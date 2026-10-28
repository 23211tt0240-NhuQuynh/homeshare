import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/vietnam_locations.dart';
import '../../../core/services/room_service.dart';
import '../../../core/services/roommate_service.dart';
import '../../../core/services/favorites_service.dart';
import '../../../data/models/room_model.dart';
import '../../../data/models/roommate_post_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/user_provider.dart';
import '../../chat/screens/chat_detail_screen.dart';
import '../../profile/widgets/host_reputation_stars.dart';
import 'room_detail_screen.dart';
import 'roommate_room_detail_screen.dart';

/// Màn hình Tìm kiếm & Bộ lọc chuẩn 100% Figma HomeShare
/// Hỗ trợ 3 trạng thái rõ ràng, không giật lag, không lỗi layout:
/// 1. Tìm kiếm cơ bản (Card Khu vực + Nút Tìm kiếm phòng)
/// 2. Tìm kiếm nâng cao (Dropdown bộ lọc giá, diện tích, tiện ích màu xanh HomeShare)
/// 3. Hiển thị kết quả tìm kiếm (Thanh lọc thu gọn + Danh sách thẻ phòng nằm ngang)
class SearchFilterScreen extends ConsumerStatefulWidget {
  final String initialCategory;
  final bool initialAdvanced;

  const SearchFilterScreen({
    super.key,
    this.initialCategory = 'Tất cả',
    this.initialAdvanced = false,
  });

  @override
  ConsumerState<SearchFilterScreen> createState() => _SearchFilterScreenState();
}

class _SearchFilterScreenState extends ConsumerState<SearchFilterScreen> {
  final currencyFormatter = NumberFormat('#,###', 'vi_VN');
  final ScrollController _scrollController = ScrollController();

  // Bảng màu xanh dương đồng bộ nhận diện HomeShare.
  static const Color _primaryBlue = AppColors.primary;
  static const Color _primaryBlueLight = AppColors.primaryContainer;
  static const Color _primaryBlueBorder = Color(0xFFB2CCFF);

  // 1. Khu vực state
  String _selectedCity = 'TP. Hồ Chí Minh';
  String _selectedDistrict = 'Tất cả';
  String _selectedWard = 'Tất cả';
  String _rentalType =
      'single'; // 'single' (Ở 1 mình), 'shared' (Ở ghép), 'all' (Cả hai)

  // 2. Trạng thái giao diện Figma
  bool _isAdvancedExpanded = false;
  bool _hasSearched = false;

  // 3. Bộ lọc nâng cao: Giá thuê (2.000.000đ - 5.000.000đ)
  RangeValues _priceRange = const RangeValues(2000000, 5000000);
  final double _minPriceLimit = 0;
  final double _maxPriceLimit = 20000000;

  // 4. Bộ lọc nâng cao: Diện tích (20m² - 60m²)
  RangeValues _areaRange = const RangeValues(20, 60);
  final double _minAreaLimit = 10;
  final double _maxAreaLimit = 200;

  // 5. Tiện ích & Yêu cầu - 5 tiêu chí được chọn sẵn chuẩn Figma
  final TextEditingController _customAmenityController =
      TextEditingController();
  final Set<String> _selectedAmenities = {
    'Máy lạnh',
    'Có gác lửng',
    'Chỗ để xe miễn phí',
    'Giờ giấc tự do',
    'Gần trường ĐH / Bến xe',
  };

  final List<String> _availableAmenities = [
    'Máy lạnh',
    'Có gác lửng',
    'Chỗ để xe miễn phí',
    'Giờ giấc tự do',
    'Gần trường ĐH / Bến xe',
    'Wifi tốc độ cao',
    'Tủ lạnh & Máy giặt',
    'Cho nuôi thú cưng',
    'Không chung chủ',
    'Ban công / Cửa sổ lớn',
  ];

  final Set<String> _customAmenities = {'Gần trường ĐH / Bến xe'};

  // Sắp xếp
  String _selectedSort = 'newest';

  List<String> get _districts {
    if (_selectedCity == 'Tất cả') return const ['Tất cả'];
    final list = VietnamLocations.getAdministrativeDistricts(_selectedCity);
    return ['Tất cả', ...list];
  }

  List<String> get _wards {
    if (_selectedCity == 'Tất cả' || _selectedDistrict == 'Tất cả') {
      return const ['Tất cả'];
    }
    final list = VietnamLocations.getWards(_selectedCity, _selectedDistrict);
    return ['Tất cả', ...list];
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialAdvanced) {
      _isAdvancedExpanded = true;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _customAmenityController.dispose();
    super.dispose();
  }

  int get _selectedCriteriaCount {
    int count = 0;
    if (_priceRange.start > 0 || _priceRange.end < 20000000) count++;
    if (_areaRange.start > 10 || _areaRange.end < 200) count++;
    count += _selectedAmenities.length;
    return count;
  }

  void _showCityPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => LocationSearchBottomSheet(
        title: 'Chọn Tỉnh / Thành phố',
        searchHint: 'Tìm kiếm tỉnh hoặc thành phố...',
        items: const ['Tất cả', ...VietnamLocations.provinces],
        selectedItem: _selectedCity,
        allLabel: 'Tất cả Tỉnh / Thành phố',
        onSelected: (val) {
          setState(() {
            _selectedCity = val;
            _selectedDistrict = 'Tất cả';
            _selectedWard = 'Tất cả';
          });
        },
      ),
    );
  }

  void _showDistrictPicker() {
    if (_selectedCity == 'Tất cả') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn Tỉnh / Thành phố trước'),
          duration: Duration(seconds: 2),
        ),
      );
      _showCityPicker();
      return;
    }

    final districts = _districts;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => LocationSearchBottomSheet(
        title: 'Chọn Quận / Huyện ($_selectedCity)',
        searchHint: 'Tìm quận, huyện, thị xã...',
        items: districts,
        selectedItem: _selectedDistrict,
        allLabel: 'Tất cả Quận / Huyện',
        onSelected: (dist) {
          setState(() {
            _selectedDistrict = dist;
            _selectedWard = 'Tất cả';
          });
        },
      ),
    );
  }

  void _showWardPicker() {
    if (_selectedCity == 'Tất cả') {
      _showCityPicker();
      return;
    }
    if (_selectedDistrict == 'Tất cả') {
      _showDistrictPicker();
      return;
    }

    final wards = _wards;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => LocationSearchBottomSheet(
        title: 'Chọn Phường / Xã ($_selectedDistrict)',
        searchHint: 'Tìm phường, xã, thị trấn...',
        items: wards,
        selectedItem: _selectedWard,
        allLabel: 'Tất cả Phường / Xã',
        onSelected: (w) {
          setState(() {
            _selectedWard = w;
          });
        },
      ),
    );
  }

  void _resetFilters() {
    setState(() {
      _selectedCity = 'TP. Hồ Chí Minh';
      _selectedDistrict = 'Tất cả';
      _selectedWard = 'Tất cả';
      _rentalType = 'single';
      _priceRange = const RangeValues(2000000, 5000000);
      _areaRange = const RangeValues(20, 60);
      _selectedAmenities.clear();
      _selectedAmenities.addAll([
        'Máy lạnh',
        'Có gác lửng',
        'Chỗ để xe miễn phí',
        'Giờ giấc tự do',
        'Gần trường ĐH / Bến xe',
      ]);
      for (final amenity in _selectedAmenities) {
        if (!_availableAmenities.contains(amenity)) {
          _availableAmenities.add(amenity);
        }
      }
      _customAmenities.add('Gần trường ĐH / Bến xe');
      _customAmenityController.clear();
      _selectedSort = 'newest';
      _hasSearched = false;
    });
  }

  void _executeSearch() {
    setState(() {
      _hasSearched = true;
      _isAdvancedExpanded = false;
    });
  }

  void _addCustomAmenity() {
    final text = _customAmenityController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        if (!_availableAmenities.contains(text)) {
          _availableAmenities.add(text);
        }
        _customAmenities.add(text);
        _selectedAmenities.add(text);
        _customAmenityController.clear();
      });
    }
  }

  void _showCallHostDialog(RoomModel room) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Số điện thoại chủ nhà'),
        content: Text(
          'Liên hệ trực tiếp với chủ trọ ${room.hostName}:\n\n📞 ${room.hostPhone}',
          style: const TextStyle(fontSize: 16, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  void _openChatWithHost(RoomModel room) {
    final currentUser = ref.read(currentUserProvider);
    final profile = ref.read(userProfileProvider).value;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng đăng nhập để nhắn tin với chủ trọ'),
        ),
      );
      return;
    }

    if (currentUser.uid == room.hostId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đây là phòng do chính bạn quản lý')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(
          receiverId: room.hostId,
          receiverName: room.hostName,
          receiverAvatar: room.hostAvatar,
          receiverPhone: room.hostPhone,
          isLandlord: true,
          currentUserId: currentUser.uid,
          currentUserName:
              profile?.displayName ?? currentUser.displayName ?? 'Khách thuê',
          pinnedRoom: room,
        ),
      ),
    );
  }

  String _getSortLabel(String val) {
    switch (val) {
      case 'price_asc':
        return 'Giá thấp đến cao';
      case 'price_desc':
        return 'Giá cao đến thấp';
      case 'rating':
        return 'Đánh giá cao';
      case 'newest':
      default:
        return 'Mới nhất';
    }
  }

  @override
  Widget build(BuildContext context) {
    final filterDistrict = _selectedWard != 'Tất cả'
        ? _selectedWard
        : (_selectedDistrict != 'Tất cả' ? _selectedDistrict : 'Tất cả');

    final filterParams = RoomFilterParams(
      city: _selectedCity,
      district: filterDistrict,
      rentalType: _rentalType,
      minPrice: _priceRange.start > 0 ? _priceRange.start : null,
      maxPrice: _priceRange.end < 20000000 ? _priceRange.end : null,
      minArea: _areaRange.start > 10 ? _areaRange.start : null,
      maxArea: _areaRange.end < 200 ? _areaRange.end : null,
      amenities: _selectedAmenities.isNotEmpty
          ? _selectedAmenities.toList()
          : const [],
      sortBy: _selectedSort,
    );

    final roomsAsync = ref.watch(roomsStreamProvider(filterParams));
    final roommateFilterParams = RoommateFilterParams(
      province: _selectedCity,
      district: _selectedDistrict,
      ward: _selectedWard,
      budgetMin: _priceRange.start > 0 ? _priceRange.start : null,
      budgetMax: _priceRange.end < 20000000 ? _priceRange.end : null,
    );
    final roommatePostsAsync = ref.watch(
      roommatePostsStreamProvider(roommateFilterParams),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            size: 22,
            color: AppColors.textDark,
          ),
          onPressed: () {
            if (_isAdvancedExpanded) {
              setState(() => _isAdvancedExpanded = false);
            } else if (_hasSearched) {
              setState(() => _hasSearched = false);
            } else if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
        ),
        title: const Text(
          'Trang Chủ',
          style: TextStyle(
            color: AppColors.textDark,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_hasSearched) ...[
              // TRẠNG THÁI 1 HOẶC 2: Chưa nhấn tìm kiếm phòng
              _buildLocationCard(),
              const SizedBox(height: 14),

              if (!_isAdvancedExpanded) ...[
                // TRẠNG THÁI 1: Nút Tìm kiếm phòng + Dòng thông tin
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _executeSearch,
                    icon: const Icon(
                      Icons.search,
                      size: 20,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Tìm kiếm phòng',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.circle, size: 6, color: _primaryBlue),
                    SizedBox(width: 6),
                    Text(
                      'Hơn 12.400+ phòng trọ chính chủ đang sẵn sàng',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // TRẠNG THÁI 2: Card Bộ lọc nâng cao + Hàng nút tác vụ
                _buildAdvancedFilterSection(),
                const SizedBox(height: 16),
                _buildAdvancedActionButtons(),
              ],
            ] else ...[
              // TRẠNG THÁI 3: Hiển thị kết quả tìm kiếm
              if (_isAdvancedExpanded) ...[
                _buildLocationCard(),
                const SizedBox(height: 14),
                _buildAdvancedFilterSection(),
                const SizedBox(height: 16),
                _buildAdvancedActionButtons(),
                const SizedBox(height: 20),
              ] else ...[
                _buildCompactFilterBar(),
                const SizedBox(height: 16),
              ],
              _buildResultsSection(roomsAsync, roommatePostsAsync),
            ],
          ],
        ),
      ),
    );
  }

  // WIDGET: Card Khu vực & Hình thức thuê
  Widget _buildLocationCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3.5,
                height: 16,
                decoration: BoxDecoration(
                  color: _primaryBlue,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'Khu vực',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 1. Dropdown Tỉnh/Thành phố
          _buildFieldLabel('Tỉnh/Thành phố *'),
          const SizedBox(height: 6),
          _buildLocationDropdown(
            label: _selectedCity,
            icon: Icons.near_me_outlined,
            onTap: _showCityPicker,
          ),
          const SizedBox(height: 12),

          // 2. Dropdown Phường/Xã
          _buildFieldLabel('Phường / Xã'),
          const SizedBox(height: 6),
          _buildLocationDropdown(
            label: _selectedDistrict == 'Tất cả'
                ? 'Chọn Phường / Xã'
                : (_selectedWard == 'Tất cả'
                      ? _selectedDistrict
                      : '$_selectedWard, $_selectedDistrict'),
            icon: Icons.map_outlined,
            onTap: () {
              if (_selectedDistrict == 'Tất cả') {
                _showDistrictPicker();
              } else {
                _showWardPicker();
              }
            },
          ),
          const SizedBox(height: 14),

          // 3. Hình thức thuê
          _buildFieldLabel('Hình thức thuê'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildRentalTypeCard(
                  type: 'single',
                  icon: Icons.person_outline,
                  title: 'Ở 1 mình',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildRentalTypeCard(
                  type: 'shared',
                  icon: Icons.group_outlined,
                  title: 'Ở ghép',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildRentalTypeCard(
                  type: 'all',
                  icon: Icons.swap_horiz_outlined,
                  title: 'Cả hai',
                ),
              ),
            ],
          ),

          // Nút + Nâng cao
          if (!_isAdvancedExpanded)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: InkWell(
                onTap: () {
                  setState(() => _isAdvancedExpanded = true);
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: _primaryBlueLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _primaryBlueBorder),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add, size: 18, color: _primaryBlue),
                      SizedBox(width: 6),
                      Text(
                        'Nâng cao',
                        style: TextStyle(
                          color: _primaryBlue,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: AppColors.textDark,
      ),
    );
  }

  Widget _buildLocationDropdown({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: _primaryBlue),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 13, color: AppColors.textDark),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down,
              size: 18,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRentalTypeCard({
    required String type,
    required IconData icon,
    required String title,
  }) {
    final isSelected = _rentalType == type;

    return InkWell(
      onTap: () => setState(() => _rentalType = type),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? _primaryBlueLight : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _primaryBlue : const Color(0xFFE5E7EB),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? _primaryBlue : AppColors.textMuted,
            ),
            const SizedBox(width: 3),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  title,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? _primaryBlue : AppColors.textDark,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 3),
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 13,
              color: isSelected ? _primaryBlue : const Color(0xFFD1D5DB),
            ),
          ],
        ),
      ),
    );
  }

  // WIDGET: Card Bộ lọc nâng cao chuẩn Figma
  Widget _buildAdvancedFilterSection() {
    final priceStartStr =
        '${currencyFormatter.format(_priceRange.start.toInt())}đ';
    final priceEndStr = '${currencyFormatter.format(_priceRange.end.toInt())}đ';
    final areaStartStr = '${_areaRange.start.toInt()} m²';
    final areaEndStr = '${_areaRange.end.toInt()} m²';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tiêu đề Nâng cao & Badge tiêu chí
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.tune, size: 20, color: _primaryBlue),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Bộ lọc',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _primaryBlueLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_selectedCriteriaCount tiêu chí',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: _primaryBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 1. GIÁ THUÊ / THÁNG
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Giá thuê / tháng',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '$priceStartStr – $priceEndStr',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: _primaryBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tối thiểu',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                      Text(
                        priceStartStr,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tối đa',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                      Text(
                        priceEndStr,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          RangeSlider(
            values: _priceRange,
            min: _minPriceLimit,
            max: _maxPriceLimit,
            divisions: 40,
            activeColor: _primaryBlue,
            inactiveColor: const Color(0xFFE5E7EB),
            onChanged: (values) => setState(() => _priceRange = values),
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '0đ',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
              Text(
                '20.000.000đ',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 2. DIỆN TÍCH
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Diện tích',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '$areaStartStr – $areaEndStr',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: _primaryBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Từ',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                      Text(
                        areaStartStr,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Đến',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                      Text(
                        areaEndStr,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          RangeSlider(
            values: _areaRange,
            min: _minAreaLimit,
            max: _maxAreaLimit,
            divisions: 19,
            activeColor: _primaryBlue,
            inactiveColor: const Color(0xFFE5E7EB),
            onChanged: (values) => setState(() => _areaRange = values),
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '10 m²',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
              Text(
                '200 m²',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 3. TIỆN ÍCH & YÊU CẦU
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Tiện ích & Yêu cầu',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '${_selectedAmenities.length} đang chọn',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 12,
                    color: _primaryBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Ô nhập thêm tiện ích riêng
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customAmenityController,
                  decoration: InputDecoration(
                    hintText: 'Thêm tiện ích, yêu cầu riêng...',
                    hintStyle: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                    prefixIcon: const Icon(
                      Icons.add_circle_outline,
                      size: 18,
                      color: AppColors.textMuted,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                  ),
                  onSubmitted: (_) => _addCustomAmenity(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _addCustomAmenity,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Thêm',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Danh sách tiện ích ĐÃ CHỌN
          Column(
            children: _selectedAmenities.map((amenity) {
              final isCustom = _customAmenities.contains(amenity);

              return Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: InkWell(
                  key: ValueKey('amenity_tile_$amenity'),
                  onTap: () =>
                      setState(() => _selectedAmenities.remove(amenity)),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _primaryBlueBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          size: 18,
                          color: _primaryBlue,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            amenity,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isCustom
                                ? const Color(0xFFDBEAFE)
                                : _primaryBlueLight,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isCustom ? 'Tùy chọn' : 'Đã chọn',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: isCustom
                                  ? const Color(0xFF1E40AF)
                                  : _primaryBlue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (isCustom) ...[
                          const SizedBox(width: 4),
                          InkWell(
                            key: ValueKey('delete_custom_amenity_$amenity'),
                            onTap: () {
                              setState(() {
                                _selectedAmenities.remove(amenity);
                                _availableAmenities.remove(amenity);
                                _customAmenities.remove(amenity);
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: const Padding(
                              padding: EdgeInsets.all(2),
                              child: Icon(
                                Icons.close,
                                size: 14,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          // Danh sách tiện ích CHƯA CHỌN
          Column(
            children: _availableAmenities
                .where((a) => !_selectedAmenities.contains(a))
                .map((amenity) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6.0),
                    child: InkWell(
                      key: ValueKey('amenity_tile_$amenity'),
                      onTap: () =>
                          setState(() => _selectedAmenities.add(amenity)),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.radio_button_unchecked,
                              size: 18,
                              color: Color(0xFF9CA3AF),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                amenity,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF4B5563),
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.add,
                              size: 16,
                              color: Color(0xFF9CA3AF),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                })
                .toList(),
          ),
          const SizedBox(height: 12),

          // Nút Thu gọn ˄
          Center(
            child: InkWell(
              onTap: () => setState(() => _isAdvancedExpanded = false),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _primaryBlueLight,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _primaryBlueBorder),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Thu gọn',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _primaryBlue,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.keyboard_arrow_up,
                      size: 16,
                      color: _primaryBlue,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Hàng 2 nút Đặt lại và Tìm kiếm trong Trạng thái 2
  Widget _buildAdvancedActionButtons() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _resetFilters,
              icon: const Icon(
                Icons.refresh,
                size: 18,
                color: AppColors.textDark,
              ),
              label: const Text(
                'Đặt lại',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFFE5E7EB)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _executeSearch,
              icon: const Icon(Icons.search, size: 18, color: Colors.white),
              label: const Text(
                'Tìm kiếm',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // WIDGET: Thanh lọc thu gọn (Trạng thái 3)
  Widget _buildCompactFilterBar() {
    final rentalLabel = _rentalType == 'single'
        ? 'Ở 1 mình'
        : (_rentalType == 'shared' ? 'Ở ghép' : 'Tất cả');
    final locationLabel = _selectedDistrict == 'Tất cả'
        ? _selectedCity
        : '$_selectedDistrict, $_selectedCity';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on, size: 18, color: _primaryBlue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$locationLabel • $rentalLabel',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          InkWell(
            onTap: () => setState(() => _isAdvancedExpanded = true),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _primaryBlueLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _primaryBlueBorder),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.tune, size: 14, color: _primaryBlue),
                  SizedBox(width: 4),
                  Text(
                    'Bộ lọc',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _primaryBlue,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // WIDGET: Danh sách kết quả tìm kiếm (Trạng thái 3)
  Widget _buildResultsSection(
    AsyncValue<List<RoomModel>> roomsAsync,
    AsyncValue<List<RoommatePostModel>> roommatePostsAsync,
  ) {
    final showRooms = _rentalType != 'shared';
    final showRoommates = _rentalType != 'single';
    final rooms = roomsAsync.asData?.value
        .where((room) => room.isDisplayable)
        .toList();
    final roommatePosts = roommatePostsAsync.asData?.value
        .where(_isOpenRoommatePost)
        .toList();
    final isLoading =
        (showRooms && roomsAsync.isLoading) ||
        (showRoommates && roommatePostsAsync.isLoading);
    final resultCount =
        (showRooms ? rooms?.length ?? 0 : 0) +
        (showRoommates ? roommatePosts?.length ?? 0 : 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 3.5,
                    height: 16,
                    decoration: BoxDecoration(
                      color: _primaryBlue,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      isLoading
                          ? 'Đang tìm kiếm...'
                          : 'Kết quả tìm kiếm ($resultCount)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              initialValue: _selectedSort,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  children: [
                    Text(
                      _getSortLabel(_selectedSort),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    const Icon(
                      Icons.keyboard_arrow_down,
                      size: 16,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
              ),
              onSelected: (val) => setState(() => _selectedSort = val),
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'newest', child: Text('Mới nhất')),
                const PopupMenuItem(
                  value: 'price_asc',
                  child: Text('Giá thấp đến cao'),
                ),
                const PopupMenuItem(
                  value: 'price_desc',
                  child: Text('Giá cao đến thấp'),
                ),
                const PopupMenuItem(
                  value: 'rating',
                  child: Text('Đánh giá cao nhất'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (showRooms)
          _buildRoomResults(roomsAsync, showSectionTitle: showRoommates),
        if (showRooms && showRoommates) const SizedBox(height: 16),
        if (showRoommates)
          _buildRoommateResults(
            roommatePostsAsync,
            showSectionTitle: showRooms,
          ),
      ],
    );
  }

  bool _isOpenRoommatePost(RoommatePostModel post) {
    final status = post.status.toLowerCase().trim();
    return status != 'deleted' &&
        status != 'daxoa' &&
        status != 'da_xoa' &&
        status != 'closed' &&
        status != 'dadong' &&
        status != 'da_dong';
  }

  Widget _buildRoomResults(
    AsyncValue<List<RoomModel>> roomsAsync, {
    required bool showSectionTitle,
  }) {
    return roomsAsync.when(
      data: (rawRooms) {
        final rooms = rawRooms.where((room) => room.isDisplayable).toList();
        if (rooms.isEmpty) return _buildEmptySearchMessage('phòng cho thuê');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showSectionTitle) ...[
              Text(
                'Phòng cho thuê (${rooms.length})',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
            ],
            for (final room in rooms)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildHorizontalRoomCard(room),
              ),
          ],
        );
      },
      loading: _buildSearchLoading,
      error: (_, _) => _buildSearchError('Không tải được danh sách phòng.'),
    );
  }

  Widget _buildRoommateResults(
    AsyncValue<List<RoommatePostModel>> postsAsync, {
    required bool showSectionTitle,
  }) {
    return postsAsync.when(
      data: (rawPosts) {
        final posts = rawPosts.where(_isOpenRoommatePost).toList();
        _sortRoommatePosts(posts);
        if (posts.isEmpty) return _buildEmptySearchMessage('bài tìm ở ghép');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showSectionTitle) ...[
              Text(
                'Bài tìm ở ghép (${posts.length})',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
            ],
            for (final post in posts) _buildRoommateResultCard(post),
          ],
        );
      },
      loading: _buildSearchLoading,
      error: (_, _) => _buildSearchError('Không tải được bài tìm ở ghép.'),
    );
  }

  void _sortRoommatePosts(List<RoommatePostModel> posts) {
    switch (_selectedSort) {
      case 'price_asc':
        posts.sort((a, b) => a.pricePerPerson.compareTo(b.pricePerPerson));
        break;
      case 'price_desc':
        posts.sort((a, b) => b.pricePerPerson.compareTo(a.pricePerPerson));
        break;
      case 'newest':
      default:
        posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
  }

  Widget _buildSearchLoading() => const Center(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: CircularProgressIndicator(color: _primaryBlue),
    ),
  );

  Widget _buildSearchError(String message) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFFCA5A5)),
    ),
    child: Text(message, style: const TextStyle(color: AppColors.danger)),
  );

  Widget _buildEmptySearchMessage(String type) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE5E7EB)),
    ),
    child: Column(
      children: [
        Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
        const SizedBox(height: 10),
        Text(
          'Chưa tìm thấy $type phù hợp',
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 6),
        const Text(
          'Hãy thử điều chỉnh khu vực, khoảng giá hoặc tiêu chí lọc.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );

  Widget _buildRoommateResultCard(RoommatePostModel post) {
    final price = post.pricePerPerson > 0
        ? '${currencyFormatter.format(post.pricePerPerson)} đ/người'
        : '${currencyFormatter.format(post.budgetMin)} - ${currencyFormatter.format(post.budgetMax)} đ';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RoommateRoomDetailScreen(post: post),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: _primaryBlueLight,
                  child: Text(
                    post.authorName.trim().isEmpty
                        ? '?'
                        : post.authorName.trim().characters.first,
                    style: const TextStyle(
                      color: _primaryBlue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${post.authorName} • ${post.district}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        price,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _primaryBlue,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // WIDGET: Thẻ phòng trọ dạng ngang chuẩn 100% Figma & tiendo.md
  // Bên trái: Ảnh 95x95dp + Huy hiệu Chính chủ/Mới
  // Bên phải: Tiêu đề, Giá to xanh, Diện tích • Loại phòng • Quận huyện, Chip tiện ích, Nút gọi & chat
  Widget _buildHorizontalRoomCard(RoomModel room) {
    final priceStr = '${currencyFormatter.format(room.price)} đ/tháng';
    final imageUrl = room.images.isNotEmpty
        ? room.images.first
        : 'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?auto=format&fit=crop&w=800&q=80';

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => RoomDetailScreen(room: room)),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // BÊN TRÁI: Ảnh phòng 95x95dp bo góc 12dp + Badge Chính chủ
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 95,
                height: 95,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: const Color(0xFFF3F4F6),
                        child: const Icon(
                          Icons.home,
                          size: 36,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Chính chủ',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),

            // BÊN PHẢI: Thông tin chi tiết phòng
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tiêu đề phòng
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          room.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      HostReputationStarLabel(hostId: room.hostId),
                    ],
                  ),
                  const SizedBox(height: 3),

                  // Giá thuê dùng màu xanh thương hiệu HomeShare.
                  Text(
                    priceStr,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: _primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 3),

                  // Thông số: Diện tích • Loại phòng • Quận huyện
                  Text(
                    '${room.area.toInt()} m² • ${room.roomType} • ${room.district}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF6B7280),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),

                  // Hàng chip tiện ích nhỏ + 2 nút tròn gọi điện & chat
                  Row(
                    children: [
                      // Chip tiện ích
                      Expanded(
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: room.amenities.take(2).map((a) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                a,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF4B5563),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                      // Nút tròn Gọi điện 📞
                      Material(
                        color: _primaryBlueLight,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => _showCallHostDialog(room),
                          child: const Padding(
                            padding: EdgeInsets.all(7),
                            child: Icon(
                              Icons.phone,
                              size: 16,
                              color: _primaryBlue,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Nút tròn Nhắn tin 💬
                      Material(
                        color: _primaryBlueLight,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => _openChatWithHost(room),
                          child: const Padding(
                            padding: EdgeInsets.all(7),
                            child: Icon(
                              Icons.chat_bubble,
                              size: 16,
                              color: _primaryBlue,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Nút tròn Yêu thích ❤️
                      Consumer(
                        builder: (context, ref, _) {
                          final isFav = ref
                              .watch(favoritesProvider)
                              .favoriteRoomIds
                              .contains(room.id);
                          return Material(
                            color: isFav
                                ? const Color(0xFFFEE2E2)
                                : const Color(0xFFF1F5F9),
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () async {
                                final added = await ref
                                    .read(favoritesProvider.notifier)
                                    .toggleFavoriteRoom(room);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(
                                    context,
                                  ).hideCurrentSnackBar();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        added
                                            ? 'Đã lưu phòng vào danh sách yêu thích ❤️'
                                            : 'Đã bỏ lưu phòng khỏi danh sách yêu thích',
                                      ),
                                      duration: const Duration(seconds: 1),
                                      backgroundColor: added
                                          ? AppColors.primary
                                          : const Color(0xFF334155),
                                    ),
                                  );
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(7),
                                child: Icon(
                                  isFav
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  size: 16,
                                  color: isFav
                                      ? const Color(0xFFEF4444)
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom Sheet tìm kiếm địa điểm với Search Bar mượt mà
class LocationSearchBottomSheet extends StatefulWidget {
  final String title;
  final String searchHint;
  final List<String> items;
  final String selectedItem;
  final String allLabel;
  final ValueChanged<String> onSelected;

  const LocationSearchBottomSheet({
    super.key,
    required this.title,
    required this.searchHint,
    required this.items,
    required this.selectedItem,
    required this.allLabel,
    required this.onSelected,
  });

  @override
  State<LocationSearchBottomSheet> createState() =>
      LocationSearchBottomSheetState();
}

class LocationSearchBottomSheetState extends State<LocationSearchBottomSheet> {
  final TextEditingController _controller = TextEditingController();
  late List<String> _filteredItems;

  @override
  void initState() {
    super.initState();
    _filteredItems = List.from(widget.items);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filteredItems = List.from(widget.items);
      } else {
        _filteredItems = widget.items.where((it) {
          if (it == 'Tất cả') return true;
          return it.toLowerCase().contains(q);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _controller,
              onChanged: _onSearch,
              decoration: InputDecoration(
                hintText: widget.searchHint,
                prefixIcon: const Icon(Icons.search, size: 20),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                filled: true,
                fillColor: const Color(0xFFF3F4F6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: _filteredItems.length,
              itemBuilder: (context, index) {
                final item = _filteredItems[index];
                final isSelected = item == widget.selectedItem;
                final displayName = item == 'Tất cả' ? widget.allLabel : item;

                return ListTile(
                  title: Text(
                    displayName,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textDark,
                      fontSize: 14,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(
                          Icons.check,
                          color: AppColors.primary,
                          size: 20,
                        )
                      : null,
                  onTap: () {
                    widget.onSelected(item);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
