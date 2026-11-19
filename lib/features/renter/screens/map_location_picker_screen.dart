import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/vietnam_map_landmarks.dart';
import '../../../core/utils/map_address_locator.dart';

/// Kết quả người dùng chọn vị trí trên bản đồ
class MapPickedLocation {
  final double latitude;
  final double longitude;
  final String address;
  final String? category;
  final String? subtitle;

  const MapPickedLocation({
    required this.latitude,
    required this.longitude,
    required this.address,
    this.category,
    this.subtitle,
  });

  LatLng get latLng => LatLng(latitude, longitude);

  @override
  String toString() => 'MapPickedLocation($latitude, $longitude, "$address", category: $category)';
}

/// Màn hình chọn địa điểm trực tiếp trên bản đồ tương tác trong ứng dụng
class MapLocationPickerScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
  final String? initialLabel;
  final String title;

  const MapLocationPickerScreen({
    super.key,
    this.initialLat,
    this.initialLng,
    this.initialLabel,
    this.title = 'Chọn địa điểm trên bản đồ',
  });

  @override
  State<MapLocationPickerScreen> createState() => _MapLocationPickerScreenState();
}

class _MapLocationPickerScreenState extends State<MapLocationPickerScreen> {
  late final MapController _mapController;
  late LatLng _currentCenter;
  String _currentAddress = 'Đang tải thông tin vị trí...';
  bool _isLocatingGps = false;
  bool _isGeocoding = false;
  Timer? _debounceTimer;

  final TextEditingController _searchController = TextEditingController();
  List<MapPickedLocation> _searchResults = [];
  bool _isSearching = false;

  // Danh mục chọn nhanh các nhóm địa danh
  static const List<Map<String, String>> _categoryChips = [
    {'label': '🎓 Cao đẳng', 'query': 'Cao đẳng'},
    {'label': '🏛️ Đại học', 'query': 'Đại học'},
    {'label': '🚌 Bến xe & Ga', 'query': 'Bến xe'},
    {'label': '🏥 Bệnh viện', 'query': 'Bệnh viện'},
    {'label': '🏙️ Địa danh', 'query': 'Địa danh'},
    {'label': '📍 Khu vực', 'query': 'Quận'},
  ];

  // Danh sách các địa điểm phổ biến để chọn nhanh
  static const List<Map<String, dynamic>> _presetLandmarks = [
    {'name': 'Quận 1 (Trung tâm TP.HCM)', 'lat': 10.7769, 'lng': 106.7009},
    {'name': 'Đại học Quốc Gia TP.HCM', 'lat': 10.8700, 'lng': 106.8031},
    {'name': 'Đại học Bách Khoa (Q.10)', 'lat': 10.7725, 'lng': 106.6578},
    {'name': 'Đại học Tôn Đức Thắng (Q.7)', 'lat': 10.7324, 'lng': 106.6992},
    {'name': 'Landmark 81 (Bình Thạnh)', 'lat': 10.7950, 'lng': 106.7219},
    {'name': 'Chợ Bến Thành (Q.1)', 'lat': 10.7725, 'lng': 106.6980},
    {'name': 'Hồ Hoàn Kiếm (Hà Nội)', 'lat': 21.0285, 'lng': 105.8542},
    {'name': 'Cầu Rồng (Đà Nẵng)', 'lat': 16.0610, 'lng': 108.2274},
  ];

  IconData _getCategoryIcon(String? category) {
    switch (category) {
      case 'Cao đẳng':
        return Icons.school_rounded;
      case 'Đại học':
        return Icons.account_balance_rounded;
      case 'Bến xe & Ga':
        return Icons.directions_bus_rounded;
      case 'Bệnh viện':
        return Icons.local_hospital_rounded;
      case 'Địa danh':
        return Icons.apartment_rounded;
      case 'Khu vực':
        return Icons.explore_rounded;
      default:
        return Icons.place_rounded;
    }
  }

  Color _getCategoryColor(String? category) {
    switch (category) {
      case 'Cao đẳng':
        return const Color(0xFFF57C00);
      case 'Đại học':
        return const Color(0xFF1976D2);
      case 'Bến xe & Ga':
        return const Color(0xFF00897B);
      case 'Bệnh viện':
        return const Color(0xFFE53935);
      case 'Địa danh':
        return const Color(0xFF8E24AA);
      case 'Khu vực':
        return const Color(0xFF3949AB);
      default:
        return AppColors.primary;
    }
  }

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _currentCenter = LatLng(
      widget.initialLat ?? 10.7769,
      widget.initialLng ?? 106.7009,
    );
    _currentAddress = widget.initialLabel ?? 'Quận 1 (Trung tâm TP.HCM)';

    // Nếu chưa có nhãn cụ thể, thực hiện tra cứu ngược
    if (widget.initialLabel == null || widget.initialLabel!.isEmpty) {
      _reverseGeocode(_currentCenter);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Tra cứu tên địa chỉ từ tọa độ
  Future<void> _reverseGeocode(LatLng point) async {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 600), () async {
      if (!mounted) return;
      setState(() => _isGeocoding = true);

      // Thử tìm địa chỉ qua Photon reverse
      String resolved = '';
      try {
        final client = HttpClient();
        final uri = Uri.https('photon.komoot.io', '/reverse', {
          'lat': point.latitude.toString(),
          'lon': point.longitude.toString(),
        });
        final request = await client.getUrl(uri);
        request.headers.set(
          HttpHeaders.userAgentHeader,
          'HomeShare/1.0 (com.homeshare.app.home_share)',
        );
        final response = await request.close().timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) {
          final body = await response.transform(utf8.decoder).join();
          final data = jsonDecode(body);
          if (data is Map && data['features'] is List && (data['features'] as List).isNotEmpty) {
            final props = data['features'][0]['properties'] as Map?;
            if (props != null) {
              final name = props['name']?.toString() ?? '';
              final street = props['street']?.toString() ?? '';
              final district = props['district']?.toString() ?? props['city']?.toString() ?? '';
              final parts = [name, street, district].where((s) => s.trim().isNotEmpty).toList();
              if (parts.isNotEmpty) {
                resolved = parts.join(', ');
              }
            }
          }
        }
        client.close(force: true);
      } catch (_) {}

      // Dự phòng từ tọa độ gần nhất hoặc format đẹp
      if (resolved.isEmpty) {
        resolved = _findNearestPresetName(point) ??
            '${point.latitude.toStringAsFixed(4)}° B, ${point.longitude.toStringAsFixed(4)}° Đ';
      }

      if (mounted) {
        setState(() {
          _currentAddress = resolved;
          _isGeocoding = false;
        });
      }
    });
  }

  String? _findNearestPresetName(LatLng point) {
    for (final p in VietnamMapLandmarks.allLandmarks) {
      final dLat = (p.latitude - point.latitude).abs();
      final dLng = (p.longitude - point.longitude).abs();
      if (dLat < 0.005 && dLng < 0.005) {
        return p.name;
      }
    }
    for (final p in _presetLandmarks) {
      final lat = p['lat'] as double;
      final lng = p['lng'] as double;
      final dLat = (lat - point.latitude).abs();
      final dLng = (lng - point.longitude).abs();
      if (dLat < 0.008 && dLng < 0.008) {
        return p['name'] as String;
      }
    }
    return null;
  }

  /// Lấy vị trí GPS hiện tại của thiết bị
  Future<void> _moveToCurrentLocation() async {
    if (_isLocatingGps) return;
    setState(() => _isLocatingGps = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vui lòng bật định vị GPS trên thiết bị')),
          );
        }
        setState(() => _isLocatingGps = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Chưa cấp quyền truy cập vị trí')),
            );
          }
          setState(() => _isLocatingGps = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Quyền vị trí bị từ chối vĩnh viễn trong Cài đặt')),
          );
        }
        setState(() => _isLocatingGps = false);
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 7),
        ),
      );

      final newCenter = LatLng(pos.latitude, pos.longitude);
      _mapController.move(newCenter, 16.5);
      setState(() {
        _currentCenter = newCenter;
        _currentAddress = 'Vị trí hiện tại của bạn 📍';
        _isLocatingGps = false;
      });
      _reverseGeocode(newCenter);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể lấy vị trí hiện tại: $e')),
        );
        setState(() => _isLocatingGps = false);
      }
    }
  }

  /// Tìm kiếm địa điểm theo từ khóa (hỗ trợ Cao đẳng, Đại học, Bến xe, Bệnh viện...)
  Future<void> _performSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    final results = <MapPickedLocation>[];

    // 1. Tìm trong danh mục các điểm mốc, Cao đẳng, Đại học, Bến xe toàn quốc (Zero-latency)
    final landmarkHits = VietnamMapLandmarks.search(q, limit: 30);
    for (final item in landmarkHits) {
      results.add(MapPickedLocation(
        latitude: item.latitude,
        longitude: item.longitude,
        address: item.name,
        category: item.category,
        subtitle: item.address,
      ));
    }

    // 2. Tra cứu online qua Photon Geocoding nếu người dùng gõ tên đường/địa chỉ riêng
    try {
      final hit = await photonSearch(q, bias: _currentCenter);
      if (hit != null && isInVietnam(hit.point.latitude, hit.point.longitude)) {
        final label = hit.name.isNotEmpty
            ? hit.name
            : (hit.street.isNotEmpty ? '${hit.houseNumber} ${hit.street}' : q);
        final exists = results.any((r) =>
            (r.latitude - hit.point.latitude).abs() < 0.001 &&
            (r.longitude - hit.point.longitude).abs() < 0.001);
        if (!exists) {
          final subtitleStr = hit.street.isNotEmpty
              ? (hit.houseNumber.isNotEmpty ? '${hit.houseNumber} ${hit.street}' : hit.street)
              : null;
          results.insert(
            0,
            MapPickedLocation(
              latitude: hit.point.latitude,
              longitude: hit.point.longitude,
              address: label,
              category: 'Địa chỉ',
              subtitle: subtitleStr,
            ),
          );
        }
      }
    } catch (_) {}

    // 3. Tra cứu từ knownPlaceBias
    final bias = knownPlaceBias(q);
    if (bias != null &&
        !results.any((r) =>
            (r.latitude - bias.latitude).abs() < 0.001 &&
            (r.longitude - bias.longitude).abs() < 0.001)) {
      results.add(MapPickedLocation(
        latitude: bias.latitude,
        longitude: bias.longitude,
        address: q,
        category: 'Khu vực',
      ));
    }

    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }
  }

  void _selectSearchResult(MapPickedLocation loc) {
    final point = loc.latLng;
    _mapController.move(point, 16.5);
    setState(() {
      _currentCenter = point;
      _currentAddress = loc.address;
      _searchResults = [];
      _searchController.clear();
    });
    FocusScope.of(context).unfocus();
  }

  void _onConfirm() {
    Navigator.of(context).pop(
      MapPickedLocation(
        latitude: _currentCenter.latitude,
        longitude: _currentCenter.longitude,
        address: _currentAddress,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        actions: [
          TextButton(
            onPressed: _onConfirm,
            child: const Text(
              'Chọn điểm',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. Bản đồ FlutterMap
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentCenter,
                initialZoom: 15.5,
                minZoom: 4,
                maxZoom: 19,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
                onPositionChanged: (camera, hasGesture) {
                  if (hasGesture) {
                    _currentCenter = camera.center;
                    _reverseGeocode(camera.center);
                  }
                },
                onTap: (_, point) {
                  _mapController.move(point, _mapController.camera.zoom);
                  setState(() => _currentCenter = point);
                  _reverseGeocode(point);
                },
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

          // 2. Ghim vị trí ở chính giữa màn hình (Center Pin)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 38.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.location_on_rounded,
                      size: 34,
                      color: Colors.white,
                    ),
                  ),
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Khung tìm kiếm địa chỉ ở đầu bản đồ
          Positioned(
            top: 12,
            left: 14,
            right: 14,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Tìm trường cao đẳng, đại học, địa điểm...',
                      hintStyle: const TextStyle(fontSize: 13.5, color: AppColors.textMuted),
                      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary, size: 22),
                      suffixIcon: _isSearching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                              ),
                            )
                          : (_searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchResults = []);
                                  },
                                )
                              : null),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    onChanged: (val) {
                      if (val.trim().isNotEmpty) {
                        _performSearch(val);
                      } else {
                        setState(() => _searchResults = []);
                      }
                    },
                    onSubmitted: _performSearch,
                  ),
                ),

                // Thanh chip danh mục nhanh (Cao đẳng, Đại học, Bến xe, Bệnh viện...)
                Container(
                  height: 38,
                  margin: const EdgeInsets.only(top: 8),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categoryChips.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (ctx, idx) {
                      final chip = _categoryChips[idx];
                      final isSelected = _searchController.text.trim().toLowerCase() ==
                          chip['query']!.toLowerCase();
                      return ActionChip(
                        backgroundColor: isSelected ? AppColors.primary : Colors.white,
                        elevation: isSelected ? 3 : 2,
                        shadowColor: Colors.black26,
                        side: BorderSide(
                          color: isSelected ? AppColors.primary : Colors.grey.shade300,
                          width: 1,
                        ),
                        label: Text(
                          chip['label']!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : AppColors.textDark,
                          ),
                        ),
                        onPressed: () {
                          if (isSelected) {
                            _searchController.clear();
                            setState(() => _searchResults = []);
                          } else {
                            _searchController.text = chip['query']!;
                            _performSearch(chip['query']!);
                          }
                        },
                      );
                    },
                  ),
                ),

                // Danh sách gợi ý tìm kiếm
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    constraints: const BoxConstraints(maxHeight: 280),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.16),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                          ),
                          child: Row(
                            children: [
                              Text(
                                'Tìm thấy ${_searchResults.length} gợi ý',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: () {
                                  setState(() => _searchResults = []);
                                },
                                child: const Text(
                                  'Đóng',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        Flexible(
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            shrinkWrap: true,
                            itemCount: _searchResults.length,
                            separatorBuilder: (_, _) => const Divider(height: 1, indent: 48),
                            itemBuilder: (ctx, idx) {
                              final item = _searchResults[idx];
                              final icon = _getCategoryIcon(item.category);
                              final color = _getCategoryColor(item.category);

                              return ListTile(
                                dense: true,
                                leading: Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(icon, color: color, size: 18),
                                ),
                                title: Row(
                                  children: [
                                    if (item.category != null && item.category!.isNotEmpty) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        margin: const EdgeInsets.only(right: 6),
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          item.category!,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: color,
                                          ),
                                        ),
                                      ),
                                    ],
                                    Expanded(
                                      child: Text(
                                        item.address,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: item.subtitle != null && item.subtitle!.isNotEmpty
                                    ? Text(
                                        item.subtitle!,
                                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      )
                                    : null,
                                onTap: () => _selectSearchResult(item),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                // Khi chưa tìm kiếm: gợi ý các điểm mốc phổ biến
                if (_searchResults.isEmpty && _searchController.text.isEmpty)
                  Container(
                    height: 36,
                    margin: const EdgeInsets.only(top: 8),
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _presetLandmarks.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (ctx, idx) {
                        final p = _presetLandmarks[idx];
                        final name = p['name'] as String;
                        return ActionChip(
                          backgroundColor: Colors.white,
                          elevation: 1.5,
                          shadowColor: Colors.black12,
                          side: BorderSide(color: Colors.grey.shade200, width: 1),
                          label: Text(
                            name.split('(').first.trim(),
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500),
                          ),
                          avatar: const Icon(Icons.near_me_rounded, size: 13, color: AppColors.textSecondary),
                          onPressed: () {
                            _selectSearchResult(MapPickedLocation(
                              latitude: p['lat'] as double,
                              longitude: p['lng'] as double,
                              address: name,
                              category: 'Điểm mốc',
                            ));
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // 4. Nút lấy vị trí hiện tại (GPS button)
          Positioned(
            right: 16,
            bottom: 170,
            child: FloatingActionButton(
              heroTag: 'map_gps_btn',
              mini: true,
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
              elevation: 4,
              onPressed: _moveToCurrentLocation,
              tooltip: 'Vị trí hiện tại của tôi',
              child: _isLocatingGps
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                    )
                  : const Icon(Icons.my_location_rounded, size: 22),
            ),
          ),

          // 5. Thẻ xác nhận điểm mốc vị trí ở đáy màn hình
          Positioned(
            left: 14,
            right: 14,
            bottom: 18,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.location_pin, color: AppColors.primary, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Điểm mốc so sánh khoảng cách:',
                                style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                              ),
                              const SizedBox(height: 2),
                              _isGeocoding
                                  ? const Text(
                                      'Đang xác định địa chỉ...',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textSecondary,
                                      ),
                                    )
                                  : Text(
                                      _currentAddress,
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textDark,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _onConfirm,
                      icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                      label: const Text(
                        'Xác nhận điểm mốc này',
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
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
}

