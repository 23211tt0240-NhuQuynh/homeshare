import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/vietnam_locations.dart';
import '../../../core/utils/vietnamese_utils.dart';
import '../../../data/models/host_post_model.dart';
import '../../auth/providers/user_provider.dart';
import '../data/host_post_repository.dart';
import '../providers/host_amenity_provider.dart';
import '../providers/host_home_provider.dart';
import '../widgets/host_post_card.dart';

/// ============================================================================
/// Màn hình Bảng tin Chủ trọ (Host Dashboard Screen)
/// ============================================================================
/// Tác dụng:
/// - Màn hình chính của role Chủ trọ: hiển thị bài đăng tìm phòng / nhượng phòng
///   từ các đối tác và chủ trọ khác trong mạng lưới HomeShare.
/// - Cho phép tìm kiếm bài đăng theo từ khoá, lọc khu vực (63 tỉnh/thành Việt Nam),
///   lọc theo tầm giá thuê, lọc theo tiện ích có sẵn/tự thêm, và sắp xếp kết quả.
/// - Hỗ trợ tương tác trực tiếp: quan tâm bài đăng, mở chat trao đổi với chủ trọ.
///
/// CƠ CHẾ KHẮC PHỤC TRIỆT ĐỂ LỖI LẤY ẢNH FIRESTORE:
/// 1. Xử lý đa dạng schema Firestore:
///    - Dữ liệu ảnh có thể lưu dưới các trường: `images`, `anhPhong`, `danhSachAnh`,
///      `imageUrls`, `photos`, `photo`, `image`, `duongDan`, `url`, `hinhAnh`, `thumbnail`.
///    - Tự động bóc tách cả dạng mảng (List) và chuỗi đơn (String).
/// 2. Bóc tách và làm sạch chuỗi map JSON:
///    - Khi Firestore lưu đối tượng dạng chuỗi `{duongDan: https://...}` hoặc `{"url": "https://..."}`,
///      phương thức `HostPostModel.cleanImageUrl` tự động dùng Regex trích xuất URL thực tế,
///      loại bỏ dấu ngoặc, dấu nháy thừa giúp `Image.network` tải ảnh chính xác 100%.
/// 3. Liên kết đa tầng (Enrichment pipeline):
///    - Nếu tài liệu bài đăng `posts` chỉ lưu `phongId` mà không có mảng ảnh, hệ thống
///      tự động liên kết đọc `RoomModel` từ `host_rooms` / `rooms` (fallback collection `AnhPhong`/`anhPhong`).
///    - Nếu bài đăng thiếu avatar chủ trọ, hệ thống tự động join từ collection `users`.
/// 4. Hỗ trợ hiển thị an toàn:
///    - Hỗ trợ cả URL HTTP/HTTPS, Cloudinary, Firebase Storage và chuỗi Base64 Data URI.
///    - Có hiệu ứng chờ tải (CircularProgressIndicator) và giao diện fallback khi ảnh lỗi.
///
/// CƠ CHẾ BỘ LỌC TIỆN ÍCH LẤY SẴN NHỮNG TIỆN ÍCH MẪU:
/// 1. Luôn nạp sẵn danh sách 13 tiện ích mẫu chuẩn (`defaultHostAmenities`):
///    - Wifi, Máy lạnh, Tủ lạnh, Máy giặt, Gác lửng, Ban công, Bảo vệ 24/7, Chỗ để xe,
///      Bếp nấu ăn, Camera an ninh, Giờ giấc tự do, Thang máy, Nội thất đầy đủ.
/// 2. Danh sách mẫu luôn sẵn sàng ngay cả khi Firestore chưa tải xong hoặc rỗng,
///    đồng thời tự động hợp nhất không trùng lặp các tiện ích tùy chỉnh lưu trên Firestore.
/// 3. Hỗ trợ đầy đủ trạng thái thu gọn (4 tiện ích đầu + tiện ích đang chọn) và
///    mở rộng xem tất cả ("Xem thêm v" / "Thu gọn ^"), cùng ô tự thêm tiện ích riêng.
///
/// Nguồn dữ liệu:
/// - Dữ liệu bài đăng: `hostHomePostsProvider` (Firestore collection 'posts').
/// - Trạng thái bộ lọc: `hostHomeFilterProvider` (Riverpod StateNotifier).
/// - Thông tin tài khoản chủ trọ: `userProfileProvider` (Firestore collection 'users').
/// - Danh mục tiện ích: `hostAmenityNamesProvider` (Firestore collection 'amenities').
/// - Danh sách tỉnh thành: `VietnamLocations.provinces63` (hằng số bản đồ Việt Nam).
/// ============================================================================
class HostDashboardScreen extends ConsumerStatefulWidget {
  /// Cờ xác định trạng thái mở sẵn panel lọc khu vực khi khởi tạo màn hình.
  final bool initialLocationExpanded;

  const HostDashboardScreen({super.key, this.initialLocationExpanded = false});

  @override
  ConsumerState<HostDashboardScreen> createState() =>
      _HostDashboardScreenState();
}

class _HostDashboardScreenState extends ConsumerState<HostDashboardScreen> {
  // ============================================================================
  // 1. CONSTANTS & DESIGN TOKENS (Bảng màu & Dữ liệu chuẩn)
  // ============================================================================
  static const Color _primaryBlue = Color(0xFF155EEF);
  static const Color _softBlueBg = Color(0xFFEFF6FF);
  static const Color _softBlueBorder = Color(0xFFBFDBFE);
  static const Color _borderGray = Color(0xFFE2E8F0);
  static const Color _textDark = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF475569);
  static const Color _textMuted = Color(0xFF94A3B8);

  /// Danh sách khu vực đầy đủ 63 tỉnh/thành phố theo bản đồ Việt Nam + Toàn quốc.
  /// Nguồn dữ liệu: `VietnamLocations.provinces63`.
  static const List<String> _hardcodedLocations = [
    'Tất cả khu vực (Toàn quốc)',
    ...VietnamLocations.provinces63,
  ];

  // ============================================================================
  // 2. STATE CONTROLLERS & SCROLL (Quản lý nhập liệu & cuộn)
  // ============================================================================
  final _searchController = TextEditingController();
  final _locationSearchController = TextEditingController();
  final _customRequirementController = TextEditingController();
  final _locationScrollController = ScrollController();

  /// Timer chống nháy (debounce) khi người dùng gõ tìm kiếm từ khóa.
  Timer? _debounceTimer;

  // ============================================================================
  // 3. UI FLAGS (Cờ trạng thái hiển thị các panel điều hướng & bộ lọc)
  // ============================================================================
  late bool _isLocationExpanded = widget.initialLocationExpanded;
  bool _isAdvancedFilterExpanded = false;
  bool _isAmenitiesExpanded = false;

  // ============================================================================
  // 4. TEMPORARY FILTER STATE (Trạng thái bộ lọc tạm thời trước khi ấn Áp dụng)
  // ============================================================================
  /// Danh sách khu vực đang chọn trong bộ lọc tạm thời. Mặc định: 'Toàn quốc'.
  final Set<String> _tempSelectedLocations = {'Tất cả khu vực (Toàn quốc)'};

  /// Nhãn hiển thị khu vực đã áp dụng lên thanh lọc ngoài.
  String _appliedLocationsLabel = 'Tất cả khu vực';

  /// Khoảng giá thuê tạm thời: mặc định từ 0 đến 20.000.000 VNĐ.
  RangeValues _priceRangeValues = const RangeValues(0, 20000000);

  /// Tập hợp các tiện ích có sẵn trong hệ thống được chọn tạm thời.
  final Set<String> _tempSelectedAmenities = <String>{};

  /// Danh sách tiện ích / yêu cầu tùy chọn do người dùng tự gõ thêm.
  final List<String> _tempCustomRequirements = <String>[];

  /// Tập hợp các tiện ích tùy chọn đang ở trạng thái được tick chọn.
  final Set<String> _tempSelectedCustomRequirements = <String>{};

  /// Tiêu chí sắp xếp:
  /// - `_tempSortNewest`, `_tempSortMostInterested`: Checkbox (có thể chọn đồng thời).
  /// - `_tempPriceSort`: Radio (luôn chọn 1 trong 2: Giá tăng dần hoặc giảm dần).
  bool _tempSortNewest = true;
  bool _tempSortMostInterested = false;
  HostPriceSort _tempPriceSort = HostPriceSort.ascending;

  // ============================================================================
  // 5. LIFECYCLE (Khởi tạo & Giải phóng tài nguyên)
  // ============================================================================

  /// Tác dụng:
  /// - Khởi tạo màn hình, đặt lại trạng thái bộ lọc toàn cục về mặc định để
  ///   người dùng vừa vào là thấy ngay tất cả bài đăng không bị hạn chế.
  /// Nguồn dữ liệu:
  /// - Gọi `hostHomeFilterProvider.notifier.resetFilters()`.
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(hostHomeFilterProvider.notifier).resetFilters();
    });
  }

  /// Tác dụng:
  /// - Hủy Timer debounce và giải phóng bộ nhớ của tất cả các TextEditingController
  ///   và ScrollController khi màn hình bị unmount khỏi Widget tree.
  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _locationSearchController.dispose();
    _customRequirementController.dispose();
    _locationScrollController.dispose();
    super.dispose();
  }

  // ============================================================================
  // 6. BUSINESS LOGIC & EVENT HANDLERS (Xử lý sự kiện & bộ lọc)
  // ============================================================================

  /// Tác dụng:
  /// - Lắng nghe thay đổi ô tìm kiếm và trì hoãn 300ms (debounce) trước khi gửi
  ///   yêu cầu tìm kiếm đến Riverpod state, giúp hạn chế re-render liên tục.
  /// Nguồn dữ liệu:
  /// - Chuỗi `query` người dùng nhập vào `_searchController`.
  /// Cập nhật:
  /// - Cập nhật `searchQuery` trong `hostHomeFilterProvider`.
  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        ref.read(hostHomeFilterProvider.notifier).setSearchQuery(query.trim());
      }
    });
  }

  /// Tác dụng:
  /// - Đóng/mở khung dropdown chọn khu vực độc lập bên ngoài (Ảnh 1).
  /// - Khi mở dropdown khu vực, tự động đóng panel Bộ lọc nâng cao để tránh rối màn hình.
  /// Cập nhật:
  /// - Cập nhật `_isLocationExpanded` và `_isAdvancedFilterExpanded`.
  void _toggleLocationPanel() {
    setState(() {
      _isLocationExpanded = !_isLocationExpanded;
      if (_isLocationExpanded) {
        _isAdvancedFilterExpanded = false;
      }
    });
  }

  /// Tác dụng:
  /// - Đóng/mở khung Bộ lọc nâng cao (Ảnh 2, 3).
  /// - Khi mở Bộ lọc nâng cao, tự động ẩn thanh dropdown khu vực ngoài để tái
  ///   sử dụng bộ chọn khu vực ngay bên trong Mục 1 của Bộ lọc nâng cao.
  /// Cập nhật:
  /// - Cập nhật `_isAdvancedFilterExpanded` và `_isLocationExpanded`.
  void _toggleAdvancedFilterPanel() {
    setState(() {
      _isAdvancedFilterExpanded = !_isAdvancedFilterExpanded;
      if (_isAdvancedFilterExpanded) {
        _isLocationExpanded = false;
      }
    });
  }

  /// Tác dụng:
  /// - Chọn hoặc bỏ chọn một tỉnh/thành phố trong danh sách lọc tạm thời.
  /// - Quy tắc nghiệp vụ: Nếu chọn "Toàn quốc", xóa các tỉnh cụ thể. Nếu chọn
  ///   tỉnh cụ thể, tự động xóa mục "Toàn quốc".
  /// Nguồn dữ liệu:
  /// - Chuỗi tên `location` được người dùng bấm vào.
  /// Cập nhật:
  /// - Cập nhật `_tempSelectedLocations`.
  void _toggleLocationItem(String location) {
    final isAll = location.contains('Toàn quốc');
    setState(() {
      if (isAll) {
        if (_tempSelectedLocations.contains(location)) {
          _tempSelectedLocations.remove(location);
        } else {
          _tempSelectedLocations.clear();
          _tempSelectedLocations.add(location);
        }
      } else {
        _tempSelectedLocations.remove('Tất cả khu vực (Toàn quốc)');
        if (_tempSelectedLocations.contains(location)) {
          _tempSelectedLocations.remove(location);
        } else {
          _tempSelectedLocations.add(location);
        }
      }
    });
  }

  /// Tác dụng:
  /// - Bỏ chọn toàn bộ khu vực đang chọn trong bộ lọc tạm thời.
  /// Cập nhật:
  /// - Xóa sạch phần tử trong `_tempSelectedLocations`.
  void _clearLocations() {
    setState(() {
      _tempSelectedLocations.clear();
    });
  }

  /// Tác dụng:
  /// - Áp dụng các khu vực đã chọn từ khung Dropdown độc lập bên ngoài,
  ///   cập nhật nhãn hiển thị và kích hoạt lọc bài đăng qua Riverpod.
  /// Nguồn dữ liệu:
  /// - Tập hợp `_tempSelectedLocations`.
  /// Cập nhật:
  /// - Cập nhật `_appliedLocationsLabel`, đóng panel `_isLocationExpanded = false`.
  /// - Gọi `hostHomeFilterProvider.notifier.setSelectedLocations(...)`.
  void _applyLocations() {
    setState(() {
      final specificLocations = _tempSelectedLocations
          .where((l) => !l.contains('Toàn quốc'))
          .toList();

      if (_tempSelectedLocations.contains('Tất cả khu vực (Toàn quốc)') ||
          specificLocations.isEmpty) {
        _appliedLocationsLabel = 'Tất cả khu vực';
      } else {
        _appliedLocationsLabel =
            '${specificLocations.join(', ')} (${specificLocations.length})';
      }
      _isLocationExpanded = false;
    });

    ref
        .read(hostHomeFilterProvider.notifier)
        .setSelectedLocations(
          _tempSelectedLocations.contains('Tất cả khu vực (Toàn quốc)')
              ? {}
              : _tempSelectedLocations,
        );
  }

  /// Tác dụng:
  /// - Áp dụng toàn diện tất cả các tiêu chí từ Panel Bộ lọc nâng cao:
  ///   khu vực, khoảng giá, tiện ích có sẵn, yêu cầu riêng, và thứ tự sắp xếp.
  /// Nguồn dữ liệu:
  /// - `_tempSelectedLocations`, `_priceRangeValues`, `_tempSelectedAmenities`,
  ///   `_tempSelectedCustomRequirements`, `_tempSortNewest`, `_tempSortMostInterested`, `_tempPriceSort`.
  /// Cập nhật:
  /// - Đóng panel `_isAdvancedFilterExpanded = false`.
  /// - Cập nhật `hostHomeFilterProvider.notifier.applyAllFilters(...)`.
  void _applyAdvancedFilter() {
    setState(() {
      final specificLocations = _tempSelectedLocations
          .where((l) => !l.contains('Toàn quốc'))
          .toList();

      if (_tempSelectedLocations.contains('Tất cả khu vực (Toàn quốc)') ||
          specificLocations.isEmpty) {
        _appliedLocationsLabel = 'Tất cả khu vực';
      } else {
        _appliedLocationsLabel =
            '${specificLocations.join(', ')} (${specificLocations.length})';
      }
      _isAdvancedFilterExpanded = false;
    });

    final locationsToApply =
        _tempSelectedLocations.contains('Tất cả khu vực (Toàn quốc)')
        ? <String>{}
        : _tempSelectedLocations;

    ref
        .read(hostHomeFilterProvider.notifier)
        .applyAllFilters(
          selectedLocations: locationsToApply,
          minPrice: _priceRangeValues.start > 0
              ? _priceRangeValues.start
              : null,
          maxPrice: _priceRangeValues.end < 20000000
              ? _priceRangeValues.end
              : null,
          selectedAmenities: _tempSelectedAmenities,
          customRequirements: _tempSelectedCustomRequirements.toList(),
          sortNewest: _tempSortNewest,
          sortMostInterested: _tempSortMostInterested,
          priceSort: _tempPriceSort,
          clearPriceSort: false,
        );
  }

  /// Tác dụng:
  /// - Đặt lại toàn bộ tiêu chí của Bộ lọc nâng cao về trạng thái mặc định ban đầu:
  ///   Toàn quốc, 0 - 20 triệu, không giới hạn tiện ích, sắp xếp mới nhất + giá tăng dần.
  /// Cập nhật:
  /// - Reset các biến `_temp...` trong State.
  /// - Gọi `hostHomeFilterProvider.notifier.resetFilters()`.
  void _resetAdvancedFilter() {
    setState(() {
      _tempSelectedLocations.clear();
      _tempSelectedLocations.add('Tất cả khu vực (Toàn quốc)');
      _appliedLocationsLabel = 'Tất cả khu vực';
      _priceRangeValues = const RangeValues(0, 20000000);
      _tempSelectedAmenities.clear();
      _tempCustomRequirements.clear();
      _tempSelectedCustomRequirements.clear();
      _tempSortNewest = true;
      _tempSortMostInterested = false;
      _tempPriceSort = HostPriceSort.ascending;
      _isAmenitiesExpanded = false;
      _locationSearchController.clear();
      _customRequirementController.clear();
    });

    ref.read(hostHomeFilterProvider.notifier).resetFilters();
  }

  /// Tác dụng:
  /// - Thêm tiện ích / yêu cầu riêng do người dùng tự nhập.
  /// - Kiểm tra chống trùng lặp thông minh tiếng Việt (không phân biệt hoa thường, dấu tiếng Việt):
  ///   + Trùng với danh mục Firestore: tự động tick chọn tiện ích hệ thống tương ứng.
  ///   + Trùng với tiện ích đã nhập trước đó: tự động tick chọn và thông báo.
  ///   + Hợp lệ mới: thêm vào danh sách tùy chọn và tự động tick chọn.
  /// Nguồn dữ liệu:
  /// - Chuỗi nhập từ `_customRequirementController`.
  /// - Danh sách tiện ích hệ thống `amenityNames` lấy từ Firestore collection 'amenities'.
  /// Cập nhật:
  /// - Cập nhật `_tempSelectedAmenities`, `_tempCustomRequirements`, `_tempSelectedCustomRequirements`.
  void _handleAddCustomRequirement(List<String> amenityNames) {
    final raw = _customRequirementController.text;
    final normalized = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) return;

    final normalizedInput = normalizeVietnameseComparison(normalized);

    // 1. Kiểm tra chống trùng với danh mục tiện ích sẵn có từ Firestore
    final catalogMatch = amenityNames.where((item) {
      return normalizeVietnameseComparison(item) == normalizedInput;
    }).firstOrNull;

    if (catalogMatch != null) {
      setState(() {
        if (!_tempSelectedAmenities.contains(catalogMatch)) {
          _tempSelectedAmenities.add(catalogMatch);
        }
        _customRequirementController.clear();
        _isAmenitiesExpanded = true;
      });
      _showNotice(
        'Tiện ích "$catalogMatch" đã có trong danh mục (đã tự động chọn).',
      );
      return;
    }

    // 2. Kiểm tra chống trùng với tiện ích tùy chọn đã thêm trước đó
    final customMatch = _tempCustomRequirements.where((item) {
      return normalizeVietnameseComparison(item) == normalizedInput;
    }).firstOrNull;

    if (customMatch != null) {
      setState(() {
        if (!_tempSelectedCustomRequirements.contains(customMatch)) {
          _tempSelectedCustomRequirements.add(customMatch);
        }
        _customRequirementController.clear();
        _isAmenitiesExpanded = true;
      });
      _showNotice('Tiện ích tùy chọn "$customMatch" đã tồn tại.');
      return;
    }

    // 3. Thêm mới vào danh sách tùy chọn
    setState(() {
      _tempCustomRequirements.add(normalized);
      _tempSelectedCustomRequirements.add(normalized);
      _customRequirementController.clear();
      _isAmenitiesExpanded = true;
    });
  }

  /// Tác dụng:
  /// - Xử lý thao tác kéo xuống để làm mới (Pull-to-refresh) bảng tin.
  /// Nguồn dữ liệu:
  /// - Vô hiệu hoá cache bằng `ref.invalidate(hostHomePostsProvider)`.
  Future<void> _handleRefresh() async {
    ref.invalidate(hostHomePostsProvider);
    await Future.delayed(const Duration(milliseconds: 300));
  }

  /// Tác dụng:
  /// - Hiển thị thanh thông báo nổi (Floating SnackBar) trên giao diện.
  /// Nguồn dữ liệu:
  /// - Chuỗi `message` truyền vào.
  void _showNotice(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  // ============================================================================
  // 7. HELPER UTILITIES (Định dạng hiển thị)
  // ============================================================================

  /// Tác dụng:
  /// - Định dạng số sang tiền tệ Việt Nam (VNĐ), ví dụ: 3500000 -> "3.500.000đ".
  /// Nguồn dữ liệu:
  /// - Số `value` truyền vào.
  String _formatCurrency(num value) {
    final formatted = NumberFormat.decimalPattern('vi').format(value.toInt());
    return '$formattedđ';
  }

  // ============================================================================
  // 8. MAIN BUILD METHOD
  // ============================================================================

  /// Tác dụng:
  /// - Xây dựng toàn bộ giao diện bảng tin chủ trọ: Header, Search, Dropdown khu vực,
  ///   Panel bộ lọc nâng cao, Thẻ chào mừng và Danh sách bài đăng.
  /// Nguồn dữ liệu:
  /// - `userProfileProvider`: Thông tin tài khoản chủ trọ đang đăng nhập.
  /// - `hostHomeFilterProvider`: Trạng thái các tiêu chí lọc đang được kích hoạt.
  /// - `hostHomePostsProvider`: Danh sách bài đăng đối chiếu từ Firestore.
  /// - `hostAmenityNamesProvider`: Danh mục tên tiện ích từ Firestore 'amenities'.
  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).value;
    final filterState = ref.watch(hostHomeFilterProvider);
    final postsAsync = ref.watch(hostHomePostsProvider);

    // BỘ LỌC TIỆN ÍCH LẤY SẴN NHỮNG TIỆN ÍCH MẪU:
    // Đọc danh mục tiện ích từ provider; nếu danh sách rỗng thì luôn fallback về
    // danh sách tiện ích mẫu chuẩn (defaultHostAmenities) để giao diện luôn sẵn sàng.
    final rawAmenityNames = ref.watch(hostAmenityNamesProvider);
    final amenityNames = rawAmenityNames.isNotEmpty
        ? rawAmenityNames
        : defaultHostAmenities;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _handleRefresh,
          color: _primaryBlue,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // 1. Header Figma: Logo HomeShare, Tên, Huy hiệu VIP, Avatar, Chuông thông báo
              _buildHeader(profile),
              const SizedBox(height: 14),

              // 2. Thanh tìm kiếm từ khóa & Nút mở Bộ lọc nâng cao
              _buildSearchBar(),
              const SizedBox(height: 12),

              // 3. Thanh hiển thị khu vực: TỰ ĐỘNG ẨN KHI BẬT BỘ LỌC NÂNG CAO
              if (!_isAdvancedFilterExpanded) ...[
                _buildLocationCard(),
                if (_isLocationExpanded) ...[
                  const SizedBox(height: 8),
                  _buildStandaloneLocationDropdown(),
                ],
                const SizedBox(height: 10),
              ],

              // 4. Panel Bộ lọc nâng cao (Ảnh 2, 3) tích hợp bộ chọn khu vực bên trong
              if (_isAdvancedFilterExpanded) ...[
                _buildAdvancedFilterPanel(amenityNames),
                const SizedBox(height: 14),
              ],

              // 5. Thẻ chào mừng & Thông điệp kết nối mạng lưới chủ trọ
              _buildWelcomeCard(profile),
              const SizedBox(height: 14),

              // 6. Danh sách bài đăng hoặc các trạng thái Loading / Empty / Error
              _buildFeedContent(postsAsync, filterState),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // 9. HEADER & TOP CONTROLS (Thành phần tiêu đề & tìm kiếm)
  // ============================================================================

  /// Tác dụng:
  /// - Hiển thị thanh thông tin trên cùng: Icon ứng dụng, thương hiệu HomeShare,
  ///   tên chủ trọ, huy hiệu VIP nếu đủ điều kiện, chuông thông báo và avatar.
  /// Nguồn dữ liệu:
  /// - `profile`: Đối tượng `UserProfile?` từ `userProfileProvider`.
  Widget _buildHeader(UserProfile? profile) {
    final hostName = profile?.displayName.isNotEmpty == true
        ? profile!.displayName
        : 'Chủ trọ';
    final isVip =
        profile != null &&
        (profile.reputationScore >= 80 || profile.isCccdVerified);
    // Chuẩn hóa đường dẫn avatar từ Firestore (xử lý chuỗi map JSON {duongDan: ...}, nháy kép, base64)
    final avatarUrl = HostPostModel.cleanImageUrl(profile?.avatarUrl ?? '');
    final initials = hostName.isNotEmpty
        ? hostName.trim().split(' ').last.substring(0, 1).toUpperCase()
        : 'HS';

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _primaryBlue,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: _primaryBlue.withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.home, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    'HomeShare',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: _primaryBlue,
                      letterSpacing: -0.3,
                    ),
                  ),
                  if (isVip)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFF59E0B)),
                      ),
                      child: const Text(
                        'Chủ trọ VIP',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFB45309),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Mạng lưới Đối tác & Chủ trọ • $hostName',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF65758F),
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Stack(
          children: [
            IconButton(
              tooltip: 'Thông báo',
              onPressed: () => _showNotice('Bạn chưa có thông báo mới'),
              icon: const Icon(
                Icons.notifications_none_rounded,
                color: Color(0xFF475569),
                size: 26,
              ),
            ),
            Positioned(
              top: 10,
              right: 12,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFFEF4444),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 4),
        CircleAvatar(
          radius: 18,
          backgroundColor: _softBlueBg,
          child: _buildDashboardAvatar(avatarUrl, initials),
        ),
      ],
    );
  }

  /// Hiển thị avatar chủ trọ trên Header: hỗ trợ Base64, URL Network và fallback chữ cái đầu
  Widget _buildDashboardAvatar(String avatarUrl, String initials) {
    if (avatarUrl.isNotEmpty) {
      if (avatarUrl.startsWith('data:image')) {
        try {
          final base64String = avatarUrl.split(',').last;
          final bytes = base64Decode(base64String);
          return ClipOval(
            child: Image.memory(
              bytes,
              width: 36,
              height: 36,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _avatarFallback(initials),
            ),
          );
        } catch (_) {}
      } else if (avatarUrl.startsWith('http')) {
        return ClipOval(
          child: Image.network(
            webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
            avatarUrl,
            width: 36,
            height: 36,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _avatarFallback(initials),
          ),
        );
      }
    }
    return _avatarFallback(initials);
  }

  Widget _avatarFallback(String initials) {
    return Text(
      initials,
      style: const TextStyle(
        color: _primaryBlue,
        fontWeight: FontWeight.bold,
        fontSize: 13,
      ),
    );
  }

  /// Tác dụng:
  /// - Hiển thị ô tìm kiếm từ khóa (tên bài, chủ trọ, địa chỉ) kèm nút bấm "Nâng cao"
  ///   màu xanh dương để mở Bộ lọc nâng cao.
  /// Nguồn dữ liệu:
  /// - `_searchController` quản lý văn bản tìm kiếm.
  Widget _buildSearchBar() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _borderGray),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              textAlignVertical: TextAlignVertical.center,
              decoration: InputDecoration(
                hintText: 'Tìm kiếm bài đăng, chủ trọ, đối tác...',
                hintStyle: const TextStyle(fontSize: 12, color: _textMuted),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Color(0xFF64748B),
                  size: 20,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          ref
                              .read(hostHomeFilterProvider.notifier)
                              .setSearchQuery('');
                        },
                      )
                    : null,
                isDense: true,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: _primaryBlue,
            minimumSize: const Size(0, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            elevation: 0,
          ),
          onPressed: _toggleAdvancedFilterPanel,
          icon: const Icon(Icons.tune_rounded, size: 17, color: Colors.white),
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Nâng cao',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                _isAdvancedFilterExpanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: Colors.white,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================================
  // 10. LOCATION FILTER WIDGETS (Bộ chọn khu vực độc lập bên ngoài)
  // ============================================================================

  /// Tác dụng:
  /// - Hiển thị thanh tóm tắt khu vực đã chọn dạng spinner/thẻ bấm (Ảnh 1).
  /// Nguồn dữ liệu:
  /// - Nhãn `_appliedLocationsLabel`.
  Widget _buildLocationCard() {
    return InkWell(
      onTap: _toggleLocationPanel,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _borderGray),
        ),
        child: Row(
          children: [
            const Text(
              'Khu vực:',
              style: TextStyle(
                fontSize: 12,
                color: _textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _softBlueBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _softBlueBorder),
                ),
                child: Text(
                  _appliedLocationsLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    color: _primaryBlue,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              _isLocationExpanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              color: _primaryBlue,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  /// Tác dụng:
  /// - Khung Dropdown hiển thị danh sách khu vực khi nhấn vào Thẻ khu vực bên ngoài.
  /// Nguồn dữ liệu:
  /// - Gọi `_buildLocationSelectorWidget(isInsideAdvancedFilter: false)`.
  Widget _buildStandaloneLocationDropdown() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderGray),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: _buildLocationSelectorWidget(isInsideAdvancedFilter: false),
    );
  }

  /// Tác dụng:
  /// - Thành phần tái sử dụng chứa ô tìm nhanh và danh sách 63 tỉnh/thành phố Việt Nam
  ///   dạng cuộn kèm checkbox bo góc vuông.
  /// - Dùng chung cho cả Dropdown ngoài (Ảnh 1) và Bộ lọc nâng cao Mục 1 (Ảnh 2).
  /// Nguồn dữ liệu:
  /// - `_hardcodedLocations`: Danh sách tỉnh thành chuẩn Việt Nam.
  /// - `_locationSearchController`: Từ khóa lọc nhanh tỉnh thành.
  /// - `_tempSelectedLocations`: Danh sách khu vực đang chọn.
  Widget _buildLocationSelectorWidget({required bool isInsideAdvancedFilter}) {
    final query = _locationSearchController.text.trim().toLowerCase();
    final filteredLocations = _hardcodedLocations.where((loc) {
      if (query.isEmpty) return true;
      return loc.toLowerCase().contains(query);
    }).toList();

    final selectedCount = _tempSelectedLocations
        .where((l) => !l.contains('Toàn quốc'))
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Ô tìm nhanh tỉnh/thành phố
        Container(
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _borderGray),
          ),
          child: TextField(
            controller: _locationSearchController,
            onChanged: (val) => setState(() {}),
            textAlignVertical: TextAlignVertical.center,
            decoration: InputDecoration(
              hintText: 'Tìm nhanh tỉnh/thành phố...',
              hintStyle: const TextStyle(fontSize: 12, color: _textMuted),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: Color(0xFF94A3B8),
                size: 18,
              ),
              suffixIcon: _locationSearchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        _locationSearchController.clear();
                        setState(() {});
                      },
                    )
                  : null,
              isDense: true,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Danh sách các khu vực có checkbox (Đầy đủ tất cả khu vực VN)
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 260),
          child: Scrollbar(
            controller: _locationScrollController,
            thumbVisibility: true,
            child: ListView.separated(
              controller: _locationScrollController,
              shrinkWrap: true,
              itemCount: filteredLocations.length,
              separatorBuilder: (context, index) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final location = filteredLocations[index];
                final isAll = location.contains('Toàn quốc');
                final isSelected = _tempSelectedLocations.contains(location);

                return InkWell(
                  onTap: () => _toggleLocationItem(location),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected && !isAll ? _softBlueBg : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected && !isAll
                            ? _primaryBlue
                            : _borderGray,
                        width: isSelected && !isAll ? 1.4 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Checkbox custom vuông bo góc
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: isSelected ? _primaryBlue : Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isSelected
                                  ? _primaryBlue
                                  : const Color(0xFFCBD5E1),
                              width: 1.5,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check_rounded,
                                  size: 15,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            location,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: isSelected
                                  ? (isAll ? _textDark : _primaryBlue)
                                  : _textDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Hàng nút điều khiển dưới cùng
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
              onPressed: _clearLocations,
              child: const Text(
                'Bỏ chọn tất cả',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: _textSecondary,
                ),
              ),
            ),
            if (!isInsideAdvancedFilter)
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _primaryBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  elevation: 0,
                ),
                onPressed: _applyLocations,
                child: Text(
                  'Áp dụng ($selectedCount khu vực)',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // ============================================================================
  // 11. ADVANCED FILTER PANEL (Panel bộ lọc nâng cao)
  // ============================================================================

  /// Tác dụng:
  /// - Hiển thị khung Bộ lọc nâng cao đầy đủ theo chuẩn Figma (Ảnh 2, 3), gồm 4 mục:
  ///   1. Khu vực tìm kiếm (tái sử dụng _buildLocationSelectorWidget).
  ///   2. Giá thuê / tháng (Tối thiểu, Tối đa, RangeSlider).
  ///   3. Tiện ích & Yêu cầu (lấy từ Firestore collection 'amenities' + tiện ích tự nhập).
  ///   4. Sắp xếp kết quả (Checkbox mới nhất/quan tâm, Radio giá tăng/giảm).
  /// - Hàng nút "Đặt lại" và "Áp dụng bộ lọc" ở cuối cùng.
  /// Nguồn dữ liệu:
  /// - `amenityNames`: Danh sách tiện ích lấy từ Firestore collection 'amenities'.
  Widget _buildAdvancedFilterPanel(List<String> amenityNames) {
    final selectedLocationsCount = _tempSelectedLocations
        .where((l) => !l.contains('Toàn quốc'))
        .length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderGray),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Mục 1: Khu vực tìm kiếm
          _buildAdvancedLocationSection(selectedLocationsCount),
          const Divider(height: 24),

          // Mục 2: Giá thuê / tháng
          _buildAdvancedPriceSection(),
          const Divider(height: 24),

          // Mục 3: Tiện ích & Yêu cầu
          _buildAdvancedAmenitiesSection(amenityNames),
          const Divider(height: 20),

          // Mục 4: Sắp xếp kết quả
          _buildAdvancedSortSection(),
          const SizedBox(height: 18),

          // Nút Đặt lại & Áp dụng bộ lọc
          _buildAdvancedActionButtons(),
        ],
      ),
    );
  }

  /// Tác dụng:
  /// - Xây dựng Mục 1: Tiêu đề "Khu vực tìm kiếm", số lượng đã chọn và bộ chọn khu vực.
  /// Nguồn dữ liệu:
  /// - Số lượng `selectedLocationsCount` từ State `_tempSelectedLocations`.
  Widget _buildAdvancedLocationSection(int selectedLocationsCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 4,
                    height: 16,
                    decoration: BoxDecoration(
                      color: _primaryBlue,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Flexible(
                    child: Text(
                      '1. Khu vực tìm kiếm',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _textDark,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _softBlueBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _softBlueBorder),
              ),
              child: Text(
                'Đã chọn ($selectedLocationsCount)',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: _primaryBlue,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildLocationSelectorWidget(isInsideAdvancedFilter: true),
      ],
    );
  }

  /// Tác dụng:
  /// - Xây dựng Mục 2: Bộ lọc khoảng giá thuê / tháng (2 ô Tối thiểu, Tối đa và RangeSlider).
  /// Nguồn dữ liệu:
  /// - `_priceRangeValues`: Khoảng giá tạm thời (0 đến 20 triệu VNĐ).
  Widget _buildAdvancedPriceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 4,
                    height: 16,
                    decoration: BoxDecoration(
                      color: _primaryBlue,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Flexible(
                    child: Text(
                      'Giá thuê / tháng',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _textDark,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${_formatCurrency(_priceRangeValues.start)} – ${_formatCurrency(_priceRangeValues.end)}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: _primaryBlue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // 2 ô Tối thiểu & Tối đa
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _borderGray),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tối thiểu',
                      style: TextStyle(fontSize: 11, color: _textSecondary),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _formatCurrency(_priceRangeValues.start),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _textDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _borderGray),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tối đa',
                      style: TextStyle(fontSize: 11, color: _textSecondary),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _formatCurrency(_priceRangeValues.end),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _textDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        // Thanh trượt 2 đầu RangeSlider
        RangeSlider(
          values: _priceRangeValues,
          min: 0,
          max: 20000000,
          divisions: 40,
          activeColor: _primaryBlue,
          inactiveColor: const Color(0xFFE2E8F0),
          onChanged: (values) {
            setState(() => _priceRangeValues = values);
          },
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '0đ',
                style: TextStyle(
                  fontSize: 11,
                  color: _textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '20.000.000đ',
                style: TextStyle(
                  fontSize: 11,
                  color: _textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// ============================================================================
  /// BỘ LỌC TIỆN ÍCH - LẤY SẴN NHỮNG TIỆN ÍCH MẪU CHUẨN
  /// ============================================================================
  /// Tác dụng:
  /// - Xây dựng Mục 3: Tiện ích & Yêu cầu gồm danh mục tiện ích và ô tự nhập thêm.
  /// - LẤY SẴN NHỮNG TIỆN ÍCH MẪU:
  ///   Bộ lọc luôn có sẵn 13 tiện ích mẫu chuẩn (Wifi, Máy lạnh, Tủ lạnh, Máy giặt,
  ///   Gác lửng, Ban công, Bảo vệ 24/7, Chỗ để xe, Bếp nấu ăn, Camera an ninh,
  ///   Giờ giấc tự do, Thang máy, Nội thất đầy đủ) làm nền tảng.
  /// - Cơ chế hiển thị:
  ///   + Mặc định ở trạng thái thu gọn: hiển thị 4 tiện ích đầu tiên + các tiện ích đang chọn.
  ///   + Nút "Xem thêm v" / "Thu gọn ^": mở rộng xem toàn bộ danh mục tiện ích mẫu và thu gọn lại.
  ///   + Thêm tiện ích riêng: cho phép nhập tiện ích đặc thù, tự động kiểm tra trùng lặp.
  ///
  /// Nguồn dữ liệu:
  /// - `amenityNames`: Danh mục tiện ích (đã bao gồm tiện ích mẫu từ defaultHostAmenities).
  /// - `_tempSelectedAmenities`: Danh sách tiện ích mẫu đang chọn.
  /// - `_tempCustomRequirements`, `_tempSelectedCustomRequirements`: Tiện ích tự thêm.
  Widget _buildAdvancedAmenitiesSection(List<String> amenityNames) {
    final totalSelectedAmenities =
        _tempSelectedAmenities.length + _tempSelectedCustomRequirements.length;

    final displayedAmenities = _isAmenitiesExpanded
        ? amenityNames
        : {
            ...amenityNames.take(4),
            ...amenityNames.where((a) => _tempSelectedAmenities.contains(a)),
          }.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.menu_rounded, size: 18, color: _primaryBlue),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Tiện ích & Yêu cầu',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _textDark,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _softBlueBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _softBlueBorder),
              ),
              child: Text(
                '$totalSelectedAmenities đang chọn',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: _primaryBlue,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Ô thêm tiện ích riêng & nút Thêm
        Row(
          children: [
            Expanded(
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _borderGray),
                ),
                child: TextField(
                  controller: _customRequirementController,
                  textAlignVertical: TextAlignVertical.center,
                  decoration: const InputDecoration(
                    hintText: 'Thêm tiện ích, yêu cầu riêng...',
                    hintStyle: TextStyle(fontSize: 12, color: _textMuted),
                    prefixIcon: Icon(
                      Icons.add_circle_outline_rounded,
                      color: Color(0xFF94A3B8),
                      size: 18,
                    ),
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10),
                  ),
                  onSubmitted: (_) => _handleAddCustomRequirement(amenityNames),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _primaryBlue,
                minimumSize: const Size(0, 42),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                elevation: 0,
              ),
              onPressed: () => _handleAddCustomRequirement(amenityNames),
              child: const Text(
                'Thêm',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Danh sách thẻ tiện ích
        Column(
          children: [
            // 1. Tiện ích từ bảng Firestore
            for (final amenity in displayedAmenities)
              _buildAmenityCard(
                name: amenity,
                isSelected: _tempSelectedAmenities.contains(amenity),
                isCustom: false,
                onToggle: () {
                  setState(() {
                    if (_tempSelectedAmenities.contains(amenity)) {
                      _tempSelectedAmenities.remove(amenity);
                    } else {
                      _tempSelectedAmenities.add(amenity);
                    }
                  });
                },
              ),

            // 2. Tiện ích tự nhập tùy chọn
            for (final customReq in _tempCustomRequirements)
              _buildAmenityCard(
                name: customReq,
                isSelected: _tempSelectedCustomRequirements.contains(customReq),
                isCustom: true,
                onToggle: () {
                  setState(() {
                    if (_tempSelectedCustomRequirements.contains(customReq)) {
                      _tempSelectedCustomRequirements.remove(customReq);
                    } else {
                      _tempSelectedCustomRequirements.add(customReq);
                    }
                  });
                },
                onRemove: () {
                  setState(() {
                    _tempCustomRequirements.remove(customReq);
                    _tempSelectedCustomRequirements.remove(customReq);
                  });
                },
              ),
          ],
        ),
        const SizedBox(height: 6),

        // Nút Thu gọn / Xem thêm tiện ích
        if (amenityNames.length > 4)
          InkWell(
            key: const ValueKey('amenities_toggle_button'),
            borderRadius: BorderRadius.circular(12),
            onTap: () =>
                setState(() => _isAmenitiesExpanded = !_isAmenitiesExpanded),
            child: Container(
              width: double.infinity,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F5FF),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                _isAmenitiesExpanded ? 'Thu gọn ^' : 'Xem thêm v',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E60F2),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Tác dụng:
  /// - Xây dựng Mục 4: Sắp xếp kết quả.
  /// - Hàng 1 (Checkbox): "Mới nhất", "Được quan tâm nhất" (chọn cùng lúc được).
  /// - Hàng 2 (Radio): "Giá thấp đến cao", "Giá cao đến thấp" (luôn chọn 1 trong 2).
  /// Nguồn dữ liệu:
  /// - `_tempSortNewest`, `_tempSortMostInterested`, `_tempPriceSort`.
  Widget _buildAdvancedSortSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                color: _primaryBlue,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Sắp xếp kết quả',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _textDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Hàng 1: Dạng Checkbox ("Mới nhất", "Được quan tâm nhất")
        Row(
          children: [
            Expanded(
              child: _buildSortCheckboxCard(
                'Mới nhất',
                isSelected: _tempSortNewest,
                onToggle: () {
                  setState(() => _tempSortNewest = !_tempSortNewest);
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSortCheckboxCard(
                'Được quan tâm nhất',
                isSelected: _tempSortMostInterested,
                onToggle: () {
                  setState(
                    () => _tempSortMostInterested = !_tempSortMostInterested,
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Hàng 2: Dạng Radio ("Giá thấp đến cao", "Giá cao đến thấp")
        Row(
          children: [
            Expanded(
              child: _buildSortRadioCard(
                'Giá thấp đến cao',
                isSelected: _tempPriceSort == HostPriceSort.ascending,
                onTap: () {
                  setState(() {
                    _tempPriceSort = HostPriceSort.ascending;
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSortRadioCard(
                'Giá cao đến thấp',
                isSelected: _tempPriceSort == HostPriceSort.descending,
                onTap: () {
                  setState(() {
                    _tempPriceSort = HostPriceSort.descending;
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Tác dụng:
  /// - Xây dựng hàng nút hành động cuối Bộ lọc nâng cao: "Đặt lại" và "Áp dụng bộ lọc".
  Widget _buildAdvancedActionButtons() {
    return Row(
      children: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(90, 46),
            side: const BorderSide(color: _borderGray),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: _resetAdvancedFilter,
          child: const Text(
            'Đặt lại',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: _textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: _primaryBlue,
              minimumSize: const Size(0, 46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            onPressed: _applyAdvancedFilter,
            icon: const Icon(
              Icons.check_rounded,
              size: 18,
              color: Colors.white,
            ),
            label: const Text(
              'Áp dụng bộ lọc',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================================
  // 12. FILTER ITEM CARDS (Các widget thẻ tiện ích và nút sắp xếp nhỏ)
  // ============================================================================

  /// Tác dụng:
  /// - Hiển thị từng thẻ tiện ích: checkbox custom, nhãn tên, badge "Tùy chọn" / "Đã chọn",
  ///   và nút X để xóa nếu là tiện ích tự nhập.
  /// Nguồn dữ liệu:
  /// - Các tham số `name`, `isSelected`, `isCustom`, `onToggle`, `onRemove`.
  Widget _buildAmenityCard({
    required String name,
    required bool isSelected,
    required bool isCustom,
    required VoidCallback onToggle,
    VoidCallback? onRemove,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? _softBlueBg : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? _primaryBlue : _borderGray,
              width: isSelected ? 1.4 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: isSelected ? _primaryBlue : Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isSelected ? _primaryBlue : const Color(0xFFCBD5E1),
                    width: 1.5,
                  ),
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check_rounded,
                        size: 15,
                        color: Colors.white,
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? _primaryBlue : _textDark,
                  ),
                ),
              ),
              if (isCustom) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDBEAFE),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Tùy chọn',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _primaryBlue,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: onRemove,
                  child: const Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: Color(0xFF64748B),
                  ),
                ),
              ] else if (isSelected)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDBEAFE),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _softBlueBorder),
                  ),
                  child: const Text(
                    'Đã chọn',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _primaryBlue,
                    ),
                  ),
                )
              else
                const Icon(
                  Icons.add_rounded,
                  size: 18,
                  color: Color(0xFF94A3B8),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Tác dụng:
  /// - Thẻ sắp xếp DẠNG CHECKBOX ("Mới nhất", "Được quan tâm nhất" - có thể chọn đồng thời).
  /// Nguồn dữ liệu:
  /// - Tham số `label`, `isSelected`, `onToggle`.
  Widget _buildSortCheckboxCard(
    String label, {
    required bool isSelected,
    required VoidCallback onToggle,
  }) {
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? _softBlueBg : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? _primaryBlue : _borderGray,
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: isSelected ? _primaryBlue : Colors.white,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: isSelected ? _primaryBlue : const Color(0xFFCBD5E1),
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: Colors.white,
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? _primaryBlue : _textDark,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tác dụng:
  /// - Thẻ sắp xếp DẠNG RADIO ("Giá thấp đến cao", "Giá cao đến thấp" - luôn chọn 1 trong 2).
  /// Nguồn dữ liệu:
  /// - Tham số `label`, `isSelected`, `onTap`.
  Widget _buildSortRadioCard(
    String label, {
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? _softBlueBg : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? _primaryBlue : _borderGray,
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? _primaryBlue : const Color(0xFFCBD5E1),
                  width: 1.8,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: const BoxDecoration(
                          color: _primaryBlue,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? _primaryBlue : _textDark,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // 13. FEED & STATUS STATES (Nội dung danh sách bài đăng & các trạng thái)
  // ============================================================================

  /// Tác dụng:
  /// - Hiển thị thẻ thông báo chào mừng & mô tả mục đích của Bảng tin kết nối.
  /// Nguồn dữ liệu:
  /// - `profile` người dùng hiện tại.
  Widget _buildWelcomeCard(UserProfile? profile) {
    return Container(
      decoration: BoxDecoration(
        color: _softBlueBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _softBlueBorder),
      ),
      padding: const EdgeInsets.all(12),
      child: const Row(
        children: [
          CircleAvatar(
            backgroundColor: Color(0xFFDBEAFE),
            radius: 18,
            child: Icon(Icons.people_alt, color: _primaryBlue, size: 20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Bảng tin kết nối chia sẻ khách thuê & hợp tác quản lý phòng trọ.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF1E3A8A),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Tác dụng:
  /// - Phân loại và hiển thị danh sách bài đăng đối tác hoặc các trạng thái tương ứng:
  ///   Đang tải, Lỗi, Không có bài đăng nào, hoặc Không tìm thấy kết quả theo bộ lọc.
  /// Nguồn dữ liệu:
  /// - `postsAsync`: Stream danh sách bài đăng từ `hostHomePostsProvider` (Firestore 'posts').
  /// - `filterState`: Trạng thái bộ lọc từ `hostHomeFilterProvider`.
  Widget _buildFeedContent(
    AsyncValue<List<HostPostModel>> postsAsync,
    HostHomeFilterState filterState,
  ) {
    return postsAsync.when(
      loading: () => _buildLoadingState(),
      error: (error, stack) => _buildErrorState(error),
      data: (posts) {
        if (posts.isEmpty) {
          final hasSpecificLocation =
              filterState.selectedLocations.isNotEmpty &&
              !filterState.selectedLocations.any(
                (l) =>
                    l.toLowerCase().contains('toàn quốc') ||
                    l.toLowerCase().contains('tất cả'),
              );
          final isFiltering =
              filterState.searchQuery.isNotEmpty ||
              hasSpecificLocation ||
              filterState.minPrice != null ||
              filterState.maxPrice != null ||
              filterState.selectedAmenities.isNotEmpty ||
              filterState.customRequirements.isNotEmpty;

          return isFiltering ? _buildNoFilterResultState() : _buildEmptyState();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Row(
                children: [
                  const Text(
                    'Bài đăng từ đối tác',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _textDark,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _softBlueBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${posts.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _primaryBlue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            for (final post in posts)
              HostPostCard(
                key: ValueKey(post.id),
                post: post,
                onInterestPressed: () async {
                  final profile = ref.read(userProfileProvider).value;
                  final uid = profile?.uid ?? '';
                  if (uid.isEmpty) {
                    _showNotice('Vui lòng đăng nhập để lưu quan tâm');
                    return;
                  }
                  await ref
                      .read(hostPostRepositoryProvider)
                      .toggleInterest(postId: post.id, userId: uid);
                },
                onChatPressed: () {
                  final profile = ref.read(userProfileProvider).value;
                  final myUid = profile?.uid ?? '';
                  final myName = profile?.displayName.isNotEmpty == true
                      ? profile!.displayName
                      : 'Chủ trọ';
                  ref
                      .read(hostPostRepositoryProvider)
                      .openChatWithHost(
                        context,
                        post,
                        currentUserId: myUid,
                        currentUserName: myName,
                      );
                },
              ),
          ],
        );
      },
    );
  }

  /// Tác dụng:
  /// - Hiển thị trạng thái đang tải bài đăng từ Firestore (vòng xoay xoay).
  Widget _buildLoadingState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          children: [
            CircularProgressIndicator(strokeWidth: 2.5, color: _primaryBlue),
            SizedBox(height: 16),
            Text(
              'Đang tải bảng tin đối tác...',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

  /// Tác dụng:
  /// - Hiển thị trạng thái lỗi khi Firestore gặp sự cố (mất quyền, mất mạng hoặc lỗi khác)
  ///   kèm nút "Thử lại".
  /// Nguồn dữ liệu:
  /// - `error`: Ngoại lệ bắt được từ `postsAsync.error`.
  Widget _buildErrorState(Object error) {
    bool isPermissionError = false;
    bool isNetworkError = false;
    String errorMessage = 'Không thể tải bảng tin. Vui lòng thử lại sau.';

    if (error is FirebaseException) {
      if (error.code == 'permission-denied') {
        isPermissionError = true;
        errorMessage =
            'Chưa có quyền đọc bài đăng từ Firestore. Kiểm tra quyền tài khoản chủ trọ.';
      } else if (error.code == 'unavailable' ||
          error.code == 'network-request-failed') {
        isNetworkError = true;
        errorMessage =
            'Lỗi kết nối mạng đến Firebase. Vui lòng kiểm tra internet.';
      }
    }

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFFEE2E2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(
              isPermissionError
                  ? Icons.lock_outline
                  : (isNetworkError
                        ? Icons.wifi_off_outlined
                        : Icons.error_outline),
              size: 48,
              color: const Color(0xFFEF4444),
            ),
            const SizedBox(height: 14),
            Text(
              isPermissionError
                  ? 'Lỗi phân quyền Firestore'
                  : (isNetworkError ? 'Lỗi kết nối mạng' : 'Đã có lỗi xảy ra'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => ref.invalidate(hostHomePostsProvider),
              style: FilledButton.styleFrom(backgroundColor: _primaryBlue),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }

  /// Tác dụng:
  /// - Hiển thị giao diện rỗng khi hệ thống chưa có bất kỳ bài đăng nào từ đối tác.
  Widget _buildEmptyState() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: _borderGray),
      ),
      child: const Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.dynamic_feed_outlined,
              size: 56,
              color: Color(0xFF94A3B8),
            ),
            SizedBox(height: 14),
            Text(
              'Chưa có bài đăng nào từ đối tác',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Các bài đăng mới từ chủ trọ khác sẽ hiển thị tại đây khi được đăng tải.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

  /// Tác dụng:
  /// - Hiển thị giao diện khi các bài đăng không khớp với tiêu chí tìm kiếm / bộ lọc,
  ///   kèm nút "Xóa bộ lọc" để đặt lại về danh sách đầy đủ.
  Widget _buildNoFilterResultState() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: _borderGray),
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 52,
              color: Color(0xFFF59E0B),
            ),
            const SizedBox(height: 14),
            const Text(
              'Không tìm thấy bài đăng phù hợp',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Hãy thử thay đổi từ khoá tìm kiếm hoặc đặt lại các tiêu chí bộ lọc.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {
                _searchController.clear();
                _resetAdvancedFilter();
                ref.read(hostHomeFilterProvider.notifier).clearLocations();
                ref.read(hostHomeFilterProvider.notifier).setSearchQuery('');
              },
              child: const Text('Xóa bộ lọc'),
            ),
          ],
        ),
      ),
    );
  }
}
