import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
<<<<<<< HEAD
import 'core/services/call_push_service.dart';
import 'core/theme/app_theme.dart';
import 'features/admin/screens/admin_main_screen.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/providers/user_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/host/screens/host_main_screen.dart';
import 'features/renter/screens/renter_main_screen.dart';
=======
import 'core/theme/app_theme.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/providers/user_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/renter/screens/renter_main_screen.dart';
import 'features/host/screens/host_main_screen.dart';
import 'features/admin/screens/admin_main_screen.dart';
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
<<<<<<< HEAD
  // Tạo kênh chuông "Cuộc gọi" và đăng ký handler khi app ở nền hoặc đã tắt.
  await CallPushService.prepare();
=======
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HomeShare',
      debugShowCheckedModeBanner: false,
<<<<<<< HEAD
      // Để thông báo cuộc gọi mở IncomingCallScreen dù người dùng đang ở trang nào.
      navigatorKey: navigatorKey,
=======
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
      theme: AppTheme.lightTheme,
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
<<<<<<< HEAD
          // Bọc màn hình chính để lưu fcmToken ngay sau khi đăng nhập.
          return _SignedInShell(uid: user.uid);
=======
          final profile = ref.watch(userProfileProvider).value;
          if (profile?.isAdmin == true) {
            return const AdminMainScreen();
          }
          if (profile?.isHost == true) {
            return const HostMainScreen();
          }
          return const RenterMainScreen();
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
        }
        return const LoginScreen();
      },
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stack) => Scaffold(
        body: Center(
          child: Text('Lỗi xác thực: $error'),
        ),
      ),
    );
  }
}
<<<<<<< HEAD

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
    });
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);

    return profileAsync.when(
      data: (profile) {
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
      },
      loading: () => const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stack) => Scaffold(
        body: Center(
          child: Text('Lỗi tải thông tin tài khoản: $error'),
        ),
      ),
    );
  }
}
=======
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
