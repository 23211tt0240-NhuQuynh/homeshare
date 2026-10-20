import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'core/services/call_push_service.dart';
import 'core/theme/app_theme.dart';
import 'features/admin/screens/admin_main_screen.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/providers/user_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/chat/screens/call_screen.dart';
import 'features/host/screens/host_main_screen.dart';
import 'features/renter/screens/renter_main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Tạo kênh chuông "Cuộc gọi" và đăng ký handler khi app ở nền hoặc đã tắt.
  await CallPushService.prepare();
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
      // Để thông báo cuộc gọi mở IncomingCallScreen dù người dùng đang ở trang nào.
      navigatorKey: navigatorKey,
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
          // Bọc màn hình chính để lưu fcmToken ngay sau khi đăng nhập.
          return _SignedInShell(uid: user.uid);
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
      ref.read(renterBottomNavIndexProvider.notifier).setIndex(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);
    // Người thuê, chủ trọ và quản trị đều nhận cuộc gọi. Trước đây chỉ màn người thuê nghe chuông.
    ref.listen(incomingCallProvider, (prev, next) {
      final call = next.value;
      if (call == null) return;
      IncomingCallRouter.show(call);
    });

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
