import '../../../core/services/resident_service.dart';
import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../../../data/models/resident_model.dart';
import '../../../core/constants/firestore_collections.dart';
import '../../../data/models/booking_model.dart';
import '../../../data/models/room_model.dart';
import '../models/invoice_line_model.dart';
import '../models/violation_model.dart';
import '../models/violation_record_model.dart';
import '../providers/violation_form_provider.dart';

/// Dữ liệu phòng đang có khách thuê để chọn trong Form lập biên bản
class HostOccupiedRoomItem {
  final String roomId;
  final String roomCode;
  final String propertyId;
  final String propertyName;
  final String periodId;
  final String tenantId;
  final String tenantName;
  final String tenantPhone;
  final String residentId;
  final String formId; // 'chinh' hoặc 'oGhep'

  String get uniqueKey =>
      '${roomId}_${tenantId.isNotEmpty ? tenantId : (residentId.isNotEmpty ? residentId : tenantName)}';

  String get dropdownLabel {
    final roleTag = formId == 'oGhep'
        ? ' (Ở ghép)'
        : (formId == 'chinh' ? ' (Cư dân chính)' : '');
    final code = roomCode.isNotEmpty
        ? (roomCode.startsWith('P.') ? roomCode : 'P.$roomCode')
        : 'Phòng';
    final prop = propertyName.isNotEmpty ? ' - $propertyName' : '';
    return '$code$prop - $tenantName$roleTag';
  }

  const HostOccupiedRoomItem({
    required this.roomId,
    required this.roomCode,
    this.propertyId = '',
    this.propertyName = '',
    this.periodId = '',
    required this.tenantId,
    required this.tenantName,
    this.tenantPhone = '',
    this.residentId = '',
    this.formId = 'chinh',
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HostOccupiedRoomItem &&
          runtimeType == other.runtimeType &&
          uniqueKey == other.uniqueKey;

  @override
  int get hashCode => uniqueKey.hashCode;
}

/// Thống kê vi phạm theo tháng
class ViolationMonthlyStats {
  final double totalFineRecorded; // Tổng tiền phạt ghi nhận
  final int totalCount; // Số vi phạm
  final double totalPaid; // Tổng đã nộp
  final double totalPending; // Tổng chờ nộp
  final int paidCount; // Số đã nộp
  final int pendingCount; // Số chờ nộp

  const ViolationMonthlyStats({
    this.totalFineRecorded = 0.0,
    this.totalCount = 0,
    this.totalPaid = 0.0,
    this.totalPending = 0.0,
    this.paidCount = 0,
    this.pendingCount = 0,
  });

  factory ViolationMonthlyStats.fromRecords(
    List<ViolationRecordModel> records,
  ) {
    double totalFine = 0.0;
    double paid = 0.0;
    double pending = 0.0;
    int pCount = 0;
    int pendCount = 0;

    for (final r in records) {
      if (r.isCancelled) continue;
      totalFine += r.totalFine;
      if (r.isPaid) {
        paid += r.totalFine;
        pCount++;
      } else {
        pending += r.totalFine;
        pendCount++;
      }
    }

    return ViolationMonthlyStats(
      totalFineRecorded: totalFine,
      totalCount: records.where((r) => !r.isCancelled).length,
      totalPaid: paid,
      totalPending: pending,
      paidCount: pCount,
      pendingCount: pendCount,
    );
  }
}

class ViolationRepository {
  final FirebaseFirestore? _customFirestore;
  final FirebaseStorage? _storage;

  ViolationRepository({FirebaseFirestore? firestore, FirebaseStorage? storage})
    : _customFirestore = firestore,
      // ignore: prefer_initializing_formals
      _storage = storage;

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  FirebaseStorage get _storageInstance => _storage ?? FirebaseStorage.instance;

  // 4 hành vi vi phạm chuẩn theo thiết kế Figma & SRS
  static final List<ViolationModel> defaultViolationTypes = [
    ViolationModel(
      id: 'vp_rac',
      title: 'Để rác sai nơi quy định',
      description: 'Để rác ngoài hành lang hoặc khu vực chung',
      defaultFine: 150000,
      category: 'Vệ sinh chung',
      iconName: 'delete_outline',
      isActive: true,
      createdAt: DateTime.now(),
    ),
    ViolationModel(
      id: 'vp_on_ao',
      title: 'Ồn ào sau 23h',
      description: 'Làm ồn, mở loa công suất lớn sau 23h đêm',
      defaultFine: 200000,
      category: 'Trật tự an ninh',
      iconName: 'volume_up_outlined',
      isActive: true,
      createdAt: DateTime.now(),
    ),
    ViolationModel(
      id: 'vp_hut_thuoc',
      title: 'Hút thuốc trong phòng',
      description: 'Hút thuốc trong phòng gây nguy cơ hỏa hoạn',
      defaultFine: 300000,
      category: 'Phòng cháy chữa cháy',
      iconName: 'smoke_free_outlined',
      isActive: true,
      createdAt: DateTime.now(),
    ),
    ViolationModel(
      id: 'vp_nguoi_la',
      title: 'Dẫn người lạ qua đêm',
      description: 'Không đăng ký tạm trú cho người lạ ở qua đêm',
      defaultFine: 250000,
      category: 'An ninh trật tự',
      iconName: 'group_outlined',
      isActive: true,
      createdAt: DateTime.now(),
    ),
  ];

  /// Lắng nghe danh mục loại vi phạm từ Firestore, tự động seed nếu rỗng
  Stream<List<ViolationModel>> watchViolationTypes() {
    return _firestore
        .collection(FirestoreCollections.violations)
        .snapshots()
        .asyncMap((snapshot) async {
          if (snapshot.docs.isEmpty) {
            // Tự động seed 4 hành vi mẫu theo quyết định của người dùng
            try {
              final batch = _firestore.batch();
              for (final item in defaultViolationTypes) {
                final docRef = _firestore
                    .collection(FirestoreCollections.violations)
                    .doc(item.id);
                batch.set(docRef, item.toMap());
              }
              await batch.commit();
            } catch (_) {}
            return defaultViolationTypes;
          }

          final items = snapshot.docs
              .map(ViolationModel.fromFirestore)
              .where((v) => v.isActive)
              .toList();

          // Xử lý dữ liệu trùng: lọc bỏ các loại vi phạm trùng tiêu đề hoặc trùng ID
          final seenTitles = <String>{};
          final seenIds = <String>{};
          final deduplicated = <ViolationModel>[];

          for (final item in items) {
            final cleanTitle = item.title.trim().toLowerCase();
            final cleanId = item.id.trim();
            if (cleanTitle.isEmpty || seenTitles.contains(cleanTitle) || seenIds.contains(cleanId)) {
              continue;
            }
            seenTitles.add(cleanTitle);
            seenIds.add(cleanId);
            deduplicated.add(item);
          }
          return deduplicated;
        });
  }

  /// Thêm một loại vi phạm mới vào danh mục (có kiểm tra chống trùng lặp)
  Future<void> addViolationType(ViolationModel item) async {
    final cleanTitle = item.title.trim().toLowerCase();
    if (cleanTitle.isEmpty) return;

    // Kiểm tra chống trùng lặp trước khi thêm
    try {
      final existingSnap = await _firestore
          .collection(FirestoreCollections.violations)
          .get();
      for (final doc in existingSnap.docs) {
        final docData = doc.data();
        final title = (docData['title'] ?? docData['ten'] ?? '').toString().trim().toLowerCase();
        if (title == cleanTitle) {
          // Đã tồn tại loại vi phạm này, không thêm bản ghi trùng
          return;
        }
      }
    } catch (_) {}

    final id = (item.id.isNotEmpty && item.id != 'vp_')
        ? item.id
        : 'vp_${DateTime.now().millisecondsSinceEpoch}';
    final docRef = _firestore
        .collection(FirestoreCollections.violations)
        .doc(id);
    final toSave = item.id == id ? item : item.copyWith(id: id);
    await docRef.set(toSave.toMap());
  }

  /// Lắng nghe danh sách biên bản vi phạm của chủ trọ hiện tại
  Stream<List<ViolationRecordModel>> watchHostViolationRecords(String hostId) {
    if (hostId.isEmpty) return Stream.value([]);

    return _firestore
        .collection(FirestoreCollections.violationRecords)
        .where('landlordId', isEqualTo: hostId)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map(ViolationRecordModel.fromFirestore)
              .toList();
          // Sắp xếp ngày tạo mới nhất lên đầu
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  /// Lấy danh sách người thuê đang ở trong các phòng thuộc chủ trọ từ collection `residents`
  Future<List<HostOccupiedRoomItem>> getHostOccupiedRooms(String hostId) async {
    if (hostId.isEmpty) return [];

    // 1. Lấy danh sách phòng thuộc chủ trọ từ host_rooms.
    final hostRoomsMap = <String, RoomModel>{};
    try {
      final hostRoomsSnap = await _firestore
          .collection(FirestoreCollections.hostRooms)
          .where('hostId', isEqualTo: hostId)
          .get();
      for (final doc in hostRoomsSnap.docs) {
        if (doc.data()['status'] != 'deleted') {
          hostRoomsMap[doc.id] = RoomModel.fromFirestore(doc);
        }
      }
    } catch (_) {}

    if (hostRoomsMap.isEmpty) return [];

    // 2. Lấy tên các cơ sở / tòa nhà (properties)
    final propertyIds = hostRoomsMap.values
        .map((r) => r.propertyId)
        .where((id) => id.isNotEmpty)
        .toSet();
    final propertyNameMap = <String, String>{};
    for (final pid in propertyIds) {
      try {
        final doc = await _firestore
            .collection(FirestoreCollections.hostProperties)
            .doc(pid)
            .get();
        if (doc.exists) {
          final data = doc.data();
          propertyNameMap[pid] =
              (data?['name'] ?? data?['tenNha'] ?? data?['title'] ?? 'Nhà trọ')
                  .toString();
        }
      } catch (_) {}
    }

    // 3. Đọc danh sách đơn đặt phòng để hỗ trợ đối chiếu fallback nếu cần
    final bookingsSnap = await _firestore
        .collection(FirestoreCollections.bookings)
        .where('hostId', isEqualTo: hostId)
        .get();
    final bookings = bookingsSnap.docs
        .map(BookingRequestModel.fromFirestore)
        .toList();

    final result = <HostOccupiedRoomItem>[];
    final seenKeys = <String>{};
    final residentService = ResidentService(_firestore);

    // 4. Quét từng phòng để lấy cư dân đang ở từ collection 'residents'
    for (final room in hostRoomsMap.values) {
      final propName = propertyNameMap[room.propertyId] ??
          (room.address.isNotEmpty ? room.address : 'Nhà trọ');
      final roomCode = room.roomCode.isNotEmpty
          ? room.roomCode
          : (room.title.isNotEmpty ? room.title : 'Phòng ${room.id}');

      // A. Truy vấn danh sách cư dân đang ở qua ResidentService
      List<ResidentModel> activeResidents = [];
      try {
        activeResidents = await residentService.forRoom(room.id);
      } catch (_) {}

      // B. Nếu forRoom rỗng, thử truy vấn trực tiếp collection residents theo roomId / phongId
      if (activeResidents.isEmpty) {
        try {
          final resSnap = await _firestore
              .collection(FirestoreCollections.residents)
              .where('roomId', isEqualTo: room.id)
              .get();
          activeResidents = resSnap.docs
              .map(ResidentModel.fromFirestore)
              .where(ResidentService.isActive)
              .toList();
        } catch (_) {}
      }

      // C. Thử thêm alias collection cu_dan_dang_o
      if (activeResidents.isEmpty) {
        try {
          final cdSnap = await _firestore
              .collection(FirestoreCollections.cuDanDangO)
              .where('phongTroId', isEqualTo: room.id)
              .get();
          activeResidents = cdSnap.docs
              .map(ResidentModel.fromFirestore)
              .where(ResidentService.isActive)
              .toList();
        } catch (_) {}
      }

      // Lọc nghiêm ngặt: chỉ lấy cư dân ĐANG Ở THỰC TẾ (đã nhận phòng, ngày vào ở <= hiện tại, chưa dọn đi)
      final now = DateTime.now();
      activeResidents = activeResidents.where((r) {
        if (!ResidentService.isActive(r)) return false;
        // Người thuê chưa tới ngày vào ở thì KHÔNG được lập biên bản
        if (r.moveInDate.isAfter(now)) return false;
        if (r.moveOutDate != null && r.moveOutDate!.isBefore(now)) return false;
        return true;
      }).toList();

      // Ghi nhận từng cư dân đang ở trong phòng (cả cư dân chính và người ở ghép)
      for (final resident in activeResidents) {
        final key = '${room.id}_${resident.userId.isNotEmpty ? resident.userId : resident.id}';
        if (seenKeys.contains(key)) continue;
        seenKeys.add(key);

        result.add(
          HostOccupiedRoomItem(
            roomId: room.id,
            roomCode: roomCode,
            propertyId: room.propertyId,
            propertyName: propName,
            periodId: resident.periodId,
            tenantId: resident.userId.isNotEmpty ? resident.userId : resident.id,
            tenantName: resident.fullName.isNotEmpty ? resident.fullName : 'Cư dân',
            tenantPhone: resident.phone,
            residentId: resident.id,
            formId: resident.formId,
          ),
        );
      }

      // D. Fallback: Chỉ chấp nhận booking nếu ĐÃ CHECK-IN / NHẬN PHÒNG THỰC TẾ và đã vào ở
      if (activeResidents.isEmpty) {
        final checkedInBooking = bookings.cast<BookingRequestModel?>().firstWhere(
          (b) {
            if (b == null) return false;
            final isMatchRoom = b.roomId == room.id || b.roomId == room.roomCode;
            if (!isMatchRoom) return false;

            // Bắt buộc phải đã check-in thực tế / đang ở, chưa ở thì tuyệt đối không tính
            final isReallyCheckedIn = b.isActive;

            final hasMovedIn = b.acceptedDate != null
                ? b.acceptedDate!.isBefore(now)
                : b.moveInDate.isBefore(now);

            return isReallyCheckedIn && hasMovedIn && !b.isCheckedOut && !b.isCancelled;
          },
          orElse: () => null,
        );

        if (checkedInBooking != null && checkedInBooking.renterName.isNotEmpty) {
          final key = '${room.id}_${checkedInBooking.renterId}';
          if (!seenKeys.contains(key)) {
            seenKeys.add(key);
            result.add(
              HostOccupiedRoomItem(
                roomId: room.id,
                roomCode: roomCode,
                propertyId: room.propertyId,
                propertyName: propName,
                periodId: '',
                tenantId: checkedInBooking.renterId,
                tenantName: checkedInBooking.renterName,
                tenantPhone: checkedInBooking.renterPhone,
                residentId: checkedInBooking.id,
                formId: 'chinh',
              ),
            );
          }
        }
      }
    }

    return result;
  }

  /// Tải danh sách tệp bằng chứng lên Firebase Storage (Hỗ trợ toàn diện Web, Android, iOS qua putData và fallback Base64)
  Future<List<String>> uploadEvidenceFiles({
    required String hostId,
    required String recordId,
    required List<ViolationEvidenceFile> files,
  }) async {
    if (files.isEmpty) return [];

    final downloadUrls = <String>[];
    for (int i = 0; i < files.length; i++) {
      final file = files[i];
      final ext = file.name.split('.').last.toLowerCase();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$i.$ext';
      final ref = _storageInstance.ref().child(
        'violations_media/$hostId/$recordId/$fileName',
      );

      final metadata = SettableMetadata(
        contentType: file.contentType,
      );

      try {
        final uploadTask = ref.putData(file.bytes, metadata);
        final snapshot = await uploadTask.timeout(
          const Duration(seconds: 40),
          onTimeout: () async {
            await uploadTask.cancel();
            throw TimeoutException('Tải tệp bằng chứng quá thời gian cho phép.');
          },
        );
        final url = await snapshot.ref.getDownloadURL();
        downloadUrls.add(url);
      } catch (e) {
        debugPrint('Lỗi tải bằng chứng vi phạm lên Firebase Storage: $e. Sử dụng fallback data URI.');
        if (!file.isVideo) {
          final b64 = base64Encode(file.bytes);
          downloadUrls.add('data:${file.contentType};base64,$b64');
        }
      }
    }

    return downloadUrls;
  }

  /// Tạo biên bản vi phạm mới và gửi thông báo kèm bằng chứng & số tiền phạt đến người thuê để thanh toán ngoài ứng dụng
  Future<String> createViolationRecord(ViolationRecordModel record) async {
    final docRef = _firestore
        .collection(FirestoreCollections.violationRecords)
        .doc(record.id.isNotEmpty ? record.id : null);

    // Luồng tinh gọn: luôn để hình thức thu tiền là CASH/trực tiếp và trạng thái PENDING
    final recordToSave = (record.id.isEmpty
            ? record.copyWith(id: docRef.id)
            : record)
        .copyWith(
      paymentMethod: 'CASH',
      status: 'PENDING',
    );

    final batch = _firestore.batch();
    batch.set(docRef, recordToSave.toMap());

    // Gửi thông báo đến chuông của người thuê kèm bằng chứng & số tiền phạt để trả ngoài app
    if (recordToSave.tenantId.isNotEmpty) {
      final notifRef =
          _firestore.collection(FirestoreCollections.notifications).doc();
      final fineFmt =
          NumberFormat('#,###', 'vi_VN').format(recordToSave.totalFine);
      final violationsStr = recordToSave.violationTitles.isNotEmpty
          ? recordToSave.violationTitles.join(', ')
          : 'Nội quy phòng trọ';

      final notifData = {
        'id': notifRef.id,
        'receiverId': recordToSave.tenantId,
        'userId': recordToSave.tenantId,
        'recipientRole': 'renter',
        'hostId': recordToSave.landlordId,
        'landlordId': recordToSave.landlordId,
        'title': 'Thông báo phạt vi phạm nội quy',
        'message':
            'Chủ trọ đã lập biên bản vi phạm phòng ${recordToSave.roomCode}: $violationsStr. Số tiền phạt: $fineFmt đ. Vui lòng xem bằng chứng và thanh toán trực tiếp ngoài ứng dụng cho chủ trọ.',
        'notificationType': 'violation_fine',
        'type': 'violation_fine',
        'recordId': recordToSave.id,
        'roomId': recordToSave.roomId,
        'roomCode': recordToSave.roomCode,
        'propertyName': recordToSave.propertyName,
        'tenantId': recordToSave.tenantId,
        'tenantName': recordToSave.tenantName,
        'totalFine': recordToSave.totalFine,
        'amount': recordToSave.totalFine,
        'violationTitles': recordToSave.violationTitles,
        'description': recordToSave.description,
        'evidenceUrls': recordToSave.evidenceUrls,
        'paymentMethod': 'CASH',
        'status': 'PENDING',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      };

      batch.set(notifRef, notifData);

      // Ghi đồng thời vào collection notification_user để người thuê luôn nhận được realtime
      try {
        final userNotifRef = _firestore
            .collection(FirestoreCollections.notificationUser)
            .doc(notifRef.id);
        batch.set(userNotifRef, notifData);
      } catch (_) {}
    }

    await batch.commit();
    return recordToSave.id;
  }

  /// Thu tiền mặt: cập nhật trạng thái đã thanh toán và gửi thông báo xác nhận cho người thuê
  Future<void> markCashPayment(
    String recordId, {
    required String hostId,
  }) async {
    final recRef =
        _firestore.collection(FirestoreCollections.violationRecords).doc(recordId);
    final doc = await recRef.get();
    String tenantId = '';
    String roomCode = '';
    double fineAmt = 0.0;
    if (doc.exists && doc.data() != null) {
      final data = doc.data()!;
      tenantId = (data['tenantId'] ?? data['nguoiDungId'] ?? '').toString();
      roomCode = (data['roomCode'] ?? data['soPhong'] ?? '').toString();
      final totalFine = (data['totalFine'] ?? data['tongTienPhat'] ?? 0.0);
      fineAmt = (totalFine is num) ? totalFine.toDouble() : 0.0;
    }

    // 1. Cập nhật trạng thái biên bản thành PAID
    await recRef.set({
      'status': 'PAID',
      'paidAt': Timestamp.now(),
      'paidMethod': 'CASH',
      'paidCollector': hostId,
      'updatedAt': Timestamp.now(),
    }, SetOptions(merge: true));

    // 2. Cập nhật các notification liên quan trong collection `notifications`
    try {
      final notifsSnap = await _firestore
          .collection(FirestoreCollections.notifications)
          .where('recordId', isEqualTo: recordId)
          .get();
      for (final nDoc in notifsSnap.docs) {
        await nDoc.reference.set({
          'status': 'PAID',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Error updating notifications on markCashPayment: $e');
    }

    // 3. Cập nhật các notification liên quan trong collection `notification_user`
    try {
      final userNotifsSnap = await _firestore
          .collection(FirestoreCollections.notificationUser)
          .where('recordId', isEqualTo: recordId)
          .get();
      for (final uDoc in userNotifsSnap.docs) {
        await uDoc.reference.set({
          'status': 'PAID',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Error updating user notifications on markCashPayment: $e');
    }

    // 4. Gửi thông báo xác nhận đã thu tiền trực tiếp cho người thuê
    if (tenantId.isNotEmpty) {
      try {
        final notifRef =
            _firestore.collection(FirestoreCollections.notifications).doc();
        final fineFmt = NumberFormat('#,###', 'vi_VN').format(fineAmt);
        final notifData = {
          'id': notifRef.id,
          'receiverId': tenantId,
          'userId': tenantId,
          'recipientRole': 'renter',
          'title': 'Xác nhận đã nộp phạt trực tiếp ✓',
          'message':
              'Chủ trọ đã xác nhận nhận đủ tiền phạt $fineFmt đ phòng $roomCode bằng tiền mặt ngoài ứng dụng.',
          'notificationType': 'violation_fine',
          'type': 'violation_fine',
          'recordId': recordId,
          'roomCode': roomCode,
          'totalFine': fineAmt,
          'amount': fineAmt,
          'status': 'PAID',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        };
        await notifRef.set(notifData);

        final userNotifRef = _firestore
            .collection(FirestoreCollections.notificationUser)
            .doc(notifRef.id);
        await userNotifRef.set(notifData);
      } catch (e) {
        debugPrint('Error sending confirmation notification on markCashPayment: $e');
      }
    }
  }

  /// Trừ vào hóa đơn: tạo dòng hóa đơn và cập nhật trạng thái biên bản
  Future<void> deductToInvoice(ViolationRecordModel record) async {
    // 1. Tạo invoice_line
    final lineDocRef = _firestore
        .collection(FirestoreCollections.invoiceLines)
        .doc();
    final invoiceLine = InvoiceLineModel(
      id: lineDocRef.id,
      violationRecordId: record.id,
      violationId: record.violationIds.isNotEmpty
          ? record.violationIds.first
          : '',
      roomId: record.roomId,
      periodId: record.periodId,
      amount: record.totalFine,
      purpose: 'PhatViPham',
      title: record.violationTitles.isNotEmpty
          ? 'Phạt: ${record.violationTitles.join(', ')}'
          : 'Phạt vi phạm nội quy',
      status: 'pending',
      createdAt: DateTime.now(),
    );
    await lineDocRef.set(invoiceLine.toMap());

    // 2. Cập nhật violation_records
    final recDocRef = _firestore
        .collection(FirestoreCollections.violationRecords)
        .doc(record.id);
    await recDocRef.set({
      'status': 'ADDED_TO_INVOICE',
      'paymentMethod': FieldValue.delete(),
      'updatedAt': Timestamp.now(),
    }, SetOptions(merge: true));

    // 3. Cập nhật các notification liên quan sang ADDED_TO_INVOICE
    try {
      final notifsSnap = await _firestore
          .collection(FirestoreCollections.notifications)
          .where('recordId', isEqualTo: record.id)
          .get();
      for (final nDoc in notifsSnap.docs) {
        await nDoc.reference.set({
          'status': 'ADDED_TO_INVOICE',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      final userNotifsSnap = await _firestore
          .collection(FirestoreCollections.notificationUser)
          .where('recordId', isEqualTo: record.id)
          .get();
      for (final uDoc in userNotifsSnap.docs) {
        await uDoc.reference.set({
          'status': 'ADDED_TO_INVOICE',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Error updating notifications on deductToInvoice: $e');
    }

    // 4. Gửi thông báo đến người thuê
    if (record.tenantId.isNotEmpty) {
      try {
        final notifRef =
            _firestore.collection(FirestoreCollections.notifications).doc();
        final fineFmt = NumberFormat('#,###', 'vi_VN').format(record.totalFine);
        final notifData = {
          'id': notifRef.id,
          'receiverId': record.tenantId,
          'userId': record.tenantId,
          'recipientRole': 'renter',
          'title': 'Cộng tiền phạt vào hóa đơn tháng sau',
          'message':
              'Khoản phạt $fineFmt đ phòng ${record.roomCode} đã được cộng vào hóa đơn tiền phòng kỳ tới để thanh toán trực tiếp.',
          'notificationType': 'violation_fine',
          'type': 'violation_fine',
          'recordId': record.id,
          'roomCode': record.roomCode,
          'totalFine': record.totalFine,
          'amount': record.totalFine,
          'status': 'ADDED_TO_INVOICE',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        };
        await notifRef.set(notifData);
        final userNotifRef = _firestore
            .collection(FirestoreCollections.notificationUser)
            .doc(notifRef.id);
        await userNotifRef.set(notifData);
      } catch (e) {
        debugPrint('Error sending deduct notification: $e');
      }
    }
  }

  /// Gửi nhắc nộp tiền: ghi nhận thời gian gửi nhắc và gửi thông báo cho người thuê
  Future<void> sendPaymentReminder(String recordId) async {
    final doc = await _firestore
        .collection(FirestoreCollections.violationRecords)
        .doc(recordId)
        .get();
    if (!doc.exists || doc.data() == null) return;
    final data = doc.data()!;
    final tenantId =
        (data['tenantId'] ?? data['nguoiDungId'] ?? '').toString();
    final roomCode =
        (data['roomCode'] ?? data['soPhong'] ?? '').toString();
    final rawFine = data['totalFine'] ?? data['tongTienPhat'] ?? 0.0;
    final fineAmt = (rawFine is num) ? rawFine.toDouble() : 0.0;
    final fineFmt = NumberFormat('#,###', 'vi_VN').format(fineAmt);
    final violationTitles = List<String>.from(
        data['violationTitles'] ?? data['danhSachTenViPham'] ?? []);
    final evidenceUrls =
        List<String>.from(data['evidenceUrls'] ?? data['chungCu'] ?? []);
    final description =
        (data['description'] ?? data['moTa'] ?? '').toString();

    // Chặn spam nhắc nhở: Giới hạn mỗi lần gửi cách nhau tối thiểu 60 giây
    final lastReminder = (data['lastReminderAt'] is Timestamp)
        ? (data['lastReminderAt'] as Timestamp).toDate()
        : null;
    if (lastReminder != null) {
      final elapsed = DateTime.now().difference(lastReminder).inSeconds;
      if (elapsed < 60) {
        throw StateError(
            'Vui lòng đợi ${60 - elapsed}s trước khi gửi lại thông báo nhắc nộp phạt.');
      }
    }

    await _firestore
        .collection(FirestoreCollections.violationRecords)
        .doc(recordId)
        .set({
      'lastReminderAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    }, SetOptions(merge: true));

    if (tenantId.isNotEmpty) {
      try {
        final notifRef =
            _firestore.collection(FirestoreCollections.notifications).doc();
        final notifData = {
          'id': notifRef.id,
          'receiverId': tenantId,
          'userId': tenantId,
          'recipientRole': 'renter',
          'title': 'Nhắc nhở nộp phạt vi phạm nội quy',
          'message':
              'Chủ trọ nhắc bạn thanh toán tiền phạt $fineFmt đ cho vi phạm phòng $roomCode. Vui lòng thanh toán trực tiếp cho chủ trọ.',
          'notificationType': 'violation_fine',
          'type': 'violation_fine',
          'recordId': recordId,
          'roomCode': roomCode,
          'totalFine': fineAmt,
          'amount': fineAmt,
          'violationTitles': violationTitles,
          'description': description,
          'evidenceUrls': evidenceUrls,
          'status': 'PENDING',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        };
        await notifRef.set(notifData);
        final userNotifRef = _firestore
            .collection(FirestoreCollections.notificationUser)
            .doc(notifRef.id);
        await userNotifRef.set(notifData);
      } catch (e) {
        debugPrint('Error sending payment reminder notification: $e');
      }
    }
  }
}
