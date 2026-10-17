import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/role_resolver.dart';
import '../../../core/utils/id_generator.dart';
import 'auth_provider.dart';

/// Model thông tin người dùng HomeShare chuẩn hóa theo Database homeShare (DrawIO pkg_0: Tài khoản)
/// Bảng: Người dùng, Sở thích (soDienThoai, email, hoTen, anhDaiDien, gioiTinh, ngaySinh, diaChi, diemUyTin, ngheNghiep)
class UserProfile {
  final String uid; // id
  final String? _userCode; // maNguoiDung 5 ký tự (3 số đầu + 2 chữ sau, vd: 382AN)
  final String email; // email
  final String displayName; // hoTen
  final String phoneNumber; // soDienThoai
  final String role; // vaiTro ('renter' / 'nguoiDung')
  final String avatarUrl; // anhDaiDien
  final String gender; // gioiTinh: nam | nu | khac
  final String address; // diaChi
  final String hometown; // queQuan
  final int reputationScore; // diemUyTin
  final String occupation; // ngheNghiep
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
  int get diemUyTin => reputationScore;
  String get ngheNghiep => occupation;
  List<String> get soThich => hobbies;
  String get vaiTro => role;
  bool get isRenter => role == 'renter' || role == 'tenant' || role == 'nguoidung';
  bool get isHost => role == 'host' || role == 'landlord' || role == 'chutro';
  bool get isAdmin => role == 'admin' || role == 'administrator' || role == 'quantri';
  bool get hasValidRole => RoleResolver.isValidRole(role);
  DateTime? get ngaySinh => birthDate;
  DateTime? get ngayTao => createdAt;
  bool get daXacThucCccd => isCccdVerified;
  String get soCccd => cccdNumber;
  String get soGiayTo => cccdNumber;
  String get hoTenCccd => cccdFullName;
  String get anhMatTruoc => cccdFrontImageUrl;
  String get anhMatSau => cccdBackImageUrl;

  /// Kiểm tra mã người dùng có đúng chuẩn CT001, NT001, ADMIN01 (hoặc chuẩn cũ 382AN) hay không
  static bool isValidUserCode(String code) {
    final clean = code.trim().toUpperCase();
    return RegExp(r'^(CT\d{3}|NT\d{3}|ADMIN\d{2,3}|\d{3}[A-Z]{2})$').hasMatch(clean);
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
    this.occupation = 'Sinh viên',
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
    final rawHobbies = (data['soThich'] ?? data['hobbies']) as List<dynamic>?;
    final parsedHobbies = rawHobbies
            ?.map((e) => e?.toString() ?? '')
            .where((e) => e.isNotEmpty)
            .toList() ??
        [];

    final resolvedRole = RoleResolver.extractRoleFromMap(data) ??
        (data['vaiTro'] != null ? RoleResolver.normalizeRole(data['vaiTro']) : null) ??
        (data['role'] != null ? RoleResolver.normalizeRole(data['role']) : null) ??
        'renter';

    final rawUserCode = (data['maNguoiDung'] ?? data['userCode'] ?? data['idNguoiDung'])?.toString();
    final userCode = (rawUserCode != null && isValidUserCode(rawUserCode))
        ? rawUserCode.trim().toUpperCase()
        : generateUserCode(seed: uid, role: resolvedRole);

    return UserProfile(
      uid: uid,
      userCode: userCode,
      email: data['email'] ?? '',
      displayName: data['hoTen'] ?? data['displayName'] ?? 'Người dùng HomeShare',
      phoneNumber: data['soDienThoai'] ?? data['phoneNumber'] ?? '',
      role: resolvedRole,
      avatarUrl: data['anhDaiDien'] ?? data['avatarUrl'] ?? '',
      gender: data['gioiTinh'] ?? data['gender'] ?? 'Nam',
      address: data['diaChi'] ?? data['address'] ?? '',
      hometown: data['queQuan'] ?? data['hometown'] ?? '',
      reputationScore: ((data['diemUyTin'] ?? data['reputationScore']) as num?)?.toInt() ?? 100,
      occupation: data['ngheNghiep'] ?? data['occupation'] ?? 'Sinh viên',
      hobbies: parsedHobbies,
      birthDate: (data['ngaySinh'] is Timestamp)
          ? (data['ngaySinh'] as Timestamp).toDate()
          : (data['birthDate'] is Timestamp)
              ? (data['birthDate'] as Timestamp).toDate()
              : null,
      createdAt: (data['ngayTao'] is Timestamp)
          ? (data['ngayTao'] as Timestamp).toDate()
          : (data['createdAt'] is Timestamp)
              ? (data['createdAt'] as Timestamp).toDate()
              : null,
      isCccdVerified: (data['daXacThucCccd'] ??
              data['isCccdVerified'] ??
              (data['trangThaiXacMinh'] == 'daXacThuc') ??
              (data['trangThaiXacMinh_id'] == 'daXacThuc')) ??
          false,
      cccdNumber: data['soCccd'] ?? data['soGiayTo'] ?? data['cccdNumber'] ?? '',
      cccdFullName: data['hoTenCccd'] ?? data['cccdFullName'] ?? '',
      cccdIssueDate: data['ngayCap'] ?? data['cccdIssueDate'] ?? '',
      cccdHometown: data['queQuanCccd'] ?? data['cccdHometown'] ?? '',
      cccdVerifiedAt: (data['ngayXacMinh'] is Timestamp)
          ? (data['ngayXacMinh'] as Timestamp).toDate()
          : (data['cccdVerifiedAt'] is Timestamp)
              ? (data['cccdVerifiedAt'] as Timestamp).toDate()
              : null,
      cccdFrontImageUrl: data['anhMatTruoc'] ?? data['cccdFrontImageUrl'] ?? '',
      cccdBackImageUrl: data['anhMatSau'] ?? data['cccdBackImageUrl'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'maNguoiDung': userCode,
      'email': email,
      'hoTen': displayName,
      'soDienThoai': phoneNumber,
      'vaiTro': role,
      'anhDaiDien': avatarUrl,
      'gioiTinh': gender,
      'diaChi': address,
      'queQuan': hometown,
      'diemUyTin': reputationScore,
      'ngheNghiep': occupation,
      'soThich': hobbies,
      'daXacThucCccd': isCccdVerified,
      'trangThaiXacMinh': isCccdVerified ? 'daXacThuc' : 'chuaXacThuc',
      'soCccd': cccdNumber,
      'hoTenCccd': cccdFullName,
      'ngayCap': cccdIssueDate,
      'queQuanCccd': cccdHometown,
      'anhMatTruoc': cccdFrontImageUrl,
      'anhMatSau': cccdBackImageUrl,
      if (birthDate != null) 'ngaySinh': Timestamp.fromDate(birthDate!),
      if (cccdVerifiedAt != null) 'ngayXacMinh': Timestamp.fromDate(cccdVerifiedAt!),
      'ngayTao': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
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
    String? occupation,
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
      occupation: occupation ?? this.occupation,
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
  final updateData = <String, dynamic>{
    'isCccdVerified': true,
    'daXacThucCccd': true,
    'trangThaiXacMinh_id': 'daXacThuc',
    'cccdNumber': cccdNumber,
    'soGiayTo': cccdNumber,
    'soCccd': cccdNumber,
    'cccdFullName': cccdFullName,
    'hoTenCccd': cccdFullName,
    'displayName': cccdFullName,
    'hoTen': cccdFullName,
    'cccdIssueDate': cccdIssueDate,
    'cccdHometown': cccdHometown,
    'gender': gender,
    'gioiTinh': gender,
    if (birthDate != null) 'birthDate': Timestamp.fromDate(birthDate),
    if (birthDate != null) 'ngaySinh': Timestamp.fromDate(birthDate),
    if (cccdFrontImageUrl.isNotEmpty) ...{
      'cccdFrontImageUrl': cccdFrontImageUrl,
      'anhMatTruoc': cccdFrontImageUrl,
    },
    if (cccdBackImageUrl.isNotEmpty) ...{
      'cccdBackImageUrl': cccdBackImageUrl,
      'anhMatSau': cccdBackImageUrl,
    },
    'cccdVerifiedAt': FieldValue.serverTimestamp(),
    'ngayXacMinh': FieldValue.serverTimestamp(),
  };

  try {
    await firestore.collection('users').doc(uid).set(updateData, SetOptions(merge: true));
  } catch (e) {
    // Offline / fallback fallback
  }

  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('cccd_verified_$uid', true);
    await prefs.setString('cccd_number_$uid', cccdNumber);
    await prefs.setString('cccd_name_$uid', cccdFullName);
    if (cccdFrontImageUrl.isNotEmpty) {
      await prefs.setString('cccd_front_$uid', cccdFrontImageUrl);
    }
    if (cccdBackImageUrl.isNotEmpty) {
      await prefs.setString('cccd_back_$uid', cccdBackImageUrl);
    }
  } catch (_) {}
}

// StreamProvider lấy thông tin chi tiết user từ Cloud Firestore
final userProfileProvider = StreamProvider<UserProfile?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(null);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map((snapshot) {
    if (!snapshot.exists || snapshot.data() == null) {
      final code = UserProfile.generateUserCode(seed: user.uid, role: 'renter');
      return UserProfile(
        uid: user.uid,
        userCode: code,
        email: user.email ?? '',
        displayName: user.displayName ?? 'Người dùng HomeShare',
        phoneNumber: '',
        role: 'renter',
      );
    }
    final data = snapshot.data()!;
    final resolvedRole = RoleResolver.extractRoleFromMap(data) ?? 'renter';
    if (data['userCode'] == null || data['maNguoiDung'] == null) {
      final code = UserProfile.generateUserCode(seed: user.uid, role: resolvedRole);
      FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'userCode': code,
        'maNguoiDung': code,
        'idNguoiDung': code,
      }, SetOptions(merge: true));
    }
    return UserProfile.fromMap(data, user.uid);
  });
});

// Cập nhật vai trò người dùng trong Firestore
Future<void> updateUserRole({
  required String uid,
  required String newRole,
}) async {
  final normalized = RoleResolver.normalizeRole(newRole) ?? 'renter';
  await FirebaseFirestore.instance.collection('users').doc(uid).set({
    'role': normalized,
    'vaiTro': normalized,
    'vaiTro_id': normalized == 'host' ? 2 : (normalized == 'admin' ? 3 : 1),
  }, SetOptions(merge: true));
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

final activeRoleProvider = NotifierProvider<ActiveRoleNotifier, String>(ActiveRoleNotifier.new);
