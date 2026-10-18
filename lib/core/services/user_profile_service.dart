import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'image_storage_service.dart';

/// Id tài liệu bảng trung gian `NguoiDung_SoThich` (khóa kép nguoiDungId + soThichId).
String nguoiDungSoThichDocId(String nguoiDungId, String soThichId) {
  return '${nguoiDungId}__$soThichId';
}

/// SoThichId hiện có mà người dùng bỏ chọn — chỉ gỡ liên kết, không xóa danh mục Sở thích.
Set<String> soThichIdsToUnlink({
  required Set<String> currentSoThichIds,
  required Set<String> desiredSoThichIds,
}) {
  return currentSoThichIds.difference(desiredSoThichIds);
}

/// Lưu hồ sơ người dùng và sở thích theo quan hệ nhiều-nhiều.
///
/// - `users/{uid}` tương ứng bảng Người dùng.
/// - `hobbies/{id}` tương ứng bảng Sở thích (`tenSoThich`).
/// - `user_hobbies/{userId__hobbyId}` tương ứng bảng nối người dùng và sở thích.
/// Không ghi vào bảng Yêu thích (đó là bài đăng / tin ở ghép đã lưu).
class UserProfileService {
  UserProfileService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    ImageStorageService? images,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _images = images ?? ImageStorageService();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final ImageStorageService _images;

  CollectionReference<Map<String, dynamic>> get _users => _firestore.collection('users');
  CollectionReference<Map<String, dynamic>> get _soThich => _firestore.collection('hobbies');
  CollectionReference<Map<String, dynamic>> get _links => _firestore.collection('user_hobbies');
  CollectionReference<Map<String, dynamic>> get _roles => _firestore.collection('roles');
  CollectionReference<Map<String, dynamic>> get _userStatuses => _firestore.collection('user_statuses');

  static const int roleGuestId = 1;
  static const int roleHostId = 2;
  static const int roleAdminId = 3;
  static const int statusActiveId = 1;
  static const int statusLockedId = 2;

  /// Người thuê là 1 (Khách), chủ trọ là 2 (Chủ), quản trị là 3 (Admin).
  static int roleIdFor(String role) {
    switch (role) {
      case 'host':
        return roleHostId;
      case 'admin':
        return roleAdminId;
      default:
        return roleGuestId;
    }
  }

  /// Ba vai trò dùng chung. `id` là số, đúng kiểu khóa của bảng Vai trò.
  Future<void> ensureRoles() async {
    final batch = _firestore.batch();
    void role(int id, String name) {
      batch.set(_roles.doc('$id'), {
        'id': id,
        'name': name,
      });
    }

    role(roleGuestId, 'Khách');
    role(roleHostId, 'Chủ');
    role(roleAdminId, 'Admin');
    batch.delete(_roles.doc('guest'));
    batch.delete(_roles.doc('host'));
    batch.delete(_roles.doc('admin'));
    await batch.commit();
  }

  /// Trạng thái người dùng. Thêm trạng thái mới bằng một document số tiếp theo, ví dụ id 3.
  Future<void> ensureUserStatuses() async {
    final batch = _firestore.batch();
    void status(int id, String name) {
      batch.set(_userStatuses.doc('$id'), {
        'id': id,
        'name': name,
      });
    }

    status(statusActiveId, 'Hoạt động');
    status(statusLockedId, 'Khóa tài khoản');
    await batch.commit();
  }

  static bool _accountsAligned = false;

  static int roleIdFromData(Map<String, dynamic> data) {
    final raw = data['roleId'] ?? data['vaiTro_id'];
    if (raw is num) {
      final id = raw.toInt();
      if (id >= roleGuestId && id <= roleAdminId) return id;
    }
    final parsed = int.tryParse('$raw');
    if (parsed != null && parsed >= roleGuestId && parsed <= roleAdminId) return parsed;
    return roleIdFor('${data['role'] ?? data['vaiTro'] ?? ''}');
  }

  static int statusIdFromData(Map<String, dynamic> data) {
    final raw = data['statusId'] ?? data['trangThai_Id'] ?? data['trangThaiId'];
    if (raw is num && raw.toInt() >= 1) return raw.toInt();
    final parsed = int.tryParse('$raw');
    if (parsed != null && parsed >= 1) return parsed;
    return statusActiveId;
  }

  static bool _usersDeduped = false;

  /// Xóa trường tiếng Việt trùng giá trị trên mọi tài khoản. Giữ một tên tiếng Anh.
  Future<void> dedupeAllUserAccounts() async {
    if (_usersDeduped) return;
    _usersDeduped = true;
    try {
      final snap = await _users.get();
      for (final doc in snap.docs) {
        await _dedupeUserDoc(doc.reference, doc.data());
      }
      debugPrint('Đã gộp trường tiếng Anh cho ${snap.docs.length} tài khoản');
    } catch (e, st) {
      _usersDeduped = false;
      debugPrint('Gộp trường users lỗi: $e\n$st');
    }
  }

  Future<void> _dedupeUserDoc(DocumentReference<Map<String, dynamic>> ref, Map<String, dynamic> data) async {
    final patch = <String, dynamic>{};
    void keep(String english, List<String> aliases) {
      if (data[english] == null) {
        for (final alias in aliases) {
          final value = data[alias];
          if (value == null) continue;
          if (value is String && value.trim().isEmpty) continue;
          patch[english] = value;
          break;
        }
      }
      for (final alias in aliases) {
        if (data.containsKey(alias)) patch[alias] = FieldValue.delete();
      }
    }

    keep('displayName', ['hoTen']);
    keep('phoneNumber', ['soDienThoai']);
    keep('avatarUrl', ['anhDaiDien']);
    keep('gender', ['gioiTinh']);
    keep('address', ['diaChi']);
    keep('hometown', ['queQuan']);
    keep('reputationScore', ['diemUyTin']);
    keep('occupation', ['ngheNghiep']);
    keep('workplace', ['noiLamViec']);
    keep('bio', ['gioiThieu']);
    keep('hobbies', ['soThich']);
    keep('birthDate', ['ngaySinh']);
    keep('createdAt', ['ngayTao']);
    keep('userCode', ['maNguoiDung', 'idNguoiDung']);
    keep('cccdNumber', ['soGiayTo', 'soCccd']);
    keep('cccdFullName', ['hoTenCccd']);
    keep('cccdFrontImageUrl', ['anhMatTruoc']);
    keep('cccdBackImageUrl', ['anhMatSau']);
    keep('cccdVerifiedAt', ['ngayXacMinh']);
    keep('isCccdVerified', ['daXacThucCccd']);
    keep('lastActiveAt', ['lanHoatDongCuoi']);

    if (data['role'] == null) {
      final named = data['vaiTro'];
      if (named is String && named.trim().isNotEmpty) {
        patch['role'] = named.trim();
      }
    }
    for (final key in ['vaiTro', 'vaiTro_id', 'roleId', 'statusId', 'trangThai_Id', 'trangThaiId']) {
      if (data.containsKey(key)) patch[key] = FieldValue.delete();
    }
    if (patch.isNotEmpty) await ref.set(patch, SetOptions(merge: true));
  }

  static const vantheUid = 'tX2g6Pdk05MA44YkREEU5s74zTn1';
  static bool _rolledBack = false;

  /// Đưa Firebase về lúc collection ảnh ở ghép còn trống, chưa có bảng vai trò và trạng thái.
  Future<void> rollbackFirebaseToRoommateImagesMoment() async {
    if (_rolledBack) return;
    _rolledBack = true;
    try {
      await _deleteWholeCollection('roles');
      await _deleteWholeCollection('user_statuses');
      await _deleteWholeCollection('roommate_post_images');
      final favorites = await _firestore.collection('favorites').get();
      for (final doc in favorites.docs) {
        final type = '${doc.data()['targetType'] ?? ''}';
        if (type == 'roommatePost' || doc.id.contains('roommatePost')) {
          await doc.reference.delete();
        }
      }
      final users = await _users.get();
      for (final doc in users.docs) {
        await _restoreUserBeforeStatusTable(doc);
      }
      debugPrint('Đã đưa Firebase về lúc chưa có roommate_post_images: ${users.docs.length} tài khoản');
    } catch (e, st) {
      _rolledBack = false;
      debugPrint('Rollback Firebase lỗi: $e\n$st');
    }
  }

  Future<void> _deleteWholeCollection(String name) async {
    final snap = await _firestore.collection(name).get();
    for (final doc in snap.docs) {
      await doc.reference.delete();
    }
  }

  Future<void> _restoreUserBeforeStatusTable(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data() ?? {};
    final roleId = roleIdFromData(data);
    final roleName = roleId == roleHostId
        ? 'host'
        : roleId == roleAdminId
            ? 'admin'
            : 'renter';
    if (doc.id == vantheUid) {
      await doc.reference.set({
        'userCode': '968DE',
        'idNguoiDung': '968DE',
        'maNguoiDung': '968DE',
        'role': 'renter',
        'displayName': data['displayName'] ?? 'vanthe',
        'phoneNumber': data['phoneNumber'] ?? '096736165',
        'avatarUrl': data['avatarUrl'] ?? '',
        'roleId': FieldValue.delete(),
        'statusId': FieldValue.delete(),
        'lastActiveAt': FieldValue.delete(),
        'reputationScore': FieldValue.delete(),
        'vaiTro': FieldValue.delete(),
        'vaiTro_id': FieldValue.delete(),
        'hoTen': FieldValue.delete(),
        'soDienThoai': FieldValue.delete(),
        'anhDaiDien': FieldValue.delete(),
        'diemUyTin': FieldValue.delete(),
        'ngayTao': FieldValue.delete(),
        'lanHoatDongCuoi': FieldValue.delete(),
        'gioiTinh': FieldValue.delete(),
        'diaChi': FieldValue.delete(),
        'queQuan': FieldValue.delete(),
        'ngheNghiep': FieldValue.delete(),
        'ngaySinh': FieldValue.delete(),
        'gender': FieldValue.delete(),
        'address': FieldValue.delete(),
        'hometown': FieldValue.delete(),
        'occupation': FieldValue.delete(),
        'workplace': FieldValue.delete(),
        'bio': FieldValue.delete(),
        'hobbies': FieldValue.delete(),
        'soThich': FieldValue.delete(),
        'trangThai_Id': FieldValue.delete(),
        'trangThaiId': FieldValue.delete(),
      }, SetOptions(merge: true));
      return;
    }

    final patch = <String, dynamic>{
      'roleId': FieldValue.delete(),
      'statusId': FieldValue.delete(),
      'lastActiveAt': FieldValue.delete(),
      'trangThai_Id': FieldValue.delete(),
      'trangThaiId': FieldValue.delete(),
    };
    if (data['role'] == null) patch['role'] = roleName;
    if (data['vaiTro'] == null) patch['vaiTro'] = roleName;
    if (data['vaiTro_id'] == null) patch['vaiTro_id'] = roleId;
    final code = data['userCode']?.toString() ?? '';
    if (code.isNotEmpty) {
      if (data['maNguoiDung'] == null) patch['maNguoiDung'] = code;
      if (data['idNguoiDung'] == null) patch['idNguoiDung'] = code;
    }
    void mirror(String englishKey, String vietnameseKey) {
      final value = data[englishKey];
      if (data[vietnameseKey] != null || value == null) return;
      if (value is String && value.trim().isEmpty) return;
      patch[vietnameseKey] = value;
    }

    mirror('displayName', 'hoTen');
    mirror('phoneNumber', 'soDienThoai');
    mirror('avatarUrl', 'anhDaiDien');
    mirror('gender', 'gioiTinh');
    mirror('address', 'diaChi');
    mirror('hometown', 'queQuan');
    mirror('occupation', 'ngheNghiep');
    mirror('reputationScore', 'diemUyTin');
    mirror('createdAt', 'ngayTao');
    mirror('birthDate', 'ngaySinh');
    await doc.reference.set(patch, SetOptions(merge: true));
  }

  /// Gắn roleId, statusId và trường tiếng Anh cho mọi tài khoản. Giữ vai trò đang có.
  Future<void> alignAllUserAccounts() async {
    if (_accountsAligned) return;
    _accountsAligned = true;
    try {
      await ensureRoles();
      await ensureUserStatuses();
      final snap = await _users.get();
      for (final doc in snap.docs) {
        await _alignUserDoc(doc.reference, doc.data());
      }
      debugPrint('Đã áp dụng users, roleId và statusId cho ${snap.docs.length} tài khoản');
    } catch (e, st) {
      _accountsAligned = false;
      debugPrint('Áp dụng users lỗi: $e\n$st');
    }
  }

  Future<void> _alignUserDoc(DocumentReference<Map<String, dynamic>> ref, Map<String, dynamic> data) async {
    String textOf(List<String> keys) {
      for (final key in keys) {
        final value = data[key];
        if (value is String && value.trim().isNotEmpty) return value.trim();
      }
      return '';
    }

    final roleId = roleIdFromData(data);
    final statusId = statusIdFromData(data);
    final patch = <String, dynamic>{
      'roleId': roleId,
      'statusId': statusId,
      'hoTen': FieldValue.delete(),
      'soDienThoai': FieldValue.delete(),
      'anhDaiDien': FieldValue.delete(),
      'diemUyTin': FieldValue.delete(),
      'gioiTinh': FieldValue.delete(),
      'diaChi': FieldValue.delete(),
      'queQuan': FieldValue.delete(),
      'ngheNghiep': FieldValue.delete(),
      'ngaySinh': FieldValue.delete(),
      'ngayTao': FieldValue.delete(),
      'lanHoatDongCuoi': FieldValue.delete(),
      'idNguoiDung': FieldValue.delete(),
      'maNguoiDung': FieldValue.delete(),
      'role': FieldValue.delete(),
      'vaiTro': FieldValue.delete(),
      'vaiTro_id': FieldValue.delete(),
      'trangThai_Id': FieldValue.delete(),
      'trangThaiId': FieldValue.delete(),
      'soThich': FieldValue.delete(),
    };
    final displayName = textOf(['displayName', 'hoTen']);
    if (displayName.isNotEmpty) patch['displayName'] = displayName;
    final phone = textOf(['phoneNumber', 'soDienThoai']);
    if (phone.isNotEmpty) patch['phoneNumber'] = phone;
    final avatar = textOf(['avatarUrl', 'anhDaiDien']);
    if (avatar.isNotEmpty) patch['avatarUrl'] = avatar;
    if (data['reputationScore'] == null && data['diemUyTin'] != null) {
      patch['reputationScore'] = data['diemUyTin'];
    }
    final gender = textOf(['gender', 'gioiTinh']);
    if (gender.isNotEmpty) patch['gender'] = gender;
    final address = textOf(['address', 'diaChi']);
    if (address.isNotEmpty) patch['address'] = address;
    final hometown = textOf(['hometown', 'queQuan']);
    if (hometown.isNotEmpty) patch['hometown'] = hometown;
    final occupation = textOf(['occupation', 'ngheNghiep']);
    if (occupation.isNotEmpty) patch['occupation'] = occupation;
    final birthDate = data['birthDate'] ?? data['ngaySinh'];
    if (birthDate != null) patch['birthDate'] = birthDate;
    if (data['createdAt'] == null && data['ngayTao'] != null) {
      patch['createdAt'] = data['ngayTao'];
    }
    final code = textOf(['userCode', 'maNguoiDung', 'idNguoiDung']);
    if (code.isNotEmpty && data['userCode'] == null) patch['userCode'] = code;
    await ref.set(patch, SetOptions(merge: true));

    final names = <String>[];
    final raw = data['hobbies'] ?? data['soThich'];
    if (raw is List) {
      for (final item in raw) {
        final name = '$item'.trim();
        if (name.isNotEmpty && !names.any((e) => e.toLowerCase() == name.toLowerCase())) {
          names.add(name);
        }
      }
    }
    if (names.isNotEmpty) {
      await syncInterests(uid: ref.id, names: names);
    }
  }

  static bool _hobbiesSplit = false;

  static bool _hobbyTablesRenamed = false;

  /// Chuyển document từ tên cũ `soThich` và `nguoiDung_soThich` sang `hobbies` và `user_hobbies`.
  Future<void> renameHobbyTablesToEnglish() async {
    if (_hobbyTablesRenamed) return;
    _hobbyTablesRenamed = true;
    try {
      final hobbyCount = await _moveCollection('soThich', 'hobbies');
      final linkCount = await _moveCollection('nguoiDung_soThich', 'user_hobbies');
      debugPrint('Đã đổi tên bảng sở thích: $hobbyCount hobbies, $linkCount user_hobbies');
    } catch (e, st) {
      _hobbyTablesRenamed = false;
      debugPrint('Đổi tên bảng sở thích lỗi: $e\n$st');
    }
  }

  Future<int> _moveCollection(String from, String to) async {
    final snap = await _firestore.collection(from).get();
    var moved = 0;
    for (final doc in snap.docs) {
      await _firestore.collection(to).doc(doc.id).set(doc.data(), SetOptions(merge: true));
      await doc.reference.delete();
      moved++;
    }
    return moved;
  }

  /// Chép sở thích đang có trên tài khoản sang `hobbies` và `user_hobbies`. Không ghi bảng users.
  Future<void> splitPersonalHobbies() async {
    if (_hobbiesSplit) return;
    _hobbiesSplit = true;
    try {
      final users = await _users.get();
      var people = 0;
      for (final doc in users.docs) {
        final names = _hobbyNames(doc.data());
        if (names.isEmpty) continue;
        people++;
        await syncInterests(uid: doc.id, names: names);
      }
      final hobbies = await _soThich.get();
      final links = await _links.get();
      debugPrint(
        'Đã tách sở thích của $people tài khoản: ${hobbies.docs.length} hobbies, ${links.docs.length} user_hobbies',
      );
    } catch (e, st) {
      _hobbiesSplit = false;
      debugPrint('Tách sở thích lỗi: $e\n$st');
    }
  }

  List<String> _hobbyNames(Map<String, dynamic> data) {
    final raw = data['hobbies'] ?? data['soThich'];
    if (raw is! List) return const [];
    return _uniqueNames(raw.map((item) => '$item').toList());
  }

  Future<List<String>> loadInterestNames(String uid) async {
    final links = await _links.where('nguoiDungId', isEqualTo: uid).get();
    final names = <String>[];
    for (final link in links.docs) {
      final soThichId = link.data()['soThichId']?.toString() ?? '';
      if (soThichId.isEmpty) continue;
      final hobby = await _soThich.doc(soThichId).get();
      final name = hobby.data()?['tenSoThich']?.toString().trim() ?? '';
      if (name.isNotEmpty && !names.any((e) => e.toLowerCase() == name.toLowerCase())) {
        names.add(name);
      }
    }
    return names;
  }

  Future<void> saveProfile({
    required String uid,
    required String displayName,
    required String phoneNumber,
    required String gender,
    required String hometown,
    required String occupation,
    required String workplace,
    required String bio,
    required List<String> interestNames,
    required String role,
    DateTime? birthDate,
    List<int>? avatarBytes,
  }) async {
    String? avatarUrl;
    if (avatarBytes != null && avatarBytes.isNotEmpty) {
      final fileName = '${uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      avatarUrl = await _images.uploadImageBytes(
        bytes: Uint8List.fromList(avatarBytes),
        folder: 'avatars/$uid',
        fileName: fileName,
      );
    }

    final names = _uniqueNames(interestNames);

    final data = <String, dynamic>{
      'displayName': displayName,
      'phoneNumber': phoneNumber,
      'gender': gender,
      'hometown': hometown,
      'occupation': occupation,
      'workplace': workplace,
      'bio': bio,
      'role': role,
      'hoTen': FieldValue.delete(),
      'soDienThoai': FieldValue.delete(),
      'gioiTinh': FieldValue.delete(),
      'queQuan': FieldValue.delete(),
      'ngheNghiep': FieldValue.delete(),
      'noiLamViec': FieldValue.delete(),
      'gioiThieu': FieldValue.delete(),
      'soThich': FieldValue.delete(),
      'vaiTro': FieldValue.delete(),
      'ngaySinh': FieldValue.delete(),
      'anhDaiDien': FieldValue.delete(),
    };
    if (birthDate != null) {
      data['birthDate'] = Timestamp.fromDate(birthDate);
    }
    if (avatarUrl != null) {
      data['avatarUrl'] = avatarUrl;
    }

    try {
      await _users.doc(uid).set(data, SetOptions(merge: true)).timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw Exception('Lưu hồ sơ quá lâu. Kiểm tra mạng rồi thử lại.');
    }

    try {
      await syncInterests(uid: uid, names: names).timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw Exception('Đã lưu thông tin cá nhân, nhưng sở thích chưa kịp đồng bộ. Hãy bấm Lưu thay đổi lần nữa.');
    }

    final authUser = _auth.currentUser;
    if (authUser != null && authUser.uid == uid) {
      try {
        await authUser.updateDisplayName(displayName);
        if (avatarUrl != null && avatarUrl.startsWith('http')) {
          await authUser.updatePhotoURL(avatarUrl);
        }
      } catch (_) {}
    }
  }

  Future<void> syncInterests({
    required String uid,
    required List<String> names,
  }) async {
    final desired = _uniqueNames(names);
    final existing = await _links.where('nguoiDungId', isEqualTo: uid).get();

    final currentIdByName = <String, String>{};
    final linkDocBySoThichId = <String, String>{};
    for (final link in existing.docs) {
      final soThichId = link.data()['soThichId']?.toString() ?? '';
      if (soThichId.isEmpty) continue;
      linkDocBySoThichId[soThichId] = link.id;
      final hobby = await _soThich.doc(soThichId).get();
      final name = hobby.data()?['tenSoThich']?.toString().trim() ?? '';
      if (name.isNotEmpty) currentIdByName[name.toLowerCase()] = soThichId;
    }

    final desiredIds = <String>{};
    var pendingWrites = 0;
    final batch = _firestore.batch();
    for (final name in desired) {
      final knownId = currentIdByName[name.toLowerCase()];
      final soThichId = knownId ?? await _ensureSoThich(name);
      desiredIds.add(soThichId);
      if (!linkDocBySoThichId.containsKey(soThichId)) {
        final linkRef = _links.doc(nguoiDungSoThichDocId(uid, soThichId));
        batch.set(linkRef, {
          'nguoiDungId': uid,
          'soThichId': soThichId,
        });
        pendingWrites++;
      }
    }

    final removeIds = soThichIdsToUnlink(
      currentSoThichIds: linkDocBySoThichId.keys.toSet(),
      desiredSoThichIds: desiredIds,
    );
    for (final soThichId in removeIds) {
      final docId = linkDocBySoThichId[soThichId];
      if (docId != null) {
        batch.delete(_links.doc(docId));
        pendingWrites++;
      }
    }

    if (pendingWrites > 0) {
      await batch.commit();
    }
  }

  Future<String> _ensureSoThich(String name) async {
    final found = await _soThich.where('tenSoThich', isEqualTo: name).limit(1).get();
    if (found.docs.isNotEmpty) return found.docs.first.id;
    final ref = _soThich.doc();
    await ref.set({
      'id': ref.id,
      'tenSoThich': name,
    });
    return ref.id;
  }

  List<String> _uniqueNames(List<String> names) {
    final result = <String>[];
    for (final raw in names) {
      final name = raw.trim();
      if (name.isEmpty) continue;
      if (result.any((e) => e.toLowerCase() == name.toLowerCase())) continue;
      result.add(name);
    }
    return result;
  }
}

final userProfileServiceProvider = Provider<UserProfileService>((ref) {
  return UserProfileService(images: ref.watch(imageStorageServiceProvider));
});
