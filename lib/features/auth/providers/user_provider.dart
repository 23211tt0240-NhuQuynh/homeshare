import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/role_resolver.dart';
import '../../../core/services/host_index_service.dart';
import '../../../core/services/image_storage_service.dart';
import '../../../core/utils/host_reputation.dart';
import '../../../core/utils/id_generator.dart';
import 'auth_provider.dart';

/// Model thông tin người dùng HomeShare chuẩn hóa theo Database homeShare (DrawIO pkg_0: Tài khoản)
/// Bảng: Người dùng, Sở thích (soDienThoai, email, hoTen, anhDaiDien, gioiTinh, ngaySinh, diaChi, reputationScore, ngheNghiep)
class UserProfile {
  final String uid; // id
  final String?
  _userCode; // maNguoiDung 5 ký tự (3 số đầu + 2 chữ sau, vd: 382AN)
  final String email; // email
  final String displayName; // hoTen
  final String phoneNumber; // soDienThoai
  final String role; // vaiTro ('renter' / 'nguoiDung')
  final String avatarUrl; // anhDaiDien
  final String gender; // gioiTinh: nam | nu | khac
  final String address; // diaChi
  final String hometown; // queQuan
  final int reputationScore;
  /// Số thứ tự chủ trọ cố định trên Firebase (`users.hostIndex`). 0 = chưa cấp.
  final int hostIndex;
  final int statusId;
  final bool isBanned;
  final bool accountDeleted;
  final DateTime? suspendedUntil;
  final String suspensionType;
  final String occupation; // ngheNghiep
  final String workplace; // noiLamViec
  final String bio; // gioiThieu
  final List<String> hobbies; // soThich
  final DateTime? birthDate; // ngaySinh
  final DateTime? createdAt; // ngayTao
  final bool isCccdVerified; // daXacThucCccd / trangThaiXacMinh_id
  final String cccdNumber; // soGiayTo / soCccd
  final String cccdFullName; // hoTenCccd
  final String cccdIssueDate; // ngayCap
  final String cccdHometown; // queQuanCccd
  final DateTime? cccdVerifiedAt; // ngayXacMinh
  final String cccdFrontImageUrl; // anhMatTruoc / anhGiayTo_id
  final String cccdBackImageUrl; // anhMatSau

  // Vietnamese DrawIO Alias Getters
  bool get isAccessBlocked {
    return accountDeleted || isBanned || statusId == 2;
  }

  String get id => uid;
  String get userCode => (_userCode != null && isValidUserCode(_userCode))
      ? _userCode
      : generateUserCode(seed: uid, role: role);
  String get maNguoiDung => userCode;
  String get idNguoiDung => userCode;
  String get maDinhDanh => userCode;
  String get hoTen => displayName;
  String get soDienThoai => phoneNumber;
  String get anhDaiDien => avatarUrl;
  String get gioiTinh => gender;
  String get diaChi => address;
  String get queQuan => hometown;
  String get ngheNghiep => occupation;
  String get noiLamViec => workplace;
  String get gioiThieu => bio;
  List<String> get soThich => hobbies;
  String get vaiTro => role;
  bool get isRenter =>
      role == 'renter' || role == 'tenant' || role == 'nguoidung';
  bool get isHost => role == 'host' || role == 'landlord' || role == 'chutro';
  bool get isAdmin =>
      role == 'admin' || role == 'administrator' || role == 'quantri';
  bool get hasValidRole => RoleResolver.isValidRole(role);
  DateTime? get ngaySinh => birthDate;
  DateTime? get ngayTao => createdAt;
  bool get daXacThucCccd => isCccdVerified;
  String get soCccd => cccdNumber;
  String get soGiayTo => cccdNumber;
  String get hoTenCccd => cccdFullName;
  String get anhMatTruoc => cccdFrontImageUrl;
  String get anhMatSau => cccdBackImageUrl;
  String get maskedCccdNumber {
    final raw = cccdNumber.trim();
    if (raw.isEmpty) return 'eKYC';

    final visible = raw.replaceAll(RegExp(r'\s+'), '');
    if (visible.length <= 4) return visible;

    final prefixLength = visible.length > 6 ? 4 : visible.length - 2;
    final prefix = visible.substring(0, prefixLength);
    final suffix = visible.substring(visible.length - 2);
    return '$prefix****$suffix';
  }

  /// Kiểm tra mã người dùng có đúng chuẩn CT001, NT001, ADMIN01 (hoặc chuẩn cũ 382AN) hay không
  static bool isValidUserCode(String code) {
    final clean = code.trim().toUpperCase();
    return RegExp(
      r'^(CT\d{3}|NT\d{3}|ADMIN\d{2,3}|\d{3}[A-Z]{2})$',
    ).hasMatch(clean);
  }

  /// Sinh mã người dùng theo vai trò: Chủ trọ (CT001), Người thuê (NT001), Quản trị viên (ADMIN01)
  static String generateUserCode({String? seed, String? role}) {
    return IdGenerator.userCode(role: role ?? 'renter', seed: seed);
  }

  UserProfile({
    required this.uid,
    String? userCode,
    required this.email,
    required this.displayName,
    required this.phoneNumber,
    this.role = 'renter',
    this.avatarUrl = '',
    this.gender = 'Nam',
    this.address = '',
    this.hometown = '',
    this.reputationScore = 100,
    this.hostIndex = 0,
    this.statusId = 0,
    this.isBanned = false,
    this.accountDeleted = false,
    this.suspendedUntil,
    this.suspensionType = '',
    this.occupation = 'Sinh viên',
    this.workplace = '',
    this.bio = '',
    this.hobbies = const [],
    this.birthDate,
    this.createdAt,
    this.isCccdVerified = false,
    this.cccdNumber = '',
    this.cccdFullName = '',
    this.cccdIssueDate = '',
    this.cccdHometown = '',
    this.cccdVerifiedAt,
    this.cccdFrontImageUrl = '',
    this.cccdBackImageUrl = '',
  }) : _userCode = (userCode != null && isValidUserCode(userCode))
           ? userCode.trim().toUpperCase()
           : generateUserCode(seed: uid, role: role);

  factory UserProfile.fromMap(Map<String, dynamic> data, String uid) {
    DateTime? parseModerationDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    final rawStatusId = data['statusId'];
    final parsedStatusId = rawStatusId is num
        ? rawStatusId.toInt()
        : int.tryParse(data['statusId'].toString()) ?? 0;
    final rawHobbies = (data['hobbies'] ?? data['soThich']) as List<dynamic>?;
    final parsedHobbies =
        rawHobbies
            ?.map((e) => e?.toString() ?? '')
            .where((e) => e.isNotEmpty)
            .toList() ??
        [];

    final resolvedRole =
        RoleResolver.extractRoleFromMap(data) ??
        (data['vaiTro'] != null
            ? RoleResolver.normalizeRole(data['vaiTro'])
            : null) ??
        (data['role'] != null
            ? RoleResolver.normalizeRole(data['role'])
            : null) ??
        'renter';

    final rawUserCode =
        (data['userCode'] ?? data['maNguoiDung'] ?? data['idNguoiDung'])
            ?.toString();
    final userCode = (rawUserCode != null && isValidUserCode(rawUserCode))
        ? rawUserCode.trim().toUpperCase()
        : generateUserCode(seed: uid, role: resolvedRole);

    return UserProfile(
      uid: uid,
      userCode: userCode,
      email: data['email'] ?? '',
      displayName:
          data['displayName'] ?? data['hoTen'] ?? 'Người dùng HomeShare',
      phoneNumber: data['phoneNumber'] ?? data['soDienThoai'] ?? '',
      role: resolvedRole,
      avatarUrl: data['avatarUrl'] ?? data['anhDaiDien'] ?? '',
      gender: data['gender'] ?? data['gioiTinh'] ?? 'Nam',
      address: data['address'] ?? data['diaChi'] ?? '',
      hometown: data['hometown'] ?? data['queQuan'] ?? '',
      reputationScore:
          ((data['reputationScore'] ?? data['diemUyTin']) as num?)?.toInt() ??
          100,
      hostIndex: ((data['hostIndex'] ?? data['soChuTro']) as num?)?.toInt() ?? 0,
      statusId: parsedStatusId,
      isBanned: data['isBanned'] == true,
      accountDeleted: data['accountDeleted'] == true,
      suspendedUntil: parseModerationDate(data['suspendedUntil']),
      suspensionType: (data['suspensionType'] ?? '').toString(),
      occupation: data['occupation'] ?? data['ngheNghiep'] ?? 'Sinh viên',
      workplace: data['workplace'] ?? data['noiLamViec'] ?? '',
      bio: data['bio'] ?? data['gioiThieu'] ?? '',
      hobbies: parsedHobbies,
      birthDate: (data['birthDate'] is Timestamp)
          ? (data['birthDate'] as Timestamp).toDate()
          : (data['ngaySinh'] is Timestamp)
          ? (data['ngaySinh'] as Timestamp).toDate()
          : null,
      createdAt: (data['createdAt'] is Timestamp)
          ? (data['createdAt'] as Timestamp).toDate()
          : (data['ngayTao'] is Timestamp)
          ? (data['ngayTao'] as Timestamp).toDate()
          : null,
      isCccdVerified:
          (data['isCccdVerified'] ??
              data['daXacThucCccd'] ??
              (data['trangThaiXacMinh'] == 'daXacThuc') ??
              (data['trangThaiXacMinh_id'] == 'daXacThuc')) ??
          false,
      cccdNumber:
          data['cccdNumber'] ?? data['soCccd'] ?? data['soGiayTo'] ?? '',
      cccdFullName: data['cccdFullName'] ?? data['hoTenCccd'] ?? '',
      cccdIssueDate: data['cccdIssueDate'] ?? data['ngayCap'] ?? '',
      cccdHometown: data['cccdHometown'] ?? data['queQuanCccd'] ?? '',
      cccdVerifiedAt: (data['cccdVerifiedAt'] is Timestamp)
          ? (data['cccdVerifiedAt'] as Timestamp).toDate()
          : (data['ngayXacMinh'] is Timestamp)
          ? (data['ngayXacMinh'] as Timestamp).toDate()
          : null,
      cccdFrontImageUrl: data['cccdFrontImageUrl'] ?? data['anhMatTruoc'] ?? '',
      cccdBackImageUrl: data['cccdBackImageUrl'] ?? data['anhMatSau'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'userCode': userCode,
      'email': email,
      'displayName': displayName,
      'phoneNumber': phoneNumber,
      'role': role,
      'avatarUrl': avatarUrl,
      'gender': gender,
      'address': address,
      'hometown': hometown,
      'reputationScore': reputationScore,
      if (hostIndex > 0) 'hostIndex': hostIndex,

      'occupation': occupation,
      'workplace': workplace,
      'bio': bio,
      'hobbies': hobbies,
      'isCccdVerified': isCccdVerified,
      'cccdNumber': cccdNumber,
      'cccdFullName': cccdFullName,
      'cccdIssueDate': cccdIssueDate,
      'cccdHometown': cccdHometown,
      'cccdFrontImageUrl': cccdFrontImageUrl,
      'cccdBackImageUrl': cccdBackImageUrl,
      if (birthDate != null) 'birthDate': Timestamp.fromDate(birthDate!),
      if (cccdVerifiedAt != null)
        'cccdVerifiedAt': Timestamp.fromDate(cccdVerifiedAt!),
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  UserProfile copyWith({
    String? uid,
    String? userCode,
    String? email,
    String? displayName,
    String? phoneNumber,
    String? role,
    String? avatarUrl,
    String? gender,
    String? address,
    String? hometown,
    int? reputationScore,
    int? hostIndex,
    int? statusId,
    bool? isBanned,
    bool? accountDeleted,
    DateTime? suspendedUntil,
    String? suspensionType,
    String? occupation,
    String? workplace,
    String? bio,
    List<String>? hobbies,
    DateTime? birthDate,
    DateTime? createdAt,
    bool? isCccdVerified,
    String? cccdNumber,
    String? cccdFullName,
    String? cccdIssueDate,
    String? cccdHometown,
    DateTime? cccdVerifiedAt,
    String? cccdFrontImageUrl,
    String? cccdBackImageUrl,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      userCode: userCode ?? this.userCode,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      gender: gender ?? this.gender,
      address: address ?? this.address,
      hometown: hometown ?? this.hometown,
      reputationScore: reputationScore ?? this.reputationScore,
      hostIndex: hostIndex ?? this.hostIndex,
      statusId: statusId ?? this.statusId,
      isBanned: isBanned ?? this.isBanned,
      accountDeleted: accountDeleted ?? this.accountDeleted,
      suspendedUntil: suspendedUntil ?? this.suspendedUntil,
      suspensionType: suspensionType ?? this.suspensionType,
      occupation: occupation ?? this.occupation,
      workplace: workplace ?? this.workplace,
      bio: bio ?? this.bio,
      hobbies: hobbies ?? this.hobbies,
      birthDate: birthDate ?? this.birthDate,
      createdAt: createdAt ?? this.createdAt,
      isCccdVerified: isCccdVerified ?? this.isCccdVerified,
      cccdNumber: cccdNumber ?? this.cccdNumber,
      cccdFullName: cccdFullName ?? this.cccdFullName,
      cccdIssueDate: cccdIssueDate ?? this.cccdIssueDate,
      cccdHometown: cccdHometown ?? this.cccdHometown,
      cccdVerifiedAt: cccdVerifiedAt ?? this.cccdVerifiedAt,
      cccdFrontImageUrl: cccdFrontImageUrl ?? this.cccdFrontImageUrl,
      cccdBackImageUrl: cccdBackImageUrl ?? this.cccdBackImageUrl,
    );
  }
}

/// Hàm lưu kết quả xác thực CCCD eKYC vào Firestore và SharedPreferences
Future<void> saveCccdVerificationToBackend({
  required String uid,
  required String cccdNumber,
  required String cccdFullName,
  required String cccdIssueDate,
  required String cccdHometown,
  required String gender,
  DateTime? birthDate,
  String cccdFrontImageUrl = '',
  String cccdBackImageUrl = '',
}) async {
  final firestore = FirebaseFirestore.instance;
  final effectiveUid = (uid.isNotEmpty && uid != 'guest_uid')
      ? uid
      : (FirebaseAuth.instance.currentUser?.uid ?? uid);

  // Bảo toàn tên hiển thị (displayName) của tài khoản:
  // CCCD chỉ ghi nhận họ tên pháp lý (cccdFullName / hoTenCccd).
  // TUYỆT ĐỐI KHÔNG ghi đè displayName của chủ trọ/người dùng (ví dụ: QA vẫn là QA).
  String? existingDisplayName;
  if (effectiveUid.isNotEmpty && effectiveUid != 'guest_uid') {
    try {
      final doc = await firestore.collection('users').doc(effectiveUid).get();
      if (doc.exists && doc.data() != null) {
        final dName = (doc.data()?['displayName'] ?? doc.data()?['hoTen'])?.toString().trim();
        if (dName != null && dName.isNotEmpty) {
          existingDisplayName = dName;
        }
      }
    } catch (_) {}
  }

  if (existingDisplayName == null || existingDisplayName.isEmpty) {
    final authName = FirebaseAuth.instance.currentUser?.displayName?.trim();
    if (authName != null && authName.isNotEmpty) {
      existingDisplayName = authName;
    }
  }

  final updateData = <String, dynamic>{
    'isCccdVerified': true,
    'daXacThucCccd': true,
    'trangThaiXacMinh': 'daXacThuc',
    'trangThaiXacMinh_id': 'daXacThuc',
    'cccdNumber': cccdNumber,
    'soCccd': cccdNumber,
    'soGiayTo': cccdNumber,
    'cccdFullName': cccdFullName,
    'hoTenCccd': cccdFullName,
    // Chỉ gán displayName nếu tài khoản chưa có bất kỳ tên nào, không ghi đè tên đã có
    if (existingDisplayName == null || existingDisplayName.isEmpty)
      'displayName': cccdFullName,
    'cccdIssueDate': cccdIssueDate,
    'ngayCap': cccdIssueDate,
    'cccdHometown': cccdHometown,
    'queQuanCccd': cccdHometown,
    'gender': gender,
    'gioiTinh': gender,
    if (birthDate != null) 'birthDate': Timestamp.fromDate(birthDate),
    if (birthDate != null) 'ngaySinh': Timestamp.fromDate(birthDate),
    if (cccdFrontImageUrl.isNotEmpty) 'cccdFrontImageUrl': cccdFrontImageUrl,
    if (cccdBackImageUrl.isNotEmpty) 'cccdBackImageUrl': cccdBackImageUrl,
    'cccdVerifiedAt': FieldValue.serverTimestamp(),
    'ngayXacMinh': FieldValue.serverTimestamp(),
  };

  if (effectiveUid.isNotEmpty && effectiveUid != 'guest_uid') {
    try {
      await firestore
          .collection('users')
          .doc(effectiveUid)
          .set(updateData, SetOptions(merge: true));
      debugPrint('Đã lưu CCCD eKYC vào Firestore users/$effectiveUid thành công ✓');
    } catch (e) {
      debugPrint('Lỗi ghi CCCD vào Firestore users/$effectiveUid: $e');
    }

    try {
      await firestore
          .collection('users')
          .doc(effectiveUid)
          .collection('id_verifications')
          .doc('cccd')
          .set({
        'id': 'cccd',
        'type': 'cccd',
        'cccdNumber': cccdNumber,
        'cccdFullName': cccdFullName,
        'cccdIssueDate': cccdIssueDate,
        'cccdHometown': cccdHometown,
        'gender': gender,
        if (birthDate != null) 'birthDate': Timestamp.fromDate(birthDate),
        if (cccdFrontImageUrl.isNotEmpty) 'cccdFrontImageUrl': cccdFrontImageUrl,
        if (cccdBackImageUrl.isNotEmpty) 'cccdBackImageUrl': cccdBackImageUrl,
        'status': 'verified',
        'verifiedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Lỗi ghi subcollection id_verifications: $e');
    }
  }

  try {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = effectiveUid.isNotEmpty ? effectiveUid : 'current';
    await prefs.setBool('cccd_verified_$cacheKey', true);
    await prefs.setString('cccd_number_$cacheKey', cccdNumber);
    await prefs.setString('cccd_name_$cacheKey', cccdFullName);
    await prefs.setString('cccd_hometown_$cacheKey', cccdHometown);
    await prefs.setString('cccd_gender_$cacheKey', gender);
    if (birthDate != null) {
      await prefs.setString('cccd_birth_$cacheKey', birthDate.toIso8601String());
    }
    if (cccdFrontImageUrl.isNotEmpty) {
      await prefs.setString('cccd_front_$cacheKey', cccdFrontImageUrl);
    }
    if (cccdBackImageUrl.isNotEmpty) {
      await prefs.setString('cccd_back_$cacheKey', cccdBackImageUrl);
    }
  } catch (_) {}
}

/// Xóa toàn bộ thông tin xác thực CCCD trên Firestore và SharedPreferences để phục vụ kiểm thử
Future<void> resetCccdVerificationForTesting({required String uid, FirebaseFirestore? firestore}) async {
  final effectiveUid = (uid.isNotEmpty && uid != 'guest_uid')
      ? uid
      : (FirebaseAuth.instance.currentUser?.uid ?? uid);

  final resetData = <String, dynamic>{
    'isCccdVerified': false,
    'daXacThucCccd': false,
    'trangThaiXacMinh': 'chuaXacThuc',
    'trangThaiXacMinh_id': 'chuaXacThuc',
    'cccdNumber': FieldValue.delete(),
    'soCccd': FieldValue.delete(),
    'soGiayTo': FieldValue.delete(),
    'cccdFullName': FieldValue.delete(),
    'hoTenCccd': FieldValue.delete(),
    'cccdIssueDate': FieldValue.delete(),
    'ngayCap': FieldValue.delete(),
    'cccdHometown': FieldValue.delete(),
    'queQuanCccd': FieldValue.delete(),
    'cccdFrontImageUrl': FieldValue.delete(),
    'cccdBackImageUrl': FieldValue.delete(),
    'cccdVerifiedAt': FieldValue.delete(),
    'ngayXacMinh': FieldValue.delete(),
  };

  if (effectiveUid.isNotEmpty && effectiveUid != 'guest_uid') {
    try {
      final db = firestore ?? FirebaseFirestore.instance;
      await db.collection('users').doc(effectiveUid).set(resetData, SetOptions(merge: true));
      await db.collection('users').doc(effectiveUid).collection('id_verifications').doc('cccd').delete();
      debugPrint('Đã xóa dữ liệu xác thực CCCD users/$effectiveUid thành công ✓');
    } catch (e) {
      debugPrint('Lỗi xóa CCCD Firestore: $e');
    }
  }

  try {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = effectiveUid.isNotEmpty ? effectiveUid : 'current';
    await prefs.remove('cccd_verified_$cacheKey');
    await prefs.remove('cccd_number_$cacheKey');
    await prefs.remove('cccd_name_$cacheKey');
    await prefs.remove('cccd_hometown_$cacheKey');
    await prefs.remove('cccd_gender_$cacheKey');
    await prefs.remove('cccd_birth_$cacheKey');
    await prefs.remove('cccd_front_$cacheKey');
    await prefs.remove('cccd_back_$cacheKey');
    await prefs.remove('draft_cccd_front_image');
    await prefs.remove('draft_cccd_back_image');
    await prefs.remove('draft_cccd_data_json');
    await prefs.remove('draft_cccd_qr_payload');
  } catch (_) {}
}

bool _userFieldMissing(Object? value) {
  if (value == null) return true;
  if (value is String && value.trim().isEmpty) return true;
  return false;
}

/// Chép giá trị sang tên tiếng Anh nếu bản tiếng Anh đang trống, rồi xóa bản trùng.
Map<String, dynamic> englishUserFieldPatch(Map<String, dynamic> data) {
  final patch = <String, dynamic>{};

  void move(String english, List<String> aliases) {
    if (_userFieldMissing(data[english])) {
      for (final alias in aliases) {
        final value = data[alias];
        if (_userFieldMissing(value)) continue;
        patch[english] = value;
        break;
      }
    }
    for (final alias in aliases) {
      if (data.containsKey(alias)) patch[alias] = FieldValue.delete();
    }
  }

  move('displayName', ['hoTen']);
  move('phoneNumber', ['soDienThoai']);
  move('userCode', ['maNguoiDung', 'idNguoiDung']);
  move('createdAt', ['ngayTao']);
  move('reputationScore', ['diemUyTin']);
  move('gender', ['gioiTinh']);
  move('address', ['diaChi']);
  move('hometown', ['queQuan']);
  move('occupation', ['ngheNghiep']);
  move('workplace', ['noiLamViec']);
  move('bio', ['gioiThieu']);
  move('birthDate', ['ngaySinh']);
  move('cccdNumber', ['soCccd', 'soGiayTo']);
  move('cccdFullName', ['hoTenCccd']);
  move('cccdIssueDate', ['ngayCap']);
  move('cccdHometown', ['queQuanCccd']);
  move('cccdFrontImageUrl', ['anhMatTruoc']);
  move('cccdBackImageUrl', ['anhMatSau']);
  move('cccdVerifiedAt', ['ngayXacMinh']);

  if (_userFieldMissing(data['role'])) {
    final named = data['vaiTro'];
    if (named is String && named.trim().isNotEmpty) {
      patch['role'] = named.trim();
    }
  }
  if (data['isCccdVerified'] == null &&
      (data['daXacThucCccd'] == true ||
          data['trangThaiXacMinh'] == 'daXacThuc' ||
          data['trangThaiXacMinh_id'] == 'daXacThuc')) {
    patch['isCccdVerified'] = true;
  }
  for (final key in [
    'vaiTro',
    'vaiTro_id',
    'daXacThucCccd',
    'trangThaiXacMinh',
    'trangThaiXacMinh_id',
  ]) {
    if (data.containsKey(key)) patch[key] = FieldValue.delete();
  }
  return patch;
}

// StreamProvider lấy thông tin chi tiết user từ Cloud Firestore
final userProfileProvider = StreamProvider<UserProfile?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(null);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .asyncExpand((snapshot) => _userProfileEvents(snapshot, user));
});

Stream<UserProfile?> _userProfileEvents(
  DocumentSnapshot<Map<String, dynamic>> snapshot,
  User user,
) async* {
  if (!snapshot.exists || snapshot.data() == null) {
    final code = UserProfile.generateUserCode(seed: user.uid, role: 'renter');
    yield UserProfile(
      uid: user.uid,
      userCode: code,
      email: user.email ?? '',
      displayName: user.displayName ?? 'Người dùng HomeShare',
      phoneNumber: '',
      role: 'renter',
    );
    return;
  }

  final data = Map<String, dynamic>.from(snapshot.data()!);
  final resolvedRole = RoleResolver.extractRoleFromMap(data) ?? 'renter';
  final patch = englishUserFieldPatch(data);
  if (data['userCode'] == null &&
      data['maNguoiDung'] == null &&
      data['idNguoiDung'] == null) {
    patch['userCode'] = UserProfile.generateUserCode(
      seed: user.uid,
      role: resolvedRole,
    );
  }

  // Tự động khôi phục tên tài khoản (như "QA") nếu từng bị ghi đè trùng với cccdFullName:
  final authDisplayName = user.displayName?.trim() ?? '';
  final firestoreDisplayName = (data['displayName'] ?? data['hoTen'])?.toString().trim() ?? '';
  final cccdFullName = (data['cccdFullName'] ?? data['hoTenCccd'])?.toString().trim() ?? '';

  if (authDisplayName.isNotEmpty &&
      firestoreDisplayName.isNotEmpty &&
      cccdFullName.isNotEmpty &&
      firestoreDisplayName.toLowerCase() == cccdFullName.toLowerCase() &&
      authDisplayName.toLowerCase() != cccdFullName.toLowerCase()) {
    patch['displayName'] = authDisplayName;
    data['displayName'] = authDisplayName;
  }

  if (patch.isNotEmpty) {
    FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set(patch, SetOptions(merge: true));
  }

  var profile = UserProfile.fromMap(data, user.uid);

  // Chủ trọ đăng nhập: bảo đảm đã có hostIndex cố định trên Firebase.
  if (HostReputation.isHostRole(profile.role) && profile.hostIndex <= 0) {
    try {
      final index = await HostIndexService().ensureHostIndex(user.uid);
      profile = profile.copyWith(hostIndex: index);
    } catch (e) {
      debugPrint('Không cấp được hostIndex cho ${user.uid}: $e');
    }
  }

  // Render the signed-in shell as soon as Firestore returns the profile. Avatar
  // Storage lookup is secondary and must not hold up login/navigation.
  yield profile;

  if (profile.avatarUrl.trim().isNotEmpty) return;
  try {
    final storedAvatar = await ImageStorageService()
        .avatarDownloadUrl(user.uid)
        .timeout(const Duration(seconds: 2));
    if (storedAvatar != null && storedAvatar.isNotEmpty) {
      yield profile.copyWith(avatarUrl: storedAvatar);
    }
  } catch (_) {
    // Keep the profile usable if Storage is slow or unavailable.
  }
}

// Cập nhật vai trò người dùng trong Firestore
Future<void> updateUserRole({
  required String uid,
  required String newRole,
}) async {
  final normalized = RoleResolver.normalizeRole(newRole) ?? 'renter';
  await FirebaseFirestore.instance.collection('users').doc(uid).set({
    'role': normalized,
    'vaiTro': FieldValue.delete(),
    'vaiTro_id': FieldValue.delete(),
  }, SetOptions(merge: true));
  if (HostReputation.isHostRole(normalized)) {
    await HostIndexService().ensureHostIndex(uid);
  }
}

// Notifier quản lý Role hoạt động
class ActiveRoleNotifier extends Notifier<String> {
  @override
  String build() {
    return 'renter';
  }

  void switchRole(String role) {
    state = RoleResolver.normalizeRole(role) ?? 'renter';
  }
}

final activeRoleProvider = NotifierProvider<ActiveRoleNotifier, String>(
  ActiveRoleNotifier.new,
);
