import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'core/constants/app_colors.dart';
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
import 'features/profile/services/required_account_info_policy.dart';
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
  String? _bankAccountUid;
  String? _lastRequiredInfoSignature;
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

  void _promptForRequiredInfo(
    UserProfile profile,
    BankAccount bankAccount, {
    required bool hasConflict,
  }) {
    final complete = RequiredAccountInfoPolicy.isComplete(
      phoneNumber: profile.phoneNumber,
      bankName: bankAccount.bankName,
      accountNumber: bankAccount.accountNumber,
      accountHolder: bankAccount.accountHolder,
    );
    if (complete && !hasConflict) {
      _lastRequiredInfoSignature = null;
      return;
    }

    final signature = [
      profile.uid,
      profile.phoneNumber,
      bankAccount.bankName,
      bankAccount.accountNumber,
      bankAccount.accountHolder,
      '$hasConflict',
    ].join('|');
    if (_requiredInfoPromptOpen || _lastRequiredInfoSignature == signature) {
      return;
    }
    _lastRequiredInfoSignature = signature;
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
          _lastRequiredInfoSignature = null;
        });
      }
    });
  }
}
