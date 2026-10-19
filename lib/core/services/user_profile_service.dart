import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/firestore_collections.dart';
import '../../features/auth/providers/user_provider.dart';
import 'image_storage_service.dart';

/// Một tài khoản ngân hàng của một người dùng. Chưa có dữ liệu thì các trường để trống.
class BankAccount {
  const BankAccount({
    this.id = '',
    this.userId = '',
    this.accountNumber = '',
    this.accountHolder = '',
    this.bankName = '',
  });

  final String id;
  final String userId;
  final String accountNumber;
  final String accountHolder;
  final String bankName;

  factory BankAccount.fromMap(Map<String, dynamic> data, String docId) {
    return BankAccount(
      id: '${data['id'] ?? docId}'.trim(),
      userId: '${data['userId'] ?? data['nguoiDungId'] ?? ''}'.trim(),
      accountNumber: '${data['accountNumber'] ?? data['soTaiKhoan'] ?? ''}'.trim(),
      accountHolder: '${data['accountHolder'] ?? data['chuTaiKhoan'] ?? ''}'.trim(),
      bankName: '${data['bankName'] ?? data['tenNganHang'] ?? ''}'.trim(),
    );
  }
}

/// Id tài liệu bảng nối người dùng và sở thích.
String nguoiDungSoThichDocId(String nguoiDungId, String soThichId) {
  return '${nguoiDungId}__$soThichId';
}

/// Sở thích đang có mà người dùng bỏ chọn. Chỉ gỡ liên kết, không xóa danh mục.
Set<String> soThichIdsToUnlink({
  required Set<String> currentSoThichIds,
  required Set<String> desiredSoThichIds,
}) {
  return currentSoThichIds.difference(desiredSoThichIds);
}

/// Lưu hồ sơ một tài khoản và sở thích theo quan hệ nhiều-nhiều.
///
/// `hobbies` lưu `name`. `user_hobbies` nối bằng `userId` và `hobbyId`.
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
  static bool _hobbyCatalogMigrated = false;

  CollectionReference<Map<String, dynamic>> get _users => _firestore.collection('users');
  CollectionReference<Map<String, dynamic>> get _hobbies => _firestore.collection('hobbies');
  CollectionReference<Map<String, dynamic>> get _links => _firestore.collection('user_hobbies');
  CollectionReference<Map<String, dynamic>> get _bankAccounts =>
      _firestore.collection(FirestoreCollections.bankAccounts);

  Future<UserProfile?> loadUser(String uid) async {
    final id = uid.trim();
    if (id.isEmpty) return null;
    final doc = await _users.doc(id).get();
    if (!doc.exists) return null;
    return attachStorageAvatar(UserProfile.fromMap(doc.data() ?? {}, doc.id));
  }

  /// Link ảnh chỉ dùng trên màn hình. File nằm ở Storage `avatars/{uid}/avatar.jpg`.
  Future<UserProfile> attachStorageAvatar(UserProfile profile) async {
    final url = await _images.avatarDownloadUrl(profile.uid);
    if (url == null) return profile;
    return profile.copyWith(avatarUrl: url);
  }

  Future<List<String>> loadInterestNames(String uid) async {
    final byUser = await loadInterestNamesForUsers([uid]);
    return byUser[uid] ?? const [];
  }

  /// Đọc sở thích của nhiều người. Tài liệu cũ còn trường tiếng Việt được ghi lại bằng tên tiếng Anh.
  Future<Map<String, List<String>>> loadInterestNamesForUsers(Iterable<String> uids) async {
    await _migrateHobbyCatalog();
    final ids = uids.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet().toList();
    final names = <String, List<String>>{};
    for (var start = 0; start < ids.length; start += 10) {
      final end = start + 10 > ids.length ? ids.length : start + 10;
      final chunk = ids.sublist(start, end);
      final docs = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
      final current = await _links.where('userId', whereIn: chunk).get();
      final legacy = await _links.where('nguoiDungId', whereIn: chunk).get();
      for (final doc in [...current.docs, ...legacy.docs]) {
        docs[doc.id] = doc;
      }
      for (final link in docs.values) {
        final data = link.data();
        final uid = _linkUserId(data);
        final hobbyId = _linkHobbyId(data);
        if (uid.isEmpty || hobbyId.isEmpty) continue;
        await _useEnglishLinkFields(link);
        final hobby = await _hobbies.doc(hobbyId).get();
        await _useEnglishHobbyFields(hobby);
        final name = _hobbyName(hobby.data());
        if (name.isEmpty) continue;
        final list = names.putIfAbsent(uid, () => []);
        if (!list.any((item) => item.toLowerCase() == name.toLowerCase())) list.add(name);
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
    String accountNumber = '',
    String accountHolder = '',
    String bankName = '',
    bool updateBankAccount = true,
  }) async {
    var uploadedAvatar = false;
    if (avatarBytes != null && avatarBytes.isNotEmpty) {
      await _images.uploadImageBytes(
        bytes: Uint8List.fromList(avatarBytes),
        folder: 'avatars/$uid',
        fileName: 'avatar.jpg',
      );
      uploadedAvatar = true;
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
      'ngaySinh': FieldValue.delete(),
      'vaiTro': FieldValue.delete(),
      'vaiTro_id': FieldValue.delete(),
    };
    if (birthDate != null) {
      data['birthDate'] = Timestamp.fromDate(birthDate);
    } else {
      data['birthDate'] = FieldValue.delete();
    }
    if (uploadedAvatar) {
      data['avatarUrl'] = FieldValue.delete();
      data['anhDaiDien'] = FieldValue.delete();
    }

    try {
      await _users.doc(uid).set(data, SetOptions(merge: true)).timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw Exception('Lưu hồ sơ quá lâu. Kiểm tra mạng rồi thử lại.');
    }

    try {
      await Future.wait([
        syncInterests(uid: uid, names: names),
        if (updateBankAccount)
          saveBankAccount(
            uid: uid,
            accountNumber: accountNumber,
            accountHolder: accountHolder,
            bankName: bankName,
          ),
      ]).timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw Exception('Đã lưu thông tin cá nhân, nhưng sở thích hoặc tài khoản ngân hàng chưa kịp đồng bộ. Hãy bấm Lưu thay đổi lần nữa.');
    }

    final authUser = _auth.currentUser;
    if (authUser != null && authUser.uid == uid) {
      try {
        await authUser.updateDisplayName(displayName);
      } catch (_) {}
    }
  }

  /// Đọc tài khoản ngân hàng theo mã người dùng. Không có bản ghi thì trả về trường trống.
  Future<BankAccount> loadBankAccount(String uid) async {
    final id = uid.trim();
    if (id.isEmpty) return const BankAccount();
    final doc = await _bankAccounts.doc(id).get();
    if (!doc.exists) return BankAccount(id: id, userId: id);
    return BankAccount.fromMap(doc.data() ?? {}, doc.id);
  }

  /// Mỗi người một bản ghi, mã tài liệu trùng mã người dùng.
  /// Cả ba trường trống thì xóa bản ghi nếu đã có, không tạo bản ghi rỗng.
  Future<void> saveBankAccount({
    required String uid,
    required String accountNumber,
    required String accountHolder,
    required String bankName,
  }) async {
    final id = uid.trim();
    if (id.isEmpty) return;
    final number = accountNumber.trim();
    final holder = accountHolder.trim();
    final bank = bankName.trim();
    final ref = _bankAccounts.doc(id);
    if (number.isEmpty && holder.isEmpty && bank.isEmpty) {
      final existing = await ref.get();
      if (existing.exists) await ref.delete();
      return;
    }
    await ref.set({
      'id': id,
      'userId': id,
      'accountNumber': number,
      'accountHolder': holder,
      'bankName': bank,
      'nguoiDungId': FieldValue.delete(),
      'soTaiKhoan': FieldValue.delete(),
      'chuTaiKhoan': FieldValue.delete(),
      'tenNganHang': FieldValue.delete(),
    }, SetOptions(merge: true));
  }

  Future<void> syncInterests({
    required String uid,
    required List<String> names,
  }) async {
    final desired = _uniqueNames(names);
    final linkSnaps = await Future.wait([
      _links.where('userId', isEqualTo: uid).get(),
      _links.where('nguoiDungId', isEqualTo: uid).get(),
    ]);
    final existing = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final snap in linkSnaps) {
      for (final link in snap.docs) {
        existing[link.id] = link;
      }
    }

    final linkDocByHobbyId = <String, String>{};
    for (final link in existing.values) {
      final hobbyId = _linkHobbyId(link.data());
      if (hobbyId.isEmpty) continue;
      linkDocByHobbyId[hobbyId] = link.id;
    }

    final hobbyDocs = await _docsByIds(_hobbies, linkDocByHobbyId.keys.toList());
    final currentIdByName = <String, String>{};
    for (final hobby in hobbyDocs) {
      final name = _hobbyName(hobby.data());
      if (name.isNotEmpty) currentIdByName[name.toLowerCase()] = hobby.id;
    }

    final missing = desired.where((name) => !currentIdByName.containsKey(name.toLowerCase())).toList();
    final byEnglishName = await _hobbiesByField('name', missing);
    for (final entry in byEnglishName.entries) {
      currentIdByName[entry.key.toLowerCase()] = entry.value.id;
    }
    final stillMissing = missing.where((name) => !currentIdByName.containsKey(name.toLowerCase())).toList();
    final byLegacyName = await _hobbiesByField('tenSoThich', stillMissing);
    for (final entry in byLegacyName.entries) {
      currentIdByName[entry.key.toLowerCase()] = entry.value.id;
    }

    final batch = _firestore.batch();
    var pendingWrites = 0;
    void touch() => pendingWrites++;

    for (final hobby in [...hobbyDocs, ...byLegacyName.values]) {
      final data = hobby.data();
      if (data == null || !data.containsKey('tenSoThich')) continue;
      final name = _hobbyName(data);
      if (name.isEmpty) continue;
      batch.set(hobby.reference, {
        'id': hobby.id,
        'name': name,
        'tenSoThich': FieldValue.delete(),
      }, SetOptions(merge: true));
      touch();
    }
    for (final link in existing.values) {
      final data = link.data();
      if (!data.containsKey('nguoiDungId') && !data.containsKey('soThichId')) continue;
      final userId = _linkUserId(data);
      final hobbyId = _linkHobbyId(data);
      batch.set(link.reference, {
        if (userId.isNotEmpty) 'userId': userId,
        if (hobbyId.isNotEmpty) 'hobbyId': hobbyId,
        'nguoiDungId': FieldValue.delete(),
        'soThichId': FieldValue.delete(),
      }, SetOptions(merge: true));
      touch();
    }

    final desiredIds = <String>{};
    for (final name in desired) {
      final key = name.toLowerCase();
      var hobbyId = currentIdByName[key];
      if (hobbyId == null) {
        final ref = _hobbies.doc();
        hobbyId = ref.id;
        batch.set(ref, {'id': hobbyId, 'name': name});
        currentIdByName[key] = hobbyId;
        touch();
      }
      desiredIds.add(hobbyId);
      if (!linkDocByHobbyId.containsKey(hobbyId)) {
        batch.set(_links.doc(nguoiDungSoThichDocId(uid, hobbyId)), {
          'userId': uid,
          'hobbyId': hobbyId,
        });
        touch();
      }
    }

    final removeIds = soThichIdsToUnlink(
      currentSoThichIds: linkDocByHobbyId.keys.toSet(),
      desiredSoThichIds: desiredIds,
    );
    for (final hobbyId in removeIds) {
      final docId = linkDocByHobbyId[hobbyId];
      if (docId == null) continue;
      batch.delete(_links.doc(docId));
      touch();
    }
    if (pendingWrites > 0) await batch.commit();
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _docsByIds(
    CollectionReference<Map<String, dynamic>> collection,
    List<String> ids,
  ) async {
    if (ids.isEmpty) return [];
    final snaps = await Future.wait(_chunks(ids, 10).map(
      (chunk) => collection.where(FieldPath.documentId, whereIn: chunk).get(),
    ));
    return snaps.expand((snap) => snap.docs).toList();
  }

  Future<Map<String, QueryDocumentSnapshot<Map<String, dynamic>>>> _hobbiesByField(
    String field,
    List<String> names,
  ) async {
    final unique = _uniqueNames(names);
    if (unique.isEmpty) return {};
    final snaps = await Future.wait(_chunks(unique, 10).map(
      (chunk) => _hobbies.where(field, whereIn: chunk).get(),
    ));
    final found = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final snap in snaps) {
      for (final doc in snap.docs) {
        final name = _hobbyName(doc.data());
        if (name.isNotEmpty) found[name] = doc;
      }
    }
    return found;
  }

  List<List<String>> _chunks(List<String> values, int size) {
    final chunks = <List<String>>[];
    for (var start = 0; start < values.length; start += size) {
      final end = start + size > values.length ? values.length : start + size;
      chunks.add(values.sublist(start, end));
    }
    return chunks;
  }

  String _hobbyName(Map<String, dynamic>? data) {
    return '${data?['name'] ?? data?['tenSoThich'] ?? ''}'.trim();
  }

  String _linkUserId(Map<String, dynamic> data) {
    return '${data['userId'] ?? data['nguoiDungId'] ?? ''}'.trim();
  }

  String _linkHobbyId(Map<String, dynamic> data) {
    return '${data['hobbyId'] ?? data['soThichId'] ?? ''}'.trim();
  }

  Future<void> _migrateHobbyCatalog() async {
    if (_hobbyCatalogMigrated) return;
    final snap = await _hobbies.get();
    for (final doc in snap.docs) {
      await _useEnglishHobbyFields(doc);
    }
    _hobbyCatalogMigrated = true;
  }

  Future<void> _useEnglishHobbyFields(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data();
    if (data == null || !data.containsKey('tenSoThich')) return;
    final name = _hobbyName(data);
    if (name.isEmpty) return;
    try {
      await doc.reference.set({
        'id': doc.id,
        'name': name,
        'tenSoThich': FieldValue.delete(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Đổi tên trường hobbies/${doc.id}: $e');
    }
  }

  Future<void> _useEnglishLinkFields(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data();
    if (!data.containsKey('nguoiDungId') && !data.containsKey('soThichId')) return;
    final userId = _linkUserId(data);
    final hobbyId = _linkHobbyId(data);
    try {
      await doc.reference.set({
        if (userId.isNotEmpty) 'userId': userId,
        if (hobbyId.isNotEmpty) 'hobbyId': hobbyId,
        'nguoiDungId': FieldValue.delete(),
        'soThichId': FieldValue.delete(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Đổi tên trường user_hobbies/${doc.id}: $e');
    }
  }

  List<String> _uniqueNames(List<String> names) {
    final result = <String>[];
    for (final raw in names) {
      final name = raw.trim();
      if (name.isEmpty) continue;
      if (result.any((item) => item.toLowerCase() == name.toLowerCase())) continue;
      result.add(name);
    }
    return result;
  }
}

final userProfileServiceProvider = Provider<UserProfileService>((ref) {
  return UserProfileService(images: ref.watch(imageStorageServiceProvider));
});
