import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'core/constants/app_colors.dart';
import 'core/services/auth_service.dart';
import 'core/services/call_push_service.dart';
import 'core/services/push_notification_service.dart';
import 'core/services/user_profile_service.dart';
import 'core/services/user_uniqueness_service.dart';
import 'core/theme/app_theme.dart';
import 'features/admin/screens/admin_main_screen.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/providers/user_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/email_verification_screen.dart';
import 'features/auth/services/email_verification_policy.dart';
import 'features/host/screens/host_main_screen.dart';
import 'features/profile/screens/cccd_verification_screen.dart';
import 'features/profile/services/required_account_info_policy.dart';
import 'features/profile/widgets/cccd_required_modal.dart';
import 'features/profile/widgets/required_info_notice_modal.dart';
import 'features/renter/screens/renter_main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Tạo kênh chuông "Cuộc gọi" và đăng ký handler khi app ở nền hoặc đã tắt.
  await CallPushService.prepare();
  // Khởi tạo hệ thống Push Notification & Local Notifications toàn diện
  await PushNotificationService.initialize();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HomeShare',
      debugShowCheckedModeBanner: false,
      // Để thông báo cuộc gọi mở IncomingCallScreen dù người dùng đang ở trang nào.
      navigatorKey: navigatorKey,
      theme: AppTheme.lightTheme,
      themeMode: ThemeMode.light,
      builder: (context, child) {
        AppColors.bind();
        return DefaultTextStyle.merge(
          style: const TextStyle(color: Color(0xFF101828)),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const AuthGate(),
    );
  }
}

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        if (user != null) {
          // Bọc màn hình chính để lưu fcmToken ngay sau khi đăng nhập.
          return _SignedInShell(
            uid: user.uid,
            email: user.email ?? '',
            firebaseEmailVerified: user.emailVerified,
          );
        }
        return const LoginScreen();
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) =>
          Scaffold(body: Center(child: Text('Lỗi xác thực: $error'))),
    );
  }
}

/// Giữ RenterMainScreen hoặc HostMainScreen tùy theo vai trò của người dùng
/// và gắn mã thông báo của máy vào user đang đăng nhập.
class _SignedInShell extends ConsumerStatefulWidget {
  final String uid;
  final String email;
  final bool firebaseEmailVerified;
  const _SignedInShell({
    required this.uid,
    required this.email,
    required this.firebaseEmailVerified,
  });

  @override
  ConsumerState<_SignedInShell> createState() => _SignedInShellState();
}

class _SignedInShellState extends ConsumerState<_SignedInShell> {
  bool _servicesBound = false;
  bool _requiredInfoPromptOpen = false;
  bool _cccdPromptOpen = false;
  bool _rejectionKickOutOpen = false;
  bool? _startedInForcedFlow;
  String? _bankAccountUid;
  String? _lastRequiredInfoSignature;
  String? _lastCccdPromptSignature;
  Future<({BankAccount bankAccount, bool hasConflict})>?
      _requiredInfoFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(renterBottomNavIndexProvider.notifier).setIndex(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);

    return profileAsync.when(
      data: (profile) {
        final mustVerify = EmailVerificationPolicy.requiresVerification(
          firebaseEmailVerified: widget.firebaseEmailVerified,
          profileRequiresVerification:
              profile?.emailVerificationRequired ??
              !widget.firebaseEmailVerified,
        );
        if (mustVerify) {
          return EmailVerificationScreen(email: widget.email);
        }

        _bindSignedInServices();
        final role = profile?.role.toLowerCase() ?? 'renter';

        if (role == 'admin') {
          return const AdminMainScreen();
        }

        final resolvedProfile = profile;
        if (resolvedProfile == null) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        // Nếu đang hiển thị dialog Bước 1 (bị từ chối lần đầu -> chuẩn bị văng ra màn hình đăng nhập),
        // giữ nguyên màn hình chờ, tuyệt đối không dựng CccdVerificationScreen để tránh hiện 2 dialog chồng nhau.
        if (_rejectionKickOutOpen) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        // Ghi nhận trạng thái CCCD ngay thời điểm vừa đăng nhập vào phiên hiện tại:
        // - Nếu lúc mới vào app chưa bị từ chối (_startedInForcedFlow == false), mà sau đó bị Admin từ chối -> Chạy Bước 1 (hiện dialog báo từ chối rồi văng ra Login).
        // - Nếu lúc đăng nhập vào từ LoginScreen mà tài khoản đã ở trạng thái bị từ chối (_startedInForcedFlow == true) -> Chạy Bước 2 & 3 (hiện dialog Yêu cầu bổ sung -> mở màn hình gửi lại CCCD).
        _startedInForcedFlow ??= resolvedProfile.isCccdForcedFlow;

        // Nếu tài khoản đã được Admin duyệt (approved) hoặc chưa bị từ chối -> reset về luồng bình thường
        if (!resolvedProfile.isCccdForcedFlow) {
          _startedInForcedFlow = false;
          AuthService.cccdResubmitSessionUids.remove(resolvedProfile.uid);
        }

        // Bước 2 & Bước 3: Chỉ chạy khi người dùng ĐĂNG NHẬP LẠI vào tài khoản đã bị từ chối (_startedInForcedFlow == true)
        if (_startedInForcedFlow == true && resolvedProfile.isCccdForcedFlow) {
          return const CccdVerificationScreen(isForcedFlow: true);
        }

        // Bước 1: Đang ở trong app (_startedInForcedFlow == false) mà bị Admin từ chối lần đầu
        // -> Chỉ hiện duy nhất 1 dialog thông báo bị từ chối rồi văng thẳng ra màn hình đăng nhập.
        if (resolvedProfile.isCccdRejected) {
          _triggerRejectedKickOut(resolvedProfile);
          return Scaffold(
            backgroundColor: AppColors.background,
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        return FutureBuilder<({BankAccount bankAccount, bool hasConflict})>(
          future: _loadRequiredInfo(resolvedProfile),
          builder: (context, requiredInfoSnapshot) {
            if (requiredInfoSnapshot.connectionState != ConnectionState.done) {
              return Scaffold(
                backgroundColor: AppColors.background,
                body: const Center(child: CircularProgressIndicator()),
              );
            }
            if (requiredInfoSnapshot.hasError) {
              return Scaffold(
                backgroundColor: AppColors.background,
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Không tải được thông tin SĐT và tài khoản ngân hàng.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () => setState(() {
                            _requiredInfoFuture = null;
                            _bankAccountUid = null;
                          }),
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            final requiredInfo = requiredInfoSnapshot.data!;
            _promptForRequiredInfo(
              resolvedProfile,
              requiredInfo.bankAccount,
              hasConflict: requiredInfo.hasConflict,
            );
            return _mainScreenForRole(role);
          },
        );
      },
      loading: () => Scaffold(
        backgroundColor: AppColors.background,
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        body: Center(child: Text('Lỗi tải thông tin tài khoản: $error')),
      ),
    );
  }

  void _bindSignedInServices() {
    if (_servicesBound) return;
    _servicesBound = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      CallPushService.bindUser(widget.uid);
      PushNotificationService.bindUser(widget.uid);
      if (PushNotificationService.pendingPayload != null) {
        final payload = PushNotificationService.pendingPayload!;
        PushNotificationService.pendingPayload = null;
        PushNotificationService.handlePayloadNavigation(payload);
      }
    });
  }

  Future<({BankAccount bankAccount, bool hasConflict})> _loadRequiredInfo(
    UserProfile profile,
  ) {
    if (_requiredInfoFuture == null || _bankAccountUid != profile.uid) {
      _bankAccountUid = profile.uid;
      _requiredInfoFuture = _fetchRequiredInfo(profile);
    }
    return _requiredInfoFuture!;
  }

  Future<({BankAccount bankAccount, bool hasConflict})> _fetchRequiredInfo(
    UserProfile profile,
  ) async {
    final bankAccount = await ref
        .read(userProfileServiceProvider)
        .loadBankAccount(profile.uid);
    final uniqueness = UserUniquenessService();
    final conflicts = await Future.wait([
      if (profile.phoneNumber.trim().isNotEmpty)
        uniqueness.checkPhoneNumberUnique(
          profile.phoneNumber,
          excludeUid: profile.uid,
        ),
      if (bankAccount.accountNumber.trim().isNotEmpty)
        uniqueness.checkBankAccountUnique(
          bankAccount.accountNumber,
          excludeUid: profile.uid,
        ),
    ]);
    return (
      bankAccount: bankAccount,
      hasConflict: conflicts.any((message) => message != null),
    );
  }

  Widget _mainScreenForRole(String role) {
    if (role == 'host' || role == 'chutro' || role == 'landlord') {
      return const HostMainScreen();
    }
    return const RenterMainScreen();
  }

  void _triggerRejectedKickOut(UserProfile profile) {
    if (_rejectionKickOutOpen) return;
    _rejectionKickOutOpen = true;
    final reason = profile.cccdRejectReason.trim().isNotEmpty
        ? profile.cccdRejectReason.trim()
        : 'Ảnh chụp không đạt tiêu chuẩn hoặc thông tin không trùng khớp';

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => PopScope(
          canPop: false,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFEE2E2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.gpp_bad_rounded,
                    color: Color(0xFFDC2626),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Yêu cầu xác thực bị từ chối',
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF991B1B),
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Yêu cầu xác thực CCCD của bạn đã bị Quản trị viên từ chối.',
                  style: TextStyle(fontSize: 13.5, height: 1.4),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Lý do từ chối:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF991B1B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        reason,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF7F1D1D),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Hệ thống sẽ chuyển bạn về màn hình đăng nhập. Vui lòng đăng nhập lại để cập nhật bổ sung hồ sơ CCCD.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textMuted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                  },
                  child: const Text(
                    'Đã hiểu & Về màn hình đăng nhập',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      );

      if (!mounted) return;
      AuthService.pendingLoginEmail = profile.email.trim().toLowerCase();
      AuthService.cccdResubmitSessionUids.add(profile.uid);
      Navigator.of(context, rootNavigator: true)
          .popUntil((route) => route.isFirst);
      await ref.read(authServiceProvider).signOut();
    });
  }

  void _promptForRequiredInfo(
    UserProfile profile,
    BankAccount bankAccount, {
    required bool hasConflict,
  }) {
    // 1. Kiểm tra SĐT và STK ngân hàng
    final needsPhoneOrBank = RequiredAccountInfoPolicy.shouldPrompt(
      phoneNumber: profile.phoneNumber,
      bankName: bankAccount.bankName,
      accountNumber: bankAccount.accountNumber,
      accountHolder: bankAccount.accountHolder,
    );

    // 2. Kiểm tra CCCD (hiện khi chưa xác thực, không chờ duyệt và không ở trạng thái bị từ chối)
    final needsCccd = !profile.isCccdVerified &&
        !profile.isCccdPending &&
        !profile.isCccdRejected;

    final isHost = profile.isHost ||
        profile.role == 'host' ||
        profile.role == 'landlord' ||
        profile.role == 'chutro';

    final phoneBankSignature = [
      profile.uid,
      profile.phoneNumber,
      bankAccount.bankName,
      bankAccount.accountNumber,
      bankAccount.accountHolder,
      '$hasConflict',
    ].join('|');

    final cccdSignature =
        '${profile.uid}|${profile.isCccdVerified}|${profile.isCccdPending}';

    // A. Nếu thiếu SĐT hoặc STK ngân hàng -> Hiện dialog STK, SĐT trước
    if (needsPhoneOrBank) {
      if (_requiredInfoPromptOpen ||
          _lastRequiredInfoSignature == phoneBankSignature) {
        return;
      }
      _lastRequiredInfoSignature = phoneBankSignature;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted || _requiredInfoPromptOpen) return;
        _requiredInfoPromptOpen = true;
        final completed = await RequiredInfoNoticeModal.show(
          context,
          profile: profile,
          initialBankAccount: bankAccount,
        );
        _requiredInfoPromptOpen = false;
        if (!mounted) return;
        if (completed == true) {
          ref.invalidate(userProfileProvider);
          setState(() {
            _bankAccountUid = null;
            _requiredInfoFuture = null;
            _lastRequiredInfoSignature = 'COMPLETED_${profile.uid}';
          });
        }
      });
      return;
    }

    // B. Nếu đã có SĐT và STK ngân hàng, nhưng chưa có CCCD -> Hiện dialog CCCD
    if (needsCccd) {
      if (_cccdPromptOpen || _lastCccdPromptSignature == cccdSignature) {
        return;
      }
      _lastCccdPromptSignature = cccdSignature;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted || _cccdPromptOpen) return;
        _cccdPromptOpen = true;
        await showCccdRequiredModal(
          context,
          isHost: isHost,
          isPending: false,
        );
        _cccdPromptOpen = false;
      });
    }
  }
}
