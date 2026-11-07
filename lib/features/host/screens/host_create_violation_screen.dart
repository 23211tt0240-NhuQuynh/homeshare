import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/user_provider.dart';
import '../data/host_property.dart';
import '../providers/host_management_provider.dart';
import '../providers/violation_form_provider.dart';
import '../providers/violation_provider.dart';
import '../repositories/violation_repository.dart';
import '../widgets/evidence_picker.dart';
import '../widgets/violation_type_selector.dart';

class _PropertyOption {
  final String id;
  final String name;
  final int occupiedRoomCount;

  const _PropertyOption({
    required this.id,
    required this.name,
    required this.occupiedRoomCount,
  });
}

class HostCreateViolationScreen extends ConsumerStatefulWidget {
  const HostCreateViolationScreen({super.key});

  @override
  ConsumerState<HostCreateViolationScreen> createState() =>
      _HostCreateViolationScreenState();
}

class _HostCreateViolationScreenState
    extends ConsumerState<HostCreateViolationScreen> {
  final _noteController = TextEditingController();
  String? _selectedPropertyId;
  String? _selectedRoomId;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  String _formatNumber(double amount) {
    final s = amount.toInt().toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      buffer.write(s[i]);
      count++;
      if (count % 3 == 0 && i != 0) {
        buffer.write('.');
      }
    }
    return buffer.toString().split('').reversed.join();
  }

  Future<void> _handleSave() async {
    final user = ref.read(userProfileProvider).value;
    final hostId = user?.uid ?? '';
    if (hostId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập tài khoản chủ trọ')),
      );
      return;
    }

    // Cập nhật note vào provider trước khi submit
    ref
        .read(violationFormNotifierProvider.notifier)
        .setNote(_noteController.text);

    final success = await ref
        .read(violationFormNotifierProvider.notifier)
        .submit(hostId);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã lưu biên bản vi phạm thành công!'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
      Navigator.of(context).pop(true);
    } else {
      final errorMsg = ref.read(violationFormNotifierProvider).errorMessage ??
          'Có lỗi xảy ra khi lưu biên bản';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  Widget _buildRoomSelector(
    List<HostProperty> allProperties,
    List<HostOccupiedRoomItem> rooms,
    HostOccupiedRoomItem? selectedRoom,
  ) {
    final hasRooms = rooms.isNotEmpty;

    // 1. Tổng hợp danh sách Nhà / Khu nhà
    final propertyOptions = <_PropertyOption>[];
    final seenPropIds = <String>{};

    for (final p in allProperties) {
      if (!seenPropIds.contains(p.id)) {
        seenPropIds.add(p.id);
        final count = rooms
            .where((r) => r.propertyId == p.id)
            .map((r) => r.roomId)
            .toSet()
            .length;
        propertyOptions.add(
          _PropertyOption(
            id: p.id,
            name: p.name.isNotEmpty ? p.name : 'Nhà trọ',
            occupiedRoomCount: count,
          ),
        );
      }
    }

    for (final r in rooms) {
      final pid = r.propertyId.isNotEmpty ? r.propertyId : r.propertyName;
      if (pid.isNotEmpty && !seenPropIds.contains(pid)) {
        seenPropIds.add(pid);
        final count = rooms
            .where((x) =>
                (x.propertyId.isNotEmpty ? x.propertyId : x.propertyName) ==
                pid)
            .map((x) => x.roomId)
            .toSet()
            .length;
        propertyOptions.add(
          _PropertyOption(
            id: pid,
            name: r.propertyName.isNotEmpty ? r.propertyName : 'Khu nhà trọ',
            occupiedRoomCount: count,
          ),
        );
      }
    }

    // Tự động gán nếu đã có selectedRoom hoặc chỉ có 1 khu nhà
    if (_selectedPropertyId == null) {
      if (selectedRoom != null) {
        _selectedPropertyId = selectedRoom.propertyId.isNotEmpty
            ? selectedRoom.propertyId
            : selectedRoom.propertyName;
      } else if (propertyOptions.length == 1) {
        _selectedPropertyId = propertyOptions.first.id;
      }
    }

    // 2. Lọc danh sách phòng thuộc khu nhà được chọn
    final roomsInSelectedProperty = _selectedPropertyId != null
        ? rooms.where((r) {
            if (r.propertyId.isNotEmpty) {
              return r.propertyId == _selectedPropertyId;
            }
            return r.propertyName == _selectedPropertyId;
          }).toList()
        : <HostOccupiedRoomItem>[];

    final uniqueRoomMap = <String, HostOccupiedRoomItem>{};
    for (final r in roomsInSelectedProperty) {
      if (!uniqueRoomMap.containsKey(r.roomId)) {
        uniqueRoomMap[r.roomId] = r;
      }
    }
    final roomOptions = uniqueRoomMap.values.toList();

    // Tự động gán nếu đã có selectedRoom hoặc chỉ có 1 phòng trong khu nhà
    if (_selectedRoomId == null) {
      if (selectedRoom != null && uniqueRoomMap.containsKey(selectedRoom.roomId)) {
        _selectedRoomId = selectedRoom.roomId;
      } else if (roomOptions.length == 1) {
        _selectedRoomId = roomOptions.first.roomId;
      }
    } else if (!uniqueRoomMap.containsKey(_selectedRoomId)) {
      _selectedRoomId = null;
    }

    // 3. Lọc danh sách người thuê trong phòng được chọn
    final tenantsInSelectedRoom = _selectedRoomId != null
        ? roomsInSelectedProperty.where((r) => r.roomId == _selectedRoomId).toList()
        : <HostOccupiedRoomItem>[];

    // Tự động chọn người thuê nếu phòng chỉ có 1 người ở
    if (_selectedRoomId != null &&
        tenantsInSelectedRoom.length == 1 &&
        (selectedRoom == null ||
            selectedRoom.uniqueKey != tenantsInSelectedRoom.first.uniqueKey)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref
            .read(violationFormNotifierProvider.notifier)
            .selectRoom(tenantsInSelectedRoom.first);
      });
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header tiêu đề
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.apartment_rounded,
                  color: Color(0xFF2563EB),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ĐỊA ĐIỂM & ĐỐI TƯỢNG VI PHẠM',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      'Chọn khu nhà ➜ chọn phòng ➜ chọn người thuê vi phạm',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // TẦNG 1: CHỌN NHÀ / KHU NHÀ TRỌ
          const Row(
            children: [
              Icon(Icons.home_work_outlined, size: 15, color: Color(0xFF2563EB)),
              SizedBox(width: 6),
              Text(
                '1. Chọn nhà / khu nhà trọ',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF334155),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _selectedPropertyId != null &&
                        propertyOptions.any((p) => p.id == _selectedPropertyId)
                    ? _selectedPropertyId
                    : null,
                hint: Text(
                  propertyOptions.isNotEmpty
                      ? 'Chọn nhà / khu nhà...'
                      : 'Chưa có khu nhà nào',
                  style: const TextStyle(fontSize: 13.5, color: Color(0xFF94A3B8)),
                ),
                icon: const Icon(Icons.unfold_more_rounded,
                    color: Color(0xFF64748B)),
                items: propertyOptions.map((item) {
                  return DropdownMenuItem<String>(
                    value: item.id,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (item.occupiedRoomCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${item.occupiedRoomCount} phòng đang ở',
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF16A34A),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null && val != _selectedPropertyId) {
                    setState(() {
                      _selectedPropertyId = val;
                      _selectedRoomId = null;
                    });
                    ref
                        .read(violationFormNotifierProvider.notifier)
                        .selectRoom(null);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 14),

          // TẦNG 2: CHỌN PHÒNG THUỘC KHU NHÀ
          const Row(
            children: [
              Icon(Icons.meeting_room_outlined, size: 15, color: Color(0xFF2563EB)),
              SizedBox(width: 6),
              Text(
                '2. Chọn phòng thuộc khu nhà',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF334155),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: _selectedPropertyId != null
                  ? const Color(0xFFF8FAFC)
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _selectedPropertyId != null
                    ? const Color(0xFFCBD5E1)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _selectedRoomId != null &&
                        roomOptions.any((r) => r.roomId == _selectedRoomId)
                    ? _selectedRoomId
                    : null,
                hint: Text(
                  _selectedPropertyId == null
                      ? 'Vui lòng chọn khu nhà trước...'
                      : (roomOptions.isNotEmpty
                          ? 'Chọn phòng...'
                          : 'Khu nhà này chưa có phòng nào có người đang ở'),
                  style: TextStyle(
                    fontSize: 13.5,
                    color: _selectedPropertyId != null
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFFCBD5E1),
                  ),
                ),
                icon: Icon(
                  Icons.unfold_more_rounded,
                  color: _selectedPropertyId != null
                      ? const Color(0xFF64748B)
                      : const Color(0xFFCBD5E1),
                ),
                items: roomOptions.map((rm) {
                  final count = roomsInSelectedProperty
                      .where((x) => x.roomId == rm.roomId)
                      .length;
                  final roomDisplay = rm.roomCode.isNotEmpty
                      ? (rm.roomCode.startsWith('P.')
                          ? rm.roomCode
                          : 'Phòng ${rm.roomCode}')
                      : 'Phòng ${rm.roomId}';

                  return DropdownMenuItem<String>(
                    value: rm.roomId,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          roomDisplay,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$count người ở',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: _selectedPropertyId != null && roomOptions.isNotEmpty
                    ? (val) {
                        if (val != null && val != _selectedRoomId) {
                          setState(() {
                            _selectedRoomId = val;
                          });
                          final tenants = roomsInSelectedProperty
                              .where((x) => x.roomId == val)
                              .toList();
                          if (tenants.length == 1) {
                            ref
                                .read(violationFormNotifierProvider.notifier)
                                .selectRoom(tenants.first);
                          } else {
                            ref
                                .read(violationFormNotifierProvider.notifier)
                                .selectRoom(null);
                          }
                        }
                      }
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // TẦNG 3: CHỌN NGƯỜI THUÊ PHÒNG (KÈM NGƯỜI THUÊ PHÒNG)
          const Row(
            children: [
              Icon(Icons.person_outline_rounded,
                  size: 15, color: Color(0xFF2563EB)),
              SizedBox(width: 6),
              Text(
                '3. Chọn người thuê vi phạm',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF334155),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: _selectedRoomId != null
                  ? const Color(0xFFF8FAFC)
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _selectedRoomId != null
                    ? const Color(0xFFCBD5E1)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: selectedRoom != null &&
                        tenantsInSelectedRoom
                            .any((t) => t.uniqueKey == selectedRoom.uniqueKey)
                    ? selectedRoom.uniqueKey
                    : null,
                hint: Text(
                  _selectedRoomId == null
                      ? 'Vui lòng chọn phòng trước...'
                      : (tenantsInSelectedRoom.isNotEmpty
                          ? 'Chọn người thuê vi phạm...'
                          : 'Không tìm thấy người thuê đang ở'),
                  style: TextStyle(
                    fontSize: 13.5,
                    color: _selectedRoomId != null
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFFCBD5E1),
                  ),
                ),
                icon: Icon(
                  Icons.unfold_more_rounded,
                  color: _selectedRoomId != null
                      ? const Color(0xFF64748B)
                      : const Color(0xFFCBD5E1),
                ),
                items: tenantsInSelectedRoom.map((item) {
                  final isMain = item.formId != 'oGhep';
                  return DropdownMenuItem<String>(
                    value: item.uniqueKey,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item.tenantName,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isMain
                                ? const Color(0xFFDCFCE7)
                                : const Color(0xFFF3E8FF),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isMain ? 'Cư dân chính' : 'Ở ghép',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: isMain
                                  ? const Color(0xFF15803D)
                                  : const Color(0xFF7E22CE),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged:
                    _selectedRoomId != null && tenantsInSelectedRoom.isNotEmpty
                        ? (val) {
                            if (val != null) {
                              final tenant = tenantsInSelectedRoom
                                  .firstWhere((t) => t.uniqueKey == val);
                              ref
                                  .read(violationFormNotifierProvider.notifier)
                                  .selectRoom(tenant);
                            }
                          }
                        : null,
              ),
            ),
          ),

          // KHỐI XÁC NHẬN ĐỐI TƯỢNG ĐÃ CHỌN
          if (selectedRoom != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: Color(0xFF2563EB), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${selectedRoom.tenantName} ${selectedRoom.formId == "oGhep" ? "(Ở ghép)" : "(Cư dân chính)"}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          'Phòng ${selectedRoom.roomCode} • ${selectedRoom.propertyName}${selectedRoom.tenantPhone.isNotEmpty ? " • SĐT: ${selectedRoom.tenantPhone}" : ""}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (!hasRooms) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFECDD3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Color(0xFFE11D48)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Hiện tại chưa có người thuê nào đang cư trú thực tế trong các phòng trọ của bạn. Chỉ có thể lập biên bản cho người đang ở thực tế.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFFBE123C),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFineAndResolution(double fineAmount) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.credit_card_outlined,
                color: Color(0xFF2563EB),
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'MỨC PHẠT & HÌNH THỨC NỘP',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Số tiền phạt (VND)',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _formatNumber(fineAmount),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                ),
                const Text(
                  'VNĐ',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 20,
                  color: Color(0xFF16A34A),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hình thức: Nộp trực tiếp ngoài ứng dụng',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF15803D),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Ứng dụng sẽ gửi thông báo chi tiết biên bản, mức phạt và hình ảnh bằng chứng đến người thuê để hai bên đối soát và nộp tiền mặt/chuyển khoản ngoài đời. Chủ trọ sẽ bấm xác nhận khi đã nhận đủ tiền.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF166534),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.edit_note_rounded,
                color: Color(0xFF2563EB),
                size: 22,
              ),
              SizedBox(width: 8),
              Text(
                'GHI CHÚ / MÔ TẢ VI PHẠM',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Nhập thời gian xảy ra, vị trí, tình trạng thực tế...',
              hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              fillColor: const Color(0xFFF8FAFC),
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF2563EB)),
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(violationFormNotifierProvider);
    final roomsAsync = ref.watch(hostOccupiedRoomsProvider);
    final violationsAsync = ref.watch(violationTypesProvider);
    final propertiesAsync = ref.watch(hostPropertiesProvider);
    final allProperties = propertiesAsync.value ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Lập biên bản vi phạm',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE2E8F0)),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Khối thông tin người vi phạm
                roomsAsync.when(
                  data: (rooms) =>
                      _buildRoomSelector(allProperties, rooms, formState.selectedRoom),
                  loading: () => Container(
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text('Lỗi tải danh sách phòng: $e'),
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Khối hành vi vi phạm
                violationsAsync.when(
                  data: (types) => ViolationTypeSelector(
                    violations: types,
                    selectedViolations: formState.selectedViolations,
                    onToggle: (item) {
                      ref
                          .read(violationFormNotifierProvider.notifier)
                          .toggleViolation(item);
                    },
                  ),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('Lỗi tải danh mục vi phạm: $e'),
                ),
                const SizedBox(height: 16),

                // 3. Khối mức phạt & hình thức xử lý
                _buildFineAndResolution(formState.fineAmount),
                const SizedBox(height: 16),

                // 4. Khối bằng chứng vi phạm
                EvidencePicker(
                  files: formState.evidenceFiles,
                  onFileAdded: (file) {
                    final err = ref
                        .read(violationFormNotifierProvider.notifier)
                        .addEvidenceFile(file);
                    if (err != null && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(err)),
                      );
                    }
                  },
                  onFileRemoved: (index) {
                    ref
                        .read(violationFormNotifierProvider.notifier)
                        .removeEvidenceFile(index);
                  },
                ),
                const SizedBox(height: 16),

                // 5. Khối ghi chú / mô tả
                _buildNoteCard(),
              ],
            ),
          ),

          // Nút cố định dưới cùng
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 10,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  height: 48,
                  child: Builder(
                    builder: (context) {
                      final hasRooms = (roomsAsync.value ?? []).isNotEmpty;
                      final isReady = hasRooms && formState.selectedRoom != null;

                      String buttonText = 'Gửi biên bản vi phạm đến người thuê';
                      if (!hasRooms) {
                        buttonText = 'Chưa có người thuê đang ở thực tế';
                      } else if (formState.selectedRoom == null) {
                        buttonText = 'Vui lòng chọn người thuê vi phạm';
                      }

                      return ElevatedButton(
                        onPressed: (!isReady || formState.isSubmitting)
                            ? null
                            : _handleSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          disabledBackgroundColor: const Color(0xFFCBD5E1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: formState.isSubmitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    isReady ? Icons.send_rounded : Icons.info_outline,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    buttonText,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
