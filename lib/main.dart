import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'core/providers/app_settings_provider.dart';
import 'core/constants/app_colors.dart';
import 'core/services/call_push_service.dart';
import 'core/services/push_notification_service.dart';
import 'core/theme/app_theme.dart';
import 'features/admin/screens/admin_main_screen.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/providers/user_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/host/screens/host_main_screen.dart';
import 'features/renter/screens/renter_main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Nạp sẵn tùy chọn theme ban đầu để giao diện sáng/tối chuẩn xác ngay khung hình đầu tiên
  try {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString('app_theme_mode') ?? prefs.getString('app_theme_mode_preference');
    if (savedTheme == 'dark') {
      AppThemeModeNotifier.initialMode = ThemeMode.dark;
    } else if (savedTheme == 'system') {
      AppThemeModeNotifier.initialMode = ThemeMode.system;
    } else if (savedTheme == 'light') {
      AppThemeModeNotifier.initialMode = ThemeMode.light;
    }
  } catch (_) {}

  // Tạo kênh chuông "Cuộc gọi" và đăng ký handler khi app ở nền hoặc đã tắt.
  await CallPushService.prepare();
  // Khởi tạo hệ thống Push Notification & Local Notifications toàn diện
  await PushNotificationService.initialize();
  runApp(const ProviderScope(child: MyApp()));
  // Khởi tạo thông báo sau frame đầu tiên để thao tác native không giữ màn hình
  // khởi động. Hàm vẫn đăng ký background handler ngay khi bắt đầu chạy.
  unawaited(
    CallPushService.prepare().catchError((Object error, StackTrace stack) {
      debugPrint('Không thể khởi tạo thông báo cuộc gọi: $error');
    }),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(appThemeModeProvider);
    return MaterialApp(
      title: 'HomeShare',
      debugShowCheckedModeBanner: false,
      // Để thông báo cuộc gọi mở IncomingCallScreen dù người dùng đang ở trang nào.
      navigatorKey: navigatorKey,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      builder: (context, child) {
        final brightness = Theme.of(context).brightness;
        AppColors.bind(brightness);
        return DefaultTextStyle.merge(
          style: TextStyle(
            color: brightness == Brightness.dark
                ? const Color(0xFFF1F5F9)
                : const Color(0xFF101828),
          ),
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
          return _SignedInShell(uid: user.uid);
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
  const _SignedInShell({required this.uid});

  @override
  ConsumerState<_SignedInShell> createState() => _SignedInShellState();
}

class _SignedInShellState extends ConsumerState<_SignedInShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      CallPushService.bindUser(widget.uid);
      PushNotificationService.bindUser(widget.uid);
      if (PushNotificationService.pendingPayload != null) {
        final payload = PushNotificationService.pendingPayload!;
        PushNotificationService.pendingPayload = null;
        PushNotificationService.handlePayloadNavigation(payload);
      }
      ref.read(renterBottomNavIndexProvider.notifier).setIndex(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);

    return profileAsync.when(
      data: (profile) {
        if (profile?.isAccessBlocked == true) {
          final until = profile!.suspendedUntil;
          final message = profile.accountDeleted
              ? 'Tài khoản đã bị xóa quyền đăng nhập.'
              : until != null
              ? 'Tài khoản tạm khóa đến ${until.toLocal()}.'
              : 'Tài khoản đang bị khóa. Vui lòng liên hệ admin.';
          return Scaffold(
            backgroundColor: const Color(0xFFF4F9FF),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.lock_outline,
                      size: 56,
                      color: Color(0xFFD92D20),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Tài khoản bị hạn chế',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(message, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => ref.read(authServiceProvider).signOut(),
                      icon: const Icon(Icons.logout),
                      label: const Text('Đăng xuất'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return _buildSignedInDestination(profile);
      },
      loading: () => Scaffold(
        backgroundColor: AppColors.background,
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        backgroundColor: const Color(0xFFF4F9FF),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 56,
                  color: Color(0xFFD92D20),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Lỗi tải thông tin tài khoản',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  '$error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF006948),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => ref.read(authServiceProvider).signOut(),
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('Đăng xuất'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignedInDestination(dynamic profile) {
    if (profile?.isAdmin == true ||
        profile?.role == 'admin' ||
        profile?.role == 'administrator' ||
        profile?.role == 'quantri') {
      return const AdminMainScreen();
    }
    if (profile?.isHost == true ||
        profile?.role == 'host' ||
        profile?.role == 'landlord' ||
        profile?.role == 'chutro') {
      return const HostMainScreen();
    }
    return const RenterMainScreen();
  }
}
