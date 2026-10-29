import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/firestore_collections.dart';
import '../../../data/models/booking_model.dart';
import '../../../data/models/period_model.dart';
import '../../../data/models/resident_model.dart';
import '../../../data/models/room_model.dart';
import '../models/invoice_line_model.dart';
import '../models/violation_model.dart';
import '../models/violation_record_model.dart';

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

  String get dropdownLabel => '$roomCode - $propertyName ($tenantName)';

  const HostOccupiedRoomItem({
    required this.roomId,
    required this.roomCode,
    this.propertyId = '',
    this.propertyName = '',
    this.periodId = '',
    required this.tenantId,
    required this.tenantName,
    this.tenantPhone = '',
  });
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

  factory ViolationMonthlyStats.fromRecords(List<ViolationRecordModel> records) {
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

  ViolationRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _customFirestore = firestore,
        // ignore: prefer_initializing_formals
        _storage = storage;

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  FirebaseStorage get _storageInstance =>
      _storage ?? FirebaseStorage.instance;

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

      return snapshot.docs
          .map(ViolationModel.fromFirestore)
          .where((v) => v.isActive)
          .toList();
    });
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

  /// Lấy danh sách các phòng đang có người thuê (`dangO`) thuộc chủ trọ
  Future<List<HostOccupiedRoomItem>> getHostOccupiedRooms(String hostId) async {
    if (hostId.isEmpty) return [];

    // 1. Lấy danh sách phòng thuộc chủ trọ
    final roomsSnap = await _firestore
        .collection(FirestoreCollections.hostRooms)
        .where('hostId', isEqualTo: hostId)
        .get();

    final hostRooms = roomsSnap.docs
        .map(RoomModel.fromFirestore)
        .where((r) => r.status != 'deleted')
        .toList();

    if (hostRooms.isEmpty) return [];
    final roomMap = {for (var r in hostRooms) r.id: r};

    // 2. Lấy tên các cơ sở/properties
    final propertyIds = hostRooms
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
          propertyNameMap[pid] = (data?['name'] ??
                  data?['tenNha'] ??
                  data?['title'] ??
                  'Nhà trọ')
              .toString();
        }
      } catch (_) {}
    }

    // 3. Lấy kỳ ở (periods) đang hoạt động
    final periodsSnap = await _firestore
        .collection(FirestoreCollections.periods)
        .where('status', isEqualTo: 'dangO')
        .get();

    final activePeriods = periodsSnap.docs
        .map(PeriodModel.fromFirestore)
        .where((p) => roomMap.containsKey(p.roomId))
        .toList();

    // 4. Lấy đơn đặt phòng (bookings)
    final bookingsSnap = await _firestore
        .collection(FirestoreCollections.bookings)
        .where('hostId', isEqualTo: hostId)
        .get();

    final bookings = bookingsSnap.docs
        .map(BookingRequestModel.fromFirestore)
        .toList();
    final bookingMap = {for (var b in bookings) b.id: b};

    final result = <HostOccupiedRoomItem>[];
    for (final period in activePeriods) {
      final room = roomMap[period.roomId];
      if (room == null) continue;

      // Tìm cư dân chính
      final resSnap = await _firestore
          .collection(FirestoreCollections.residents)
          .where('kyThue_id', isEqualTo: period.id)
          .get();

      final residents =
          resSnap.docs.map(ResidentModel.fromFirestore).toList();
      final booking = bookingMap[period.bookingId];

      final propName = propertyNameMap[room.propertyId] ??
          (room.address.isNotEmpty ? room.address : 'KTX / Nhà trọ');

      final tenantName = residents.isNotEmpty
          ? residents.first.fullName
          : (booking?.renterName.isNotEmpty == true
              ? booking!.renterName
              : (room.tenantName.isNotEmpty ? room.tenantName : 'Khách thuê'));

      final tenantPhone = residents.isNotEmpty &&
              residents.first.phone.isNotEmpty
          ? residents.first.phone
          : (booking?.renterPhone.isNotEmpty == true
              ? booking!.renterPhone
              : room.tenantPhone);

      final tenantId = residents.isNotEmpty
          ? residents.first.userId
          : (booking?.renterId.isNotEmpty == true
              ? booking!.renterId
              : period.renterId);

      result.add(HostOccupiedRoomItem(
        roomId: room.id,
        roomCode: room.roomCode.isNotEmpty
            ? room.roomCode
            : (room.title.isNotEmpty ? room.title : 'Phòng ${room.id}'),
        propertyId: room.propertyId,
        propertyName: propName,
        periodId: period.id,
        tenantId: tenantId,
        tenantName: tenantName,
        tenantPhone: tenantPhone,
      ));
    }

    return result;
  }

  /// Tải danh sách tệp bằng chứng lên Firebase Storage
  Future<List<String>> uploadEvidenceFiles({
    required String hostId,
    required String recordId,
    required List<File> files,
  }) async {
    if (files.isEmpty) return [];

    final downloadUrls = <String>[];
    for (int i = 0; i < files.length; i++) {
      final file = files[i];
      final ext = file.path.split('.').last.toLowerCase();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$i.$ext';
      final ref = _storageInstance
          .ref()
          .child('violations_media/$hostId/$recordId/$fileName');

      final metadata = SettableMetadata(
        contentType: ext == 'mp4' ? 'video/mp4' : 'image/jpeg',
      );

      final uploadTask = await ref.putFile(file, metadata);
      final url = await uploadTask.ref.getDownloadURL();
      downloadUrls.add(url);
    }

    return downloadUrls;
  }

  /// Tạo biên bản vi phạm mới kèm tạo dòng hóa đơn tự động nếu chọn cộng vào tiền phòng
  Future<String> createViolationRecord(ViolationRecordModel record) async {
    final docRef = _firestore
        .collection(FirestoreCollections.violationRecords)
        .doc(record.id.isNotEmpty ? record.id : null);

    final recordToSave = record.id.isEmpty
        ? record.copyWith(id: docRef.id)
        : record;

    final batch = _firestore.batch();
    batch.set(docRef, recordToSave.toMap());

    // Nếu chọn hình thức 'NEXT_INVOICE', tự động tạo Dòng hóa đơn (invoice_lines)
    if (recordToSave.paymentMethod == 'NEXT_INVOICE') {
      final lineDocRef =
          _firestore.collection(FirestoreCollections.invoiceLines).doc();

      final invoiceLine = InvoiceLineModel(
        id: lineDocRef.id,
        violationRecordId: recordToSave.id,
        violationId: recordToSave.violationIds.isNotEmpty
            ? recordToSave.violationIds.first
            : '',
        roomId: recordToSave.roomId,
        periodId: recordToSave.periodId,
        amount: recordToSave.totalFine,
        purpose: 'PhatViPham',
        title: recordToSave.violationTitles.isNotEmpty
            ? 'Phạt: ${recordToSave.violationTitles.join(', ')}'
            : 'Phạt vi phạm nội quy',
        status: 'pending',
        createdAt: DateTime.now(),
      );

      batch.set(lineDocRef, invoiceLine.toMap());
    }

    // Gửi thông báo đến chuông của người thuê kèm bằng chứng & số tiền phạt
    if (recordToSave.tenantId.isNotEmpty) {
      final notifRef =
          _firestore.collection(FirestoreCollections.notifications).doc();
      final fineFmt =
          NumberFormat('#,###', 'vi_VN').format(recordToSave.totalFine);
      final violationsStr = recordToSave.violationTitles.isNotEmpty
          ? recordToSave.violationTitles.join(', ')
          : 'Nội quy phòng trọ';
      batch.set(notifRef, {
        'id': notifRef.id,
        'receiverId': recordToSave.tenantId,
        'recipientRole': 'renter',
        'title': 'Biên bản phạt vi phạm nội quy',
        'message':
            'Chủ trọ đã ghi nhận vi phạm phòng ${recordToSave.roomCode}: $violationsStr. Số tiền phạt: $fineFmt đ. Lưu ý: Tiền phạt nộp trực tiếp cho chủ trọ, không thu trên ứng dụng.',
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
        'paymentMethod': recordToSave.paymentMethod,
        'status': recordToSave.status,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
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

    final batch = _firestore.batch();
    batch.update(recRef, {
      'status': 'PAID',
      'paidAt': Timestamp.now(),
      'paidMethod': 'CASH',
      'paidCollector': hostId,
      'updatedAt': Timestamp.now(),
    });

    // Cập nhật các notification liên quan sang PAID
    try {
      final notifsSnap = await _firestore
          .collection(FirestoreCollections.notifications)
          .where('recordId', isEqualTo: recordId)
          .get();
      for (final nDoc in notifsSnap.docs) {
        batch.update(nDoc.reference, {
          'status': 'PAID',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {}

    // Gửi thông báo xác nhận đã thu tiền trực tiếp
    if (tenantId.isNotEmpty) {
      final notifRef =
          _firestore.collection(FirestoreCollections.notifications).doc();
      final fineFmt = NumberFormat('#,###', 'vi_VN').format(fineAmt);
      batch.set(notifRef, {
        'id': notifRef.id,
        'receiverId': tenantId,
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
      });
    }

    await batch.commit();
  }

  /// Trừ vào hóa đơn: tạo dòng hóa đơn và cập nhật trạng thái biên bản
  Future<void> deductToInvoice(ViolationRecordModel record) async {
    final batch = _firestore.batch();

    // 1. Tạo invoice_line
    final lineDocRef =
        _firestore.collection(FirestoreCollections.invoiceLines).doc();
    final invoiceLine = InvoiceLineModel(
      id: lineDocRef.id,
      violationRecordId: record.id,
      violationId:
          record.violationIds.isNotEmpty ? record.violationIds.first : '',
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
    batch.set(lineDocRef, invoiceLine.toMap());

    // 2. Cập nhật violation_records
    final recDocRef = _firestore
        .collection(FirestoreCollections.violationRecords)
        .doc(record.id);
    batch.update(recDocRef, {
      'status': 'ADDED_TO_INVOICE',
      'paymentMethod': 'NEXT_INVOICE',
      'updatedAt': Timestamp.now(),
    });

    // 3. Cập nhật các notification liên quan sang ADDED_TO_INVOICE
    try {
      final notifsSnap = await _firestore
          .collection(FirestoreCollections.notifications)
          .where('recordId', isEqualTo: record.id)
          .get();
      for (final nDoc in notifsSnap.docs) {
        batch.update(nDoc.reference, {
          'status': 'ADDED_TO_INVOICE',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {}

    // 4. Gửi thông báo đến người thuê
    if (record.tenantId.isNotEmpty) {
      final notifRef =
          _firestore.collection(FirestoreCollections.notifications).doc();
      final fineFmt = NumberFormat('#,###', 'vi_VN').format(record.totalFine);
      batch.set(notifRef, {
        'id': notifRef.id,
        'receiverId': record.tenantId,
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
      });
    }

    await batch.commit();
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

    final batch = _firestore.batch();
    batch.update(
        _firestore.collection(FirestoreCollections.violationRecords).doc(recordId),
        {
          'lastReminderAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
        });

    if (tenantId.isNotEmpty) {
      final notifRef =
          _firestore.collection(FirestoreCollections.notifications).doc();
      batch.set(notifRef, {
        'id': notifRef.id,
        'receiverId': tenantId,
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
      });
    }

    await batch.commit();
  }
}
