import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'image_storage_service.dart';

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
/// `hobbies` giữ tên sở thích. `user_hobbies` nối người dùng với sở thích.
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
  CollectionReference<Map<String, dynamic>> get _hobbies => _firestore.collection('hobbies');
  CollectionReference<Map<String, dynamic>> get _links => _firestore.collection('user_hobbies');

  Future<List<String>> loadInterestNames(String uid) async {
    final links = await _links.where('nguoiDungId', isEqualTo: uid).get();
    final names = <String>[];
    for (final link in links.docs) {
      final hobbyId = link.data()['soThichId']?.toString() ?? '';
      if (hobbyId.isEmpty) continue;
      final hobby = await _hobbies.doc(hobbyId).get();
      final name = hobby.data()?['tenSoThich']?.toString().trim() ?? '';
      if (name.isNotEmpty && !names.any((item) => item.toLowerCase() == name.toLowerCase())) {
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
      'hoTen': displayName,
      'phoneNumber': phoneNumber,
      'soDienThoai': phoneNumber,
      'gender': gender,
      'gioiTinh': gender,
      'hometown': hometown,
      'queQuan': hometown,
      'occupation': occupation,
      'ngheNghiep': occupation,
      'workplace': workplace,
      'noiLamViec': workplace,
      'bio': bio,
      'gioiThieu': bio,
      'role': role,
    };
    if (birthDate != null) {
      data['birthDate'] = Timestamp.fromDate(birthDate);
      data['ngaySinh'] = Timestamp.fromDate(birthDate);
    }
    if (avatarUrl != null) {
      data['avatarUrl'] = avatarUrl;
      data['anhDaiDien'] = avatarUrl;
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
    final linkDocByHobbyId = <String, String>{};
    for (final link in existing.docs) {
      final hobbyId = link.data()['soThichId']?.toString() ?? '';
      if (hobbyId.isEmpty) continue;
      linkDocByHobbyId[hobbyId] = link.id;
      final hobby = await _hobbies.doc(hobbyId).get();
      final name = hobby.data()?['tenSoThich']?.toString().trim() ?? '';
      if (name.isNotEmpty) currentIdByName[name.toLowerCase()] = hobbyId;
    }

    final desiredIds = <String>{};
    var pendingWrites = 0;
    final batch = _firestore.batch();
    for (final name in desired) {
      final hobbyId = currentIdByName[name.toLowerCase()] ?? await _ensureHobby(name);
      desiredIds.add(hobbyId);
      if (!linkDocByHobbyId.containsKey(hobbyId)) {
        batch.set(_links.doc(nguoiDungSoThichDocId(uid, hobbyId)), {
          'nguoiDungId': uid,
          'soThichId': hobbyId,
        });
        pendingWrites++;
      }
    }

    final removeIds = soThichIdsToUnlink(
      currentSoThichIds: linkDocByHobbyId.keys.toSet(),
      desiredSoThichIds: desiredIds,
    );
    for (final hobbyId in removeIds) {
      final docId = linkDocByHobbyId[hobbyId];
      if (docId != null) {
        batch.delete(_links.doc(docId));
        pendingWrites++;
      }
    }
    if (pendingWrites > 0) await batch.commit();
  }

  Future<String> _ensureHobby(String name) async {
    final found = await _hobbies.where('tenSoThich', isEqualTo: name).limit(1).get();
    if (found.docs.isNotEmpty) return found.docs.first.id;
    final ref = _hobbies.doc();
    await ref.set({'id': ref.id, 'tenSoThich': name});
    return ref.id;
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
