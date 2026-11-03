import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/room_amenities.dart';
import '../../../core/utils/room_deposit.dart';
import '../../../core/utils/vnd_input.dart';
import '../widgets/host_deposit_input.dart';
import '../../../data/models/room_model.dart';
import '../data/host_property.dart';
import '../providers/host_management_provider.dart';
import '../widgets/host_room_widgets.dart';
import '../widgets/host_area_input.dart';
import '../widgets/host_form_theme.dart';
import 'host_create_screen.dart';
import 'host_room_detail_screen.dart';

// Chủ trọ - Chỉnh sửa phòng - Luồng đi: Chi tiết mở form có sẵn dữ
// liệu; xem trước tại máy, lưu lên Firebase rồi quay về chi tiết phòng.
class HostRoomEditScreen extends ConsumerStatefulWidget {
  const HostRoomEditScreen({
    super.key,
    required this.room,
    required this.property,
  });
  final RoomModel room;
  final HostProperty property;
  @override
  ConsumerState<HostRoomEditScreen> createState() => _HostRoomEditScreenState();
}

class _HostRoomEditScreenState extends ConsumerState<HostRoomEditScreen> {
  final _form = GlobalKey<FormState>();
  final _fields = <String, TextEditingController>{};
  final _custom = TextEditingController();
  final _newImages = <HostUpload>[];
  late List<String> _images;
  late Set<String> _amenities;
  late int _floor;
  late double _area;
  int? _depositPercentage;
  bool _busy = false, _picking = false, _expanded = true;
  final _operationId = List.generate(
    16,
    (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  static const _choices = roomAmenityOptions;

  // Chủ trọ - Nạp form - Luồng đi: Sao chép giá trị gốc để chỉnh sửa;
  // giữ phiên bản phòng nhằm phát hiện người khác sửa cùng lúc.
  @override
  void initState() {
    super.initState();
    final r = widget.room;
    // Chủ trọ - Khôi phục tỷ lệ - Luồng đi: Chỉ dùng tỷ lệ khớp tiền
    // cọc thực có; dữ liệu cũ ngoài các mức cho phép cần chọn lại.
    _depositPercentage = existingRoomDepositPercentage(
      r.price,
      r.deposit,
      r.depositPercentage,
    );
    _area = r.area;
    final values = <String, String>{
      'roomCode': r.roomCode.isNotEmpty ? r.roomCode : r.maPhong,
      'title': r.title,
      'capacity': r.capacity.toString(),
      'area': '${r.area}',
      'price': r.price > 0 ? formatVnd(r.price.toInt()) : '',
      'electricityRate': (r.electricityRate != null && r.electricityRate! > 0)
          ? formatVnd(r.electricityRate!.toInt())
          : '',
      'waterRate': (r.waterRate != null && r.waterRate! > 0)
          ? formatVnd(r.waterRate!.toInt())
          : '',
      'serviceFee': (r.serviceFee != null && r.serviceFee! > 0)
          ? formatVnd(r.serviceFee!.toInt())
          : '',
      'description': r.description,
    };
    for (final entry in values.entries) {
      _fields[entry.key] = TextEditingController(text: entry.value);
    }
    _images = [...r.images];
    // Chủ trọ - Tiện ích phòng cũ - Luồng đi: Gộp các tên tương đương
    // trước khi dựng checkbox để số mục chọn và dữ liệu lưu không trùng.
    _amenities = uniqueRoomAmenities(r.amenities);
    _floor = r.floor;
    if (_images.isEmpty) {
      _loadMissingImages();
    }
    if (_amenities.isEmpty) {
      _loadMissingAmenities();
    }
  }

  Future<void> _loadMissingImages() async {
    try {
      final imgs = await ref
          .read(hostRepositoryProvider)
          .getRoomImagesFromAnhPhong(widget.room.id);
      if (mounted && imgs.isNotEmpty) {
        setState(() {
          _images = [...imgs];
        });
      }
    } catch (_) {}
  }

  Future<void> _loadMissingAmenities() async {
    try {
      final ams = await ref
          .read(hostRepositoryProvider)
          .getRoomAmenitiesFromTienIchPhong(widget.room.id);
      if (mounted && ams.isNotEmpty) {
        setState(() {
          // Chủ trọ - Nạp tiện ích bổ sung - Luồng đi: Gộp tên trùng
          // từ bảng liên kết theo cùng quy tắc với tiện ích trong phòng.
          _amenities = uniqueRoomAmenities(ams);
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    _custom.dispose();
    super.dispose();
  }

  // Chủ trọ - Chọn ảnh chỉnh sửa - Luồng đi: Thêm ảnh JPEG/PNG từ
  // máy; kiểm tra dung lượng trước khi tải Storage khi nhấn lưu.
  Future<void> _pick() async {
    setState(() => _picking = true);
    try {
      final files = await ref.read(hostImagePickerProvider).pickMultiImage();
      if (_images.length + _newImages.length + files.length > 8) {
        throw StateError('Tối đa 8 ảnh phòng.');
      }
      final uploads = <HostUpload>[];
      for (final file in files) {
        final bytes = await file.readAsBytes();
        final contentType = HostImageUtils.detectContentType(bytes);
        if (contentType == null || bytes.length > 5 * 1024 * 1024) {
          throw StateError('Chọn ảnh JPEG/PNG không quá 5 MB.');
        }
        uploads.add(HostUpload(bytes, contentType));
      }
      if (mounted) setState(() => _newImages.addAll(uploads));
    } catch (e) {
      _error(e);
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _error(Object e) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(hostErrorMessage(e))));
    }
  }

  // Chủ trọ - Giá trị chỉnh sửa - Luồng đi: Chỉ gửi trường được sửa;
  // trạng thái, khách thuê, hợp đồng và ID phòng được giữ nguyên.
  Map<String, dynamic> _patch() => {
    'title': _fields['title']!.text.trim(),
    if (_fields['roomCode']?.text.trim().isNotEmpty == true) ...{
      'roomCode': _fields['roomCode']!.text.trim().toUpperCase(),
    },
    'floor': _floor,
    'capacity': int.parse(_fields['capacity']!.text.trim()),
    'area': _area,
    'price': double.parse(vndDigits(_fields['price']!.text.trim())),
    'depositPercentage': _depositPercentage,
    'deposit': roomDeposit(
      double.parse(vndDigits(_fields['price']!.text.trim())),
      _depositPercentage!,
    ),
    for (final key in ['electricityRate', 'waterRate', 'serviceFee'])
      key: double.tryParse(vndDigits(_fields[key]!.text.trim())),
    'amenities': _amenities.toList(),
    'description': _fields['description']!.text.trim(),
  };
  bool _validate() {
    if (!_form.currentState!.validate()) return false;
    if (_images.isEmpty && _newImages.isEmpty) {
      _error(StateError('Giữ ít nhất một ảnh phòng.'));
      return false;
    }
    return true;
  }

  Future<void> _preview() async {
    if (!_validate()) return;
    final room = RoomModel.fromMap({
      ...widget.room.toMap(),
      ..._patch(),
      'images': _images,
    }, widget.room.id);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HostRoomDetailScreen(
          propertyId: room.propertyId,
          roomId: room.id,
          previewRoom: room,
          previewImages: [..._newImages],
        ),
      ),
    );
  }

  // Chủ trọ - Lưu phòng - Luồng đi: Khóa thao tác khi gửi; Firebase
  // cập nhật xong mới đóng form, lỗi vẫn giữ nguyên nội dung đã nhập.
  Future<void> _save() async {
    if (!_validate()) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(hostRepositoryProvider)
          .updateRoom(widget.room, _patch(), _images, _newImages, _operationId);
      if (mounted) {
        setState(() => _busy = false);
        Navigator.pop(context, 'saved');
      }
    } catch (e) {
      _error(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    setState(() => _busy = true);
    final deleted = await hostDeleteRoom(context, ref, widget.room);
    if (!mounted) return;
    setState(() => _busy = false);
    if (deleted) Navigator.pop(context, 'deleted');
  }

  // Chủ trọ - Giao diện chỉnh sửa - Luồng đi: Nhóm ảnh, thông tin,
  // phí, tiện ích và khách thuê theo mẫu; nút lưu cố định cuối màn hình.
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy && !_picking,
    child: Scaffold(
      backgroundColor: const Color(0xFFF7F8FF),
      appBar: AppBar(title: const Text('Chỉnh sửa phòng')),
      body: AbsorbPointer(
        absorbing: _busy || _picking,
        child: Form(
          key: _form,
          child: ListView(
            scrollCacheExtent: const ScrollCacheExtent.pixels(5000),
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  HostRoomBadge(room: widget.room),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.room.contractId,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: _preview,
                    child: const Text('Xem trước'),
                  ),
                ],
              ),
              HostRoomSection(
                title: 'Hình ảnh phòng',
                icon: Icons.photo_library_outlined,
                trailing: Text(
                  '${_images.length + _newImages.length}/8 ảnh',
                  style: const TextStyle(fontSize: 11),
                ),
                child: SizedBox(
                  height: 110,
                  child: ListView(
                    scrollCacheExtent: const ScrollCacheExtent.pixels(5000),
                    scrollDirection: Axis.horizontal,
                    children: [
                      SizedBox(
                        width: 100,
                        child: InkWell(
                          onTap: _pick,
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F4FF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_a_photo_outlined,
                                  color: AppColors.primary,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  '+ Thêm ảnh',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      for (var i = 0; i < _images.length; i++)
                        _photo(
                          Image.network(
                            webHtmlElementStrategy:
                                WebHtmlElementStrategy.fallback,
                            _images[i],
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                const Icon(Icons.broken_image_outlined),
                          ),
                          () => setState(() => _images.removeAt(i)),
                        ),
                      for (var i = 0; i < _newImages.length; i++)
                        _photo(
                          Image.memory(_newImages[i].bytes, fit: BoxFit.cover),
                          () => setState(() => _newImages.removeAt(i)),
                        ),
                    ],
                  ),
                ),
              ),
              HostRoomSection(
                title: 'Thông tin cơ bản',
                icon: Icons.apartment,
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _field('roomCode', 'Mã phòng', numeric: false),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: _floor,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Tầng',
                            ),
                            items: [
                              for (
                                var i = 1;
                                i <= max(widget.property.floors, _floor);
                                i++
                              )
                                DropdownMenuItem(
                                  value: i,
                                  child: Text('Tầng $i'),
                                ),
                            ],
                            onChanged: (v) => setState(() => _floor = v!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Chủ trọ - Danh tính phòng - Luồng đi: Giữ mã đã cấp
                    // và ID liên kết; chủ trọ chỉ sửa tên hiển thị của phòng.
                    _field('title', 'Tên phòng *', numeric: false),
                    const SizedBox(height: 16),
                    HostAreaInput(
                      value: _area,
                      onChanged: (value) => setState(() => _area = value),
                    ),
                    _field('capacity', 'Số người ở tối đa *', suffix: 'người'),
                    const SizedBox(height: 16),
                    _field('price', 'Giá thuê tháng *', suffix: 'đ/tháng'),
                    const SizedBox(height: 16),
                    HostDepositInput(
                      priceController: _fields['price']!,
                      percentage: _depositPercentage,
                      formattedPrice: true,
                      legacyDeposit: widget.room.deposit,
                      onChanged: (value) =>
                          setState(() => _depositPercentage = value),
                    ),
                  ],
                ),
              ),
              HostRoomSection(
                title: 'Điện, Nước & Dịch vụ',
                icon: Icons.bolt,
                child: Column(
                  children: [
                    _field(
                      'electricityRate',
                      'Tiền điện',
                      suffix: 'đ/kWh',
                      optional: true,
                    ),
                    const SizedBox(height: 16),
                    _field(
                      'waterRate',
                      'Tiền nước',
                      suffix: 'đ/m³',
                      optional: true,
                    ),
                    const SizedBox(height: 16),
                    _field(
                      'serviceFee',
                      'Wifi + Rác + Vệ sinh',
                      suffix: 'đ/tháng',
                      optional: true,
                    ),
                  ],
                ),
              ),
              HostRoomSection(
                title: 'Tiện ích & Trang bị',
                icon: Icons.tune,
                trailing: Text(
                  '${_amenities.length} chọn',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF00865B),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _custom,
                            maxLength: 60,
                            decoration: const InputDecoration(
                              hintText: 'Thêm tiện ích...',
                              counterText: '',
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        TextButton(
                          onPressed: () {
                            // Chủ trọ - Thêm tiện ích khi sửa phòng - Luồng đi:
                            // Dùng cùng quy tắc với tạo phòng; mục tương đương
                            // được chọn lại và thông báo, không thêm dòng mới.
                            final value = cleanRoomAmenity(_custom.text);
                            if (value.isNotEmpty && value.length <= 60) {
                              final match = matchingRoomAmenity(
                                value,
                                _amenities,
                              );
                              setState(() {
                                _amenities.add(match ?? value);
                                _expanded = true;
                              });
                              _custom.clear();
                              if (match != null) {
                                _error(
                                  StateError(
                                    'Tiện ích "$match" đã có, đã chọn mục có sẵn.',
                                  ),
                                );
                              }
                            }
                          },
                          child: const Text('Thêm'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    for (final value in {
                      ..._amenities,
                      if (_expanded) ..._choices,
                    })
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: _amenities.contains(value)
                              ? const Color(0xFFE8FCF4)
                              : Colors.white,
                          border: Border.all(
                            color: _amenities.contains(value)
                                ? const Color(0xFF8BD4B8)
                                : const Color(0xFFE3E6EF),
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: CheckboxListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(
                              value,
                              style: const TextStyle(fontSize: 12),
                            ),
                            value: _amenities.contains(value),
                            onChanged: (checked) => setState(() {
                              if (checked == true) {
                                _amenities.add(value);
                              } else {
                                _amenities.remove(value);
                              }
                            }),
                          ),
                        ),
                      ),
                    TextButton(
                      onPressed: () => setState(() => _expanded = !_expanded),
                      child: Text(_expanded ? 'Thu gọn ↑' : 'Xem thêm ↓'),
                    ),
                  ],
                ),
              ),
              HostRoomSection(
                title: 'Mô tả phòng',
                icon: Icons.notes,
                child: _field(
                  'description',
                  'Thông tin bổ sung',
                  numeric: false,
                  optional: true,
                  maxLines: 3,
                ),
              ),
              HostRoomTenant(room: widget.room),
              TextButton(
                onPressed: _delete,
                child: const Text(
                  'Xóa phòng này',
                  style: TextStyle(color: AppColors.danger),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            key: const ValueKey('save_room'),
            onPressed: _busy || _picking ? null : _save,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('Lưu thay đổi'),
          ),
        ),
      ),
    ),
  );

  // Chủ trọ - Kiểm tra trường sửa - Luồng đi: Báo lỗi ngay tại ô;
  // giá, diện tích phải dương, phí và tiền cọc không được âm.
  Widget _field(
    String key,
    String label, {
    bool numeric = true,
    bool optional = false,
    String? suffix,
    int maxLines = 1,
  }) {
    final isMoney =
        key == 'price' ||
        key == 'deposit' ||
        key == 'electricityRate' ||
        key == 'waterRate' ||
        key == 'serviceFee';
    return TextFormField(
      key: ValueKey('edit_$key'),
      controller: _fields[key],
      readOnly: key == 'roomCode',
      maxLines: maxLines,
      keyboardType: numeric || isMoney
          ? (isMoney
                ? TextInputType.number
                : const TextInputType.numberWithOptions(decimal: true))
          : TextInputType.text,
      inputFormatters: isMoney ? [VndInputFormatter()] : null,
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        suffixIcon: key == 'roomCode' ? const Icon(Icons.lock_outline) : null,
        filled: true,
        fillColor: const Color(0xFFF0F4FF),
      ),
      validator: (raw) {
        final value = raw?.trim() ?? '';
        if (optional && value.isEmpty) return null;
        if (value.isEmpty) return 'Vui lòng nhập';
        if (!numeric && !isMoney) {
          if (key == 'title' && value.length > 100) return 'Tối đa 100 ký tự';
          return null;
        }
        if (key == 'capacity') {
          final capacity = int.tryParse(value);
          return capacity == null || capacity < 1 || capacity > 1000000000
              ? 'Nhập số nguyên từ 1 trở lên'
              : null;
        }
        final cleaned = isMoney ? vndDigits(value) : value;
        final number = double.tryParse(cleaned);
        if (number == null ||
            !number.isFinite ||
            number < 0 ||
            number > 1000000000 ||
            ((key == 'area' || key == 'price') && number == 0)) {
          return 'Giá trị không hợp lệ';
        }
        return null;
      },
    );
  }

  Widget _photo(Widget image, VoidCallback remove) => Container(
    width: 100,
    margin: const EdgeInsets.only(right: 8),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          image,
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              tooltip: 'Bỏ ảnh',
              onPressed: remove,
              icon: const Icon(Icons.cancel, color: Colors.black54),
            ),
          ),
        ],
      ),
    ),
  );
}
