import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/user_profile_service.dart';
import '../../../core/utils/host_reputation.dart';
import '../../auth/providers/user_provider.dart';
import 'host_profile_screen.dart';
import 'personal_profile_screen.dart';

/// Mở đúng màn hồ sơ theo vai trò: chủ trọ → [HostProfileScreen], còn lại → [PersonalProfileScreen].
class RoleAwareProfileScreen extends ConsumerStatefulWidget {
  final String? userId;

  const RoleAwareProfileScreen({super.key, this.userId});

  @override
  ConsumerState<RoleAwareProfileScreen> createState() => _RoleAwareProfileScreenState();
}

class _RoleAwareProfileScreenState extends ConsumerState<RoleAwareProfileScreen> {
  UserProfile? _other;
  late bool _loading;
  String? _error;

  @override
  void initState() {
    super.initState();
    final requested = widget.userId?.trim() ?? '';
    _loading = requested.isNotEmpty;
    Future.microtask(_resolve);
  }

  Future<void> _resolve() async {
    final requested = widget.userId?.trim() ?? '';
    final mine = ref.read(userProfileProvider).value;
    if (requested.isEmpty || requested == mine?.uid) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await ref.read(userProfileServiceProvider).loadUser(requested);
      if (!mounted) return;
      setState(() {
        _other = profile;
        _loading = false;
        _error = profile == null ? 'Không tìm thấy hồ sơ.' : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Không tải được hồ sơ.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mine = ref.watch(userProfileProvider).value;
    final requested = widget.userId?.trim() ?? '';
    final isSelf = requested.isEmpty || requested == mine?.uid;

    if (isSelf) {
      if (HostReputation.isHostRole(mine?.role ?? '')) {
        return const HostProfileScreen();
      }
      return const PersonalProfileScreen();
    }

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null || _other == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Hồ sơ')),
        body: Center(child: Text(_error ?? 'Không tìm thấy hồ sơ.')),
      );
    }
    if (HostReputation.isHostRole(_other!.role)) {
      return HostProfileScreen(userId: requested);
    }
    return PersonalProfileScreen(userId: requested);
  }
}
