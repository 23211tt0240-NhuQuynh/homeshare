import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_provider.dart';
import '../../../core/services/user_profile_service.dart';

/// Model thông tin người dùng HomeShare chuẩn hóa theo Database homeShare (DrawIO pkg_0: Tài khoản)
/// Bảng: Người dùng, Sở thích (soDienThoai, email, hoTen, anhDaiDien, gioiTinh, ngaySinh, diaChi, diemUyTin, ngheNghiep)
class UserProfile {
  final String uid; // id
  final String? _userCode; // maNguoiDung 5 ký tự (3 số đầu + 2 chữ sau, vd: 382AN)
  final String email; // email
  final String displayName; // hoTen
  final String phoneNumber; // soDienThoai
  final String role; // giá trị trong bộ nhớ: renter / host / admin
  final int roleId; // khóa số của bảng roles: 1 Khách, 2 Chủ, 3 Admin
  final int statusId; // khóa số của bảng user_statuses: 1 Hoạt động, 2 Khóa tài khoản
  final String avatarUrl; // anhDaiDien
  final String gender; // gioiTinh: nam | nu | khac
  final String address; // diaChi
  final String hometown; // queQuan
  final int reputationScore; // diemUyTin
  final String occupation; // ngheNghiep
  final String workplace; // noiLamViec — đơn vị công tác, không có bảng riêng trong DrawIO
  final String bio; // gioiThieu — người dùng tự viết, không có bảng riêng trong DrawIO
  final List<String> hobbies; // tên sở thích (bản sao); nguồn chuẩn là bảng NguoiDung_SoThich
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
      : generateUserCode(seed: uid);
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
  String get noiLamViec => workplace;
  String get gioiThieu => bio;
  List<String> get soThich => hobbies;
  String get vaiTro => role;
  bool get isRenter => role == 'renter';
  bool get isHost => role == 'host';
  DateTime? get ngaySinh => birthDate;
  DateTime? get ngayTao => createdAt;
  bool get daXacThucCccd => isCccdVerified;
  String get soCccd => cccdNumber;
  String get soGiayTo => cccdNumber;
  String get hoTenCccd => cccdFullName;
  String get anhMatTruoc => cccdFrontImageUrl;
  String get anhMatSau => cccdBackImageUrl;

  /// Kiểm tra mã người dùng có đúng chuẩn 5 ký tự (3 số đầu + 2 chữ sau) hay không
  static bool isValidUserCode(String code) {
    return RegExp(r'^\d{3}[A-Z]{2}$').hasMatch(code.trim().toUpperCase());
  }

  /// Sinh mã người dùng chuẩn 5 ký tự gồm 3 số đầu và 2 chữ cái sau (vd: 382AN, 825TO)
  /// - Nếu truyền seed (UID), thuật toán băm tất định (deterministic) đảm bảo mã luôn cố định
  /// - Nếu không có seed, sinh ngẫu nhiên chuẩn 3 số (100-999) + 2 chữ in hoa (A-Z)
  static String generateUserCode({String? seed}) {
    if (seed != null && seed.isNotEmpty) {
      var hash = 0;
      for (var i = 0; i < seed.length; i++) {
        hash = (hash * 31 + seed.codeUnitAt(i)) & 0x7FFFFFFF;
      }
      final digits = (100 + (hash % 900)).toString();
      const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
      final char1 = letters[(hash ~/ 900) % 26];
      final char2 = letters[(hash ~/ 23400) % 26];
      return '$digits$char1$char2';
    } else {
      final rand = Random();
      final digits = (100 + rand.nextInt(900)).toString();
      const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
      final char1 = letters[rand.nextInt(letters.length)];
      final char2 = letters[rand.nextInt(letters.length)];
      return '$digits$char1$char2';
    }
  }

  UserProfile({
    required this.uid,
    String? userCode,
    required this.email,
    required this.displayName,
    required this.phoneNumber,
    this.role = 'renter',
    int? roleId,
    int? statusId,
    this.avatarUrl = '',
    this.gender = '',
    this.address = '',
    this.hometown = '',
    this.reputationScore = 100,
    this.occupation = '',
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
  }) : roleId = roleId ?? UserProfileService.roleIdFor(role),
        statusId = statusId ?? UserProfileService.statusActiveId,
        _userCode = (userCode != null && isValidUserCode(userCode))
            ? userCode.trim().toUpperCase()
            : generateUserCode(seed: uid);

  /// Vai trò lưu trên users là chữ: renter, host, admin.
  static String roleNameFromData(Map<String, dynamic> data) {
    final name = '${data['role'] ?? data['vaiTro'] ?? ''}'.trim().toLowerCase();
    if (name == 'host') return 'host';
    if (name == 'admin') return 'admin';
    return 'renter';
  }

  /// Document users lúc đăng ký. Chỉ các trường đã có dữ liệu, tên tiếng Anh.
  static Map<String, dynamic> registrationData({
    required String uid,
    required String email,
    required String displayName,
    required String phoneNumber,
    required String role,
    required String userCode,
  }) {
    return {
      'uid': uid,
      'userCode': userCode,
      'email': email.trim(),
      'displayName': displayName.trim(),
      'phoneNumber': phoneNumber.trim(),
      'role': roleNameFromData({'role': role}),
      'avatarUrl': '',
      'reputationScore': 100,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  static int _statusIdFrom(Map<String, dynamic> data) {
    final raw = data['statusId'] ?? data['trangThai_Id'] ?? data['trangThaiId'];
    if (raw is num && raw.toInt() >= 1) return raw.toInt();
    final parsed = int.tryParse('$raw');
    if (parsed != null && parsed >= 1) return parsed;
    return UserProfileService.statusActiveId;
  }

  factory UserProfile.fromMap(Map<String, dynamic> data, String uid) {
    final rawHobbies = (data['hobbies'] ?? data['soThich']) as List<dynamic>?;
    final parsedHobbies = rawHobbies
            ?.map((e) => e?.toString() ?? '')
            .where((e) => e.isNotEmpty)
            .toList() ??
        [];

    final rawUserCode = (data['userCode'] ?? data['maNguoiDung'] ?? data['idNguoiDung'])?.toString();
    final userCode = (rawUserCode != null && isValidUserCode(rawUserCode))
        ? rawUserCode.trim().toUpperCase()
        : generateUserCode(seed: uid);

    return UserProfile(
      uid: uid,
      userCode: userCode,
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? data['hoTen'] ?? 'Người dùng HomeShare',
      phoneNumber: data['phoneNumber'] ?? data['soDienThoai'] ?? '',
      role: roleNameFromData(data),
      statusId: _statusIdFrom(data),
      avatarUrl: data['avatarUrl'] ?? data['anhDaiDien'] ?? '',
      gender: data['gender'] ?? data['gioiTinh'] ?? '',
      address: data['address'] ?? data['diaChi'] ?? '',
      hometown: data['hometown'] ?? data['queQuan'] ?? '',
      reputationScore: ((data['reputationScore'] ?? data['diemUyTin']) as num?)?.toInt() ?? 100,
      occupation: data['occupation'] ?? data['ngheNghiep'] ?? '',
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
      isCccdVerified: (data['isCccdVerified'] ?? (data['trangThaiXacMinh_id'] == 'daXacThuc')) ?? false,
      cccdNumber: data['cccdNumber'] ?? data['soGiayTo'] ?? data['soCccd'] ?? '',
      cccdFullName: data['cccdFullName'] ?? data['hoTenCccd'] ?? '',
      cccdIssueDate: data['cccdIssueDate'] ?? '',
      cccdHometown: data['cccdHometown'] ?? '',
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
      if (cccdVerifiedAt != null) 'cccdVerifiedAt': Timestamp.fromDate(cccdVerifiedAt!),
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }

  UserProfile copyWith({
    String? uid,
    String? userCode,
    String? email,
    String? displayName,
    String? phoneNumber,
    String? role,
    int? roleId,
    int? statusId,
    String? avatarUrl,
    String? gender,
    String? address,
    String? hometown,
    int? reputationScore,
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
      roleId: roleId ?? (role != null ? UserProfileService.roleIdFor(role) : this.roleId),
      statusId: statusId ?? this.statusId,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      gender: gender ?? this.gender,
      address: address ?? this.address,
      hometown: hometown ?? this.hometown,
      reputationScore: reputationScore ?? this.reputationScore,
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
  final updateData = <String, dynamic>{
    'isCccdVerified': true,
    'cccdNumber': cccdNumber,
    'cccdFullName': cccdFullName,
    'displayName': cccdFullName,
    'cccdIssueDate': cccdIssueDate,
    'cccdHometown': cccdHometown,
    'gender': gender,
    if (birthDate != null) 'birthDate': Timestamp.fromDate(birthDate),
    if (cccdFrontImageUrl.isNotEmpty) 'cccdFrontImageUrl': cccdFrontImageUrl,
    if (cccdBackImageUrl.isNotEmpty) 'cccdBackImageUrl': cccdBackImageUrl,
    'cccdVerifiedAt': FieldValue.serverTimestamp(),
    'daXacThucCccd': FieldValue.delete(),
    'trangThaiXacMinh_id': FieldValue.delete(),
    'soGiayTo': FieldValue.delete(),
    'soCccd': FieldValue.delete(),
    'hoTenCccd': FieldValue.delete(),
    'hoTen': FieldValue.delete(),
    'gioiTinh': FieldValue.delete(),
    'ngaySinh': FieldValue.delete(),
    'anhMatTruoc': FieldValue.delete(),
    'anhMatSau': FieldValue.delete(),
    'ngayXacMinh': FieldValue.delete(),
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
      final code = UserProfile.generateUserCode(seed: user.uid);
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
    UserProfileService().dedupeAllUserAccounts();
    UserProfileService().renameHobbyTablesToEnglish();
    UserProfileService().splitPersonalHobbies();
    // Đảm bảo mã người dùng 5 ký tự luôn được lưu trong Firestore để Admin tìm kiếm
    if (data['userCode'] == null && data['maNguoiDung'] == null && data['idNguoiDung'] == null) {
      final code = UserProfile.generateUserCode(seed: user.uid);
      FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'userCode': code,
      }, SetOptions(merge: true));
    }
    return UserProfile.fromMap(data, user.uid);
  });
});

// Notifier quản lý Role hoạt động (Chỉ người dùng / Renter)
class ActiveRoleNotifier extends Notifier<String> {
  @override
  String build() {
    return 'renter';
  }

  void switchRole(String role) {
    state = 'renter'; // Cố định role người dùng theo yêu cầu dự án
  }
}

final activeRoleProvider = NotifierProvider<ActiveRoleNotifier, String>(ActiveRoleNotifier.new);
