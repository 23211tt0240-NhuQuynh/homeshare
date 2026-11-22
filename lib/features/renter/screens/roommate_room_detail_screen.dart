import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/booking_service.dart';
import '../../../core/services/room_service.dart';
import '../../../core/services/roommate_listing_facts.dart';
import '../../../core/utils/map_address_locator.dart';
import '../../../core/utils/vietnam_address_parser.dart';
import '../../../data/models/roommate_post_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/user_provider.dart';
import '../../chat/screens/chat_detail_screen.dart';
import '../../profile/screens/role_aware_profile_screen.dart';

/// Một dòng thói quen. `detail` để trống khi chữ lấy thẳng từ bài đăng.
class _HabitItem {
  final IconData icon;
  final String tag;
  final String detail;

  const _HabitItem(this.icon, this.tag, this.detail);
}

/// Màn chi tiết phòng ở ghép, mở từ thẻ tin ở Tìm ở ghép.
/// Phòng của chủ nhà không dùng màn này.
///
/// Dữ liệu thật lấy từ [RoommatePostModel] và phòng chủ nhà trên Firebase:
/// người đăng, tiêu đề, mô tả, địa chỉ, giá, ảnh, diện tích, phí điện nước,
/// tiện ích phòng, thói quen, giới tính cần tìm, thời điểm đăng, bản đồ.
class RoommateRoomDetailScreen extends ConsumerStatefulWidget {
  final RoommatePostModel post;

  const RoommateRoomDetailScreen({super.key, required this.post});

  @override
  ConsumerState<RoommateRoomDetailScreen> createState() => _RoommateRoomDetailScreenState();
}

class _RoommateRoomDetailScreenState extends ConsumerState<RoommateRoomDetailScreen> {
  int _photoIndex = 0;
  late final PageController _pageController;
  RoommateListingFacts? _facts;
  bool? _foundOnMap;

  RoommatePostModel get _post => widget.post;

  String get _posterName {
    final name = _post.authorName.trim();
    return name.isEmpty ? 'Người đăng' : name;
  }

  String get _givenName {
    final parts = _posterName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.last.isEmpty) return 'bạn';
    return parts.last;
  }

  String get _ageLabel {
    final age = _post.authorAge;
    if (age > 0) return '$age tuổi';
    return '';
  }

  String get _occupation {
    final job = _post.authorOccupation.trim();
    return job.isEmpty ? 'Chưa cập nhật nghề nghiệp' : job;
  }

  String get _verifiedLabel => _post.isVerified ? 'Đã xác minh' : 'Chưa xác minh';

  String get _seekLabel {
    final raw = _post.targetGender.trim().toLowerCase();
    if (raw == 'nu' || raw == 'nữ' || raw == 'female') return 'Chỉ tìm nữ';
    if (raw == 'nam' || raw == 'male') return 'Chỉ tìm nam';
    if (raw.isEmpty || raw == 'tất cả' || raw == 'tatca' || raw == 'tat ca') return 'Tìm mọi giới tính';
    return 'Chỉ tìm $raw';
  }

  String get _statusLabel => _post.hasRoom ? 'Đã có phòng sẵn' : 'Đang tìm phòng';

  int get _matchRate {
    final rate = _post.matchRate;
    if (rate < 0) return 0;
    if (rate > 100) return 100;
    return rate;
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadListingFacts();
  }

  Future<void> _loadListingFacts() async {
    if (!_post.hasRoom) return;
    final facts = await RoommateListingFacts.resolve(
      post: _post,
      rooms: ref.read(roomServiceProvider),
      bookings: ref.read(bookingServiceProvider),
    );
    if (!mounted) return;
    setState(() => _facts = facts);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Ảnh của bài. Không có ảnh thì không chèn ảnh mẫu.
  List<String> get _photos {
    return _post.images.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  List<_HabitItem> get _habits {
    return _post.habits
        .map((habit) => habit.trim())
        .where((habit) => habit.isNotEmpty)
        .map((habit) => _HabitItem(_habitIcon(habit), habit, ''))
        .toList();
  }

  IconData _habitIcon(String habit) {
    final lower = habit.toLowerCase();
    if (lower.contains('thuốc') || lower.contains('ồn')) return Icons.smoke_free_rounded;
    if (lower.contains('yên') || lower.contains('ngủ')) return Icons.nightlight_round;
    if (lower.contains('sạch') || lower.contains('gọn')) return Icons.cleaning_services_rounded;
    if (lower.contains('nấu') || lower.contains('ăn')) return Icons.restaurant_rounded;
    if (lower.contains('học') || lower.contains('sách')) return Icons.menu_book_rounded;
    if (lower.contains('yoga') || lower.contains('thể')) return Icons.self_improvement_rounded;
    if (lower.contains('nhạc')) return Icons.headphones_rounded;
    if (lower.contains('cây') || lower.contains('pet') || lower.contains('thú')) return Icons.yard_rounded;
    return Icons.check_circle_outline;
  }

  String get _title {
    final title = _post.title.trim();
    return title.isEmpty ? 'Tin ở ghép chưa có tiêu đề' : title;
  }

  /// Địa chỉ hiện một lần, dưới tiêu đề. Ưu tiên địa chỉ bài đăng chủ nhà / cơ sở.
  String get _address {
    final best = VietnamAddressParser.pickBest([
      _facts?.address.trim() ?? '',
      _post.address.trim(),
      VietnamAddressParser.composeParts(
        street: _post.address,
        district: _post.district,
      ),
    ]);
    return best.isEmpty ? 'Chưa có địa chỉ' : best;
  }

  String get _displayedAddress => displayedMapAddress(
        address: _address,
        foundOnMap: _foundOnMap,
      );

  double get _priceEach {
    if (_post.pricePerPerson > 0) return _post.pricePerPerson;
    if (_post.budgetMin > 0) return _post.budgetMin;
    return 0;
  }

  double get _deposit {
    if ((_facts?.deposit ?? 0) > 0) return _facts!.deposit;
    if (_post.deposit > 0) return _post.deposit;
    return 0;
  }

  DateTime? get _moveInDate => _facts?.moveInDate ?? _post.moveInDate;

  double get _area {
    if (_facts != null) return _facts!.area;
    if (_post.area > 0) return _post.area;
    return 0;
  }

  int get _capacity {
    if ((_facts?.capacity ?? 0) > 0) return _facts!.capacity;
    if (_post.capacity > 0) return _post.capacity;
    return 0;
  }

  List<String> get _amenities {
    final fromRoom = _facts?.amenities ?? const <String>[];
    if (fromRoom.isNotEmpty) return fromRoom;
    return _post.amenities.where((item) => item.trim().isNotEmpty).toList();
  }

  List<RoommateExtraFee> get _extraFees {
    final fromFacts = _facts?.extraFees ?? const <RoommateExtraFee>[];
    if (fromFacts.isNotEmpty) return fromFacts;
    return _post.extraFees;
  }

  DateTime get _createdAt => _post.createdAt;

  String get _message {
    final fromPost = _post.description.trim();
    return fromPost.isEmpty ? 'Người đăng chưa viết mô tả.' : fromPost;
  }

  /// Người nhận chat là người đăng tin, không phải chủ nhà của collection `rooms`.
  String get _peerId => _post.authorId;
  String get _peerAvatar => _post.authorAvatar;
  String get _peerPhone => _post.contactPhone;

  String _money(num value) => '${NumberFormat('#,###', 'vi_VN').format(value.round())}đ';

  String _shortMoney(num value) {
    if (value >= 1000000) {
      final tr = value / 1000000;
      final text = tr == tr.roundToDouble() ? tr.toStringAsFixed(0) : tr.toStringAsFixed(1);
      return '${text}tr';
    }
    return _money(value);
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Vừa đăng';
    if (diff.inMinutes < 60) return 'Đăng ${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return 'Đăng ${diff.inHours} giờ trước';
    if (diff.inDays < 7) return 'Đăng ${diff.inDays} ngày trước';
    return 'Đăng ${DateFormat('dd/MM/yyyy').format(time)}';
  }

  /// Mở chat với người đăng tin. `isLandlord: false` để hội thoại theo kiểu ở ghép.
  void _openChat() {
    final currentUser = ref.read(currentUserProvider);
    final profile = ref.read(userProfileProvider).value;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để nhắn tin')),
      );
      return;
    }
    if (_peerId.isNotEmpty && currentUser.uid == _peerId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đây là bài của chính bạn')),
      );
      return;
    }
    if (_peerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bài này chưa có người đăng để nhắn tin')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(
          receiverId: _peerId,
          receiverName: _posterName,
          receiverAvatar: _peerAvatar,
          receiverPhone: _peerPhone,
          isLandlord: false,
          currentUserId: currentUser.uid,
          currentUserName: profile?.displayName ?? currentUser.displayName ?? 'Khách thuê',
          pinnedPost: _post,
        ),
      ),
    );
  }

  /// Soạn lời ghép nối rồi vào chat. Chưa tạo document yêu cầu trên Firestore.
  void _openJoinRequest() {
    final controller = TextEditingController(
      text: 'Chào $_posterName, mình thấy phòng và lối sống của bạn hợp với mình. Mình muốn kết nối để ở ghép cùng nhé.',
    );
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Yêu cầu ghép nối', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text(
                'Lời nhắn này mở cuộc trò chuyện với người đăng phòng. Chưa ghi thành đơn riêng trên Firestore.',
                style: TextStyle(fontSize: 15, color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 4,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _openChat();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Gửi và mở trò chuyện', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).value;
    final photos = _photos;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Chi Tiết Phòng Ở ghép',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.textDark),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primaryContainer,
              backgroundImage: (profile?.avatarUrl.startsWith('http') == true) ? NetworkImage(profile!.avatarUrl) : null,
              child: profile?.avatarUrl.startsWith('http') == true
                  ? null
                  : const Icon(Icons.person, size: 18, color: AppColors.primary),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _photoCard(photos),
          const SizedBox(height: 14),
          _posterCard(),
          if (_post.matchRate >= 0) ...[
            const SizedBox(height: 12),
            _matchCard(),
          ],
          const SizedBox(height: 12),
          // Chỉ còn thời điểm đăng. Địa chỉ nằm một lần, ngay dưới tiêu đề.
          Text(
            _timeAgo(_createdAt),
            style: const TextStyle(fontSize: 14.5, color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          Text(_title, style: const TextStyle(fontSize: 24, height: 1.25, fontWeight: FontWeight.w800, color: AppColors.textDark)),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.location_on_outlined, size: 16, color: AppColors.textMuted),
              ),
              const SizedBox(width: 4),
              Expanded(child: Text(_displayedAddress, style: const TextStyle(fontSize: 15.5, color: AppColors.textSecondary, height: 1.35))),
            ],
          ),
          const SizedBox(height: 14),
          _priceCard(),
          if (_post.hasRoom) ...[
            const SizedBox(height: 12),
            _billsCard(),
          ],
          if (_area > 0 || _capacity > 0) ...[
            const SizedBox(height: 12),
            _specRow(),
          ],
          const SizedBox(height: 22),
          const Text('Tiêu chí Thói quen & Sở thích', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Xem mức độ hòa hợp giữa bạn và người đăng', style: TextStyle(fontSize: 15, color: AppColors.textSecondary)),
          const SizedBox(height: 10),
          if (_habits.isEmpty)
            const Text('Người đăng chưa thêm thói quen.', style: TextStyle(fontSize: 15, color: AppColors.textSecondary))
          else
            ..._habits.map(_habitTile),
          const SizedBox(height: 18),
          _quoteCard(),
          if (_amenities.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Text('Tiện ích phòng', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            _perkGrid(),
          ],
          const SizedBox(height: 16),
          const Text('Vị trí toạ lạc:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _AddressMap(
            key: ValueKey(_address),
            address: _address,
            latitude: _post.latitude,
            longitude: _post.longitude,
            onResolved: (found) {
              if (!mounted) return;
              setState(() => _foundOnMap = found);
            },
          ),
        ],
      ),
      bottomNavigationBar: _bottomBar(),
    );
  }

  /// Ảnh lớn hiện trọn khung, nhãn trạng thái nằm dưới ảnh để không che hình.
  Widget _photoCard(List<String> photos) {
    if (photos.isEmpty) {
      return Container(
        height: 280,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: const Color(0xFFE4E7EC), borderRadius: BorderRadius.circular(18)),
        child: const Text('Bài này chưa có ảnh', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600)),
      );
    }
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: ColoredBox(
            color: const Color(0xFFE8EEF5),
            child: SizedBox(
              height: 320,
              width: double.infinity,
              child: PageView.builder(
                controller: _pageController,
                itemCount: photos.length,
                onPageChanged: (index) => setState(() => _photoIndex = index),
                itemBuilder: (_, index) => _photo(photos[index], fit: BoxFit.contain),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _pill(_statusLabel, const Color(0xFFE8F8EF), const Color(0xFF067647)),
            _pill(_seekLabel, const Color(0xFFFFF1F3), const Color(0xFFE11D48), icon: Icons.female_rounded),
            _pill(_verifiedLabel, const Color(0xFF101828), Colors.white, icon: Icons.verified_rounded),
            _pill('${_photoIndex + 1}/${photos.length} ảnh thực tế', const Color(0xFF101828), Colors.white),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 58,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: photos.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, index) {
              final selected = index == _photoIndex;
              return GestureDetector(
                onTap: () {
                  setState(() => _photoIndex = index);
                  _pageController.animateToPage(index, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
                },
                child: Container(
                  width: 72,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: selected ? AppColors.primary : Colors.transparent, width: 2),
                  ),
                  child: ClipRRect(borderRadius: BorderRadius.circular(8), child: _photo(photos[index])),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _openAuthorProfile() {
    final authorId = _post.authorId.trim();
    if (authorId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RoleAwareProfileScreen(userId: authorId)),
    );
  }

  /// Thẻ người đăng: tên, tuổi, nghề và avatar lấy từ bài.
  Widget _posterCard() {
    return _infoCard(
      child: Row(
      children: [
        GestureDetector(
          onTap: _openAuthorProfile,
          child: Stack(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFFE8F0FE),
              backgroundImage: _avatarProvider(_peerAvatar),
              child: _avatarProvider(_peerAvatar) == null
                  ? Text(
                      _posterName.isNotEmpty ? _posterName[0].toUpperCase() : '?',
                      style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary),
                    )
                  : null,
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ],
            ),
          ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: _openAuthorProfile,
                    child: Text(_posterName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                  ),
                  const SizedBox(width: 6),
                  if (_ageLabel.isNotEmpty) Text(_ageLabel, style: const TextStyle(color: AppColors.textMuted, fontSize: 15)),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(Icons.school_outlined, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Expanded(child: Text(_occupation, style: const TextStyle(fontSize: 14.5, color: AppColors.textSecondary))),
                ],
              ),
              Row(
                children: [
                  Icon(Icons.verified_rounded, size: 14, color: _post.isVerified ? AppColors.success : AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    _verifiedLabel,
                    style: TextStyle(
                      fontSize: 14.5,
                      color: _post.isVerified ? AppColors.success : AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
      ),
    );
  }

  /// Thẻ độ tương thích. Phần trăm lấy từ `matchRate`. Ba chip lối sống vẫn là chữ cố định.
  Widget _matchCard() {
    return _infoCard(
      color: const Color(0xFFF3F7FF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppColors.primary, size: 18),
              const SizedBox(width: 6),
              Text('$_matchRate%', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.primary)),
              SizedBox(width: 8),
              const Text('Tương\nthích', style: TextStyle(fontWeight: FontWeight.w700, height: 1.15)),
              const Spacer(),
              const Text('Dựa trên lối sống\n& thói quen', textAlign: TextAlign.right, style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  /// Khung thẻ trắng bo góc cho người đăng và độ tương thích.
  Widget _infoCard({required Widget child, Color color = Colors.white}) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: child,
      ),
    );
  }

  /// Giá mỗi người từ bài. Dòng cọc và ngày dọn vào chưa có field riêng.
  Widget _priceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('TIỀN PHÒNG MỖI NGƯỜI', style: TextStyle(fontSize: 13, letterSpacing: 0.4, color: AppColors.textMuted, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              text: _money(_priceEach),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.primary),
              children: const [
                TextSpan(text: ' / người / tháng', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textMuted)),
              ],
            ),
          ),
          if (_post.hasRoom) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _priceMeta(
                    'Tiền cọc phòng',
                    _deposit > 0 ? _money(_deposit) : 'Chưa có',
                    _deposit > 0 ? 'theo phòng đang thuê' : '',
                  ),
                ),
                Expanded(
                  child: _priceMeta(
                    'Thời gian dọn vào',
                    _moveInDate == null ? 'Chưa có' : DateFormat('dd/MM/yyyy').format(_moveInDate!),
                    _moveInDate == null ? '' : 'theo đơn đặt phòng',
                    valueColor: AppColors.primary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _priceMeta(String label, String value, String extra, {Color valueColor = AppColors.textDark}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textMuted)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontWeight: FontWeight.w800, color: valueColor)),
        if (extra.isNotEmpty)
          Text(extra, style: TextStyle(fontWeight: FontWeight.w700, color: valueColor)),
      ],
    );
  }

  Widget _billsCard() {
    final occupants = _capacity > 1 ? _capacity : 2;
    final rows = _extraFees.map((fee) {
      if (fee.isMonthly) {
        final each = fee.amount / occupants;
        return (
          '${fee.name}\n(chia đều $occupants người)',
          '~${_money(each)}/người',
        );
      }
      return (
        '${fee.name}\n(theo chỉ số, chia đều)',
        '${_money(fee.amount)}${fee.unit.replaceFirst('đ', '')}',
      );
    }).toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.receipt_long_rounded, size: 18, color: AppColors.primary),
              SizedBox(width: 8),
              Expanded(child: Text('Khoản phí phát sinh chia đều (ước tính):', style: TextStyle(fontWeight: FontWeight.w700))),
            ],
          ),
          const SizedBox(height: 8),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Phòng này chưa có khoản phí phát sinh trên hệ thống.',
                style: TextStyle(fontSize: 15, color: AppColors.textSecondary, height: 1.3),
              ),
            )
          else
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  ', style: TextStyle(color: AppColors.textMuted)),
                    Expanded(child: Text(row.$1, style: const TextStyle(fontSize: 15, height: 1.3))),
                    const SizedBox(width: 8),
                    Text(row.$2, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _specRow() {
    final cards = <Widget>[];
    if (_area > 0) {
      cards.add(_specCard(Icons.square_foot_rounded, 'Tổng diện tích', '${_area.toString().replaceAll(RegExp(r"\.0$"), "")} m²'));
    }
    if (_capacity > 0) {
      cards.add(_specCard(Icons.groups_rounded, 'Quy mô', 'Tối đa\n$_capacity người'));
    }
    if (cards.isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: cards[i]),
        ],
      ],
    );
  }

  Widget _specCard(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, height: 1.2)),
        ],
      ),
    );
  }

  Widget _habitTile(_HabitItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Row(
        children: [
          CircleAvatar(radius: 18, backgroundColor: AppColors.primaryContainer, child: Icon(item.icon, size: 18, color: AppColors.primary)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.tag, style: const TextStyle(fontWeight: FontWeight.w800)),
                if (item.detail.isNotEmpty)
                  Text(item.detail, style: const TextStyle(fontSize: 14.5, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Icon(item.icon, size: 18, color: AppColors.textMuted),
        ],
      ),
    );
  }

  /// Mô tả bài đăng. Hết mô tả thì dùng lời nhắn mẫu.
  Widget _quoteCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('“', style: TextStyle(fontSize: 28, height: 1, color: AppColors.primary, fontWeight: FontWeight.w800)),
              const SizedBox(width: 6),
              Expanded(child: Text('Lời nhắn từ $_posterName', style: const TextStyle(fontWeight: FontWeight.w800))),
            ],
          ),
          const SizedBox(height: 8),
          Text(_message, style: const TextStyle(fontSize: 16, height: 1.5, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _perkGrid() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _amenities.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, index) {
        final perk = _amenities[index];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC), // Nền xám nhạt (chìm)
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)), // Viền xám
          ),
          child: Row(
            children: [
              Icon(
                _amenityIcon(perk),
                size: 20,
                color: const Color(0xFF94A3B8), // Icon màu xám đồng bộ
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  perk,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B), // Chữ xám (chìm)
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1), // Nền check box xám (disabled)
                  borderRadius: BorderRadius.circular(4),
                ),
                padding: const EdgeInsets.all(2),
                child: const Icon(
                  Icons.check,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _amenityIcon(String name) {
    final lower = name.toLowerCase().trim();
    if (lower.contains('wifi') || lower.contains('mạng') || lower.contains('internet')) return Icons.wifi_rounded;
    if (lower.contains('máy lạnh') || lower.contains('điều hòa') || lower.contains('lạnh')) return Icons.ac_unit_rounded;
    if (lower.contains('gác') || lower.contains('gác lửng')) return Icons.check_circle_outline;
    if (lower.contains('giặt')) return Icons.local_laundry_service_rounded;
    if (lower.contains('tủ lạnh')) return Icons.kitchen_rounded;
    if (lower.contains('xe') || lower.contains('đỗ') || lower.contains('bãi')) return Icons.directions_car_rounded;
    if (lower.contains('bảo vệ') || lower.contains('camera') || lower.contains('an ninh')) return Icons.security_rounded;
    if (lower.contains('ban công') || lower.contains('cửa sổ')) return Icons.balcony_rounded;
    if (lower.contains('nóng') || lower.contains('nước nóng')) return Icons.water_drop_rounded;
    if (lower.contains('gym') || lower.contains('thể thao')) return Icons.fitness_center_rounded;
    if (lower.contains('tự do') || lower.contains('giờ giấc')) return Icons.access_time_rounded;
    if (lower.contains('thú cưng') || lower.contains('chó') || lower.contains('mèo')) return Icons.pets_rounded;
    if (lower.contains('bếp') || lower.contains('nấu')) return Icons.soup_kitchen_rounded;
    return Icons.check_circle_outline;
  }

  /// Thanh dưới: yêu cầu ghép nối mở lời nhắn, nút còn lại mở chat.
  Widget _bottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, -3))],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Chi phí ở ghép', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                Text.rich(
                  TextSpan(
                    text: _shortMoney(_priceEach),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    children: const [
                      TextSpan(text: '/tháng', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: _openJoinRequest,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 46),
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Yêu cầu ghép nối', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                onPressed: _openChat,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size(0, 46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Nhắn $_givenName ngay', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String text, Color background, Color foreground, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(text, style: TextStyle(color: foreground, fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _photo(String raw, {BoxFit fit = BoxFit.cover}) {
    final url = raw.trim();
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return Image.network(
        url,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFFE4E7EC), child: Icon(Icons.image_not_supported_outlined)),
      );
    }
    if (url.startsWith('data:image')) {
      try {
        final comma = url.indexOf(',');
        return Image.memory(base64Decode(comma == -1 ? url : url.substring(comma + 1)), fit: fit);
      } catch (_) {}
    }
    return const ColoredBox(color: Color(0xFFE4E7EC), child: Icon(Icons.photo_outlined));
  }

  ImageProvider? _avatarProvider(String raw) {
    final url = raw.trim();
    if (url.startsWith('http://') || url.startsWith('https://')) return NetworkImage(url);
    return null;
  }
}

/// Bản đồ cuối bài. Chỉ ghim khi tìm được địa điểm thật trên bản đồ.
class _AddressMap extends StatefulWidget {
  final String address;
  final double? latitude;
  final double? longitude;
  final ValueChanged<bool>? onResolved;

  const _AddressMap({
    super.key,
    required this.address,
    this.latitude,
    this.longitude,
    this.onResolved,
  });

  @override
  State<_AddressMap> createState() => _AddressMapState();
}

class _AddressMapState extends State<_AddressMap> {
  LatLng? _point;
  bool _loading = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _locate();
  }

  Future<void> _locate() async {
    void notify(bool found) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onResolved?.call(found);
      });
    }

    if (isMissingMapAddress(widget.address) &&
        storedMapLocation(widget.latitude, widget.longitude) == null) {
      notify(true);
      return;
    }
    final stored = storedMapLocation(widget.latitude, widget.longitude);
    if (stored != null) {
      _point = stored.latLng;
      notify(true);
      return;
    }
    _loading = true;
    final located = await locateAddressOnMap(
      address: widget.address,
      latitude: widget.latitude,
      longitude: widget.longitude,
    );
    if (!mounted) return;
    setState(() {
      _point = located?.latLng;
      _loading = false;
      _failed = located == null;
    });
    notify(located != null);
  }

  @override
  Widget build(BuildContext context) {
    final point = _point;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 260,
        width: double.infinity,
        child: ColoredBox(
          color: const Color(0xFFE4E7EC),
          child: Stack(
            children: [
              if (point != null)
                Positioned.fill(
                  child: FlutterMap(
                  key: ValueKey('${point.latitude.toStringAsFixed(5)}:${point.longitude.toStringAsFixed(5)}'),
                  options: MapOptions(
                    initialCenter: point,
                    initialZoom: 17,
                    maxZoom: 20,
                    interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://{s}.google.com/vt/lyrs=m&hl=vi&x={x}&y={y}&z={z}',
                      subdomains: const ['mt0', 'mt1', 'mt2', 'mt3'],
                      userAgentPackageName: 'com.homeshare.app.home_share',
                      maxNativeZoom: 20,
                      tileDisplay: const TileDisplay.instantaneous(),
                    ),
                  ],
                  ),
                ),
              if (point != null)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 40),
                    child: Icon(Icons.location_on, color: Color(0xFFE11D48), size: 40),
                  ),
                )
              else
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFE7F0E4), Color(0xFFC5D7C8), Color(0xFFB7C9D6)],
                      ),
                    ),
                  ),
                ),
              if (_loading) const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                  child: Text(
                    _failed ? unresolvedMapAddressLabel : widget.address,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, height: 1.3),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
