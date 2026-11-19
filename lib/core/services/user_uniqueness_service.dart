import 'package:cloud_firestore/cloud_firestore.dart';

/// Dịch vụ kiểm tra và đảm bảo tính duy nhất (Uniqueness) cho:
/// 1. Số CCCD (cccdNumber / soCccd / soGiayTo)
/// 2. Số điện thoại (phoneNumber / soDienThoai)
/// 3. Số tài khoản ngân hàng (accountNumber / soTaiKhoan)
///
/// Mỗi tài khoản là độc nhất, không được trùng với tài khoản khác trên toàn hệ thống.
class UserUniquenessService {
  final FirebaseFirestore _firestore;
  static const String claimsCollection = 'user_unique_values';

  UserUniquenessService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Chuẩn hóa số điện thoại: loại bỏ khoảng trắng, dấu gạch nối, dấu chấm
  static String normalizePhone(String raw) {
    return raw.replaceAll(RegExp(r'[\s\.\-\(\)]'), '').trim();
  }

  /// Chuẩn hóa số CCCD: chỉ giữ lại các chữ số
  static String normalizeCccd(String raw) {
    return raw.replaceAll(RegExp(r'\D'), '');
  }

  /// Chuẩn hóa số tài khoản ngân hàng: chỉ giữ chữ cái và số, viết hoa
  static String normalizeBankAccount(String raw) {
    return raw.replaceAll(RegExp(r'[\s\.\-]'), '').trim().toUpperCase();
  }

  Future<void> claimPhoneNumber(String phoneNumber, {required String uid}) {
    final clean = normalizePhone(phoneNumber);
    return _claim(kind: 'phone', normalizedValue: clean, uid: uid);
  }

  Future<void> claimCccd(String cccdNumber, {required String uid}) {
    final clean = normalizeCccd(cccdNumber);
    return _claim(kind: 'cccd', normalizedValue: clean, uid: uid);
  }

  Future<void> claimBankAccount(String accountNumber, {required String uid}) {
    final clean = normalizeBankAccount(accountNumber);
    return _claim(kind: 'bank', normalizedValue: clean, uid: uid);
  }

  Future<void> releasePhoneNumber(String phoneNumber, {required String uid}) {
    return _release(
      kind: 'phone',
      normalizedValue: normalizePhone(phoneNumber),
      uid: uid,
    );
  }

  Future<void> releaseBankAccount(String accountNumber, {required String uid}) {
    return _release(
      kind: 'bank',
      normalizedValue: normalizeBankAccount(accountNumber),
      uid: uid,
    );
  }

  Future<void> _claim({
    required String kind,
    required String normalizedValue,
    required String uid,
  }) async {
    if (normalizedValue.isEmpty || uid.trim().isEmpty) return;
    final ref = _firestore
        .collection(claimsCollection)
        .doc('${kind}_$normalizedValue');
    await _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(ref);
      final ownerUid = '${existing.data()?['ownerUid'] ?? ''}'.trim();
      if (existing.exists && ownerUid.isNotEmpty && ownerUid != uid) {
        throw _conflictMessage(kind);
      }
      transaction.set(
        ref,
        {
          'ownerUid': uid,
          'kind': kind,
          'updatedAt': FieldValue.serverTimestamp(),
          if (!existing.exists) 'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  Future<void> _release({
    required String kind,
    required String normalizedValue,
    required String uid,
  }) async {
    if (normalizedValue.isEmpty || uid.trim().isEmpty) return;
    final ref = _firestore
        .collection(claimsCollection)
        .doc('${kind}_$normalizedValue');
    await _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(ref);
      if (!existing.exists) return;
      final ownerUid = '${existing.data()?['ownerUid'] ?? ''}'.trim();
      if (ownerUid == uid) transaction.delete(ref);
    });
  }

  String _conflictMessage(String kind) {
    switch (kind) {
      case 'phone':
        return 'Số điện thoại này đã được sử dụng bởi một tài khoản khác.';
      case 'cccd':
        return 'Số CCCD này đã được đăng ký/xác thực cho một tài khoản khác.';
      default:
        return 'Số tài khoản ngân hàng này đã được liên kết với một tài khoản khác.';
    }
  }

  /// Kiểm tra số điện thoại đã được tài khoản khác sử dụng chưa.
  /// Nếu trùng với tài khoản khác (khác [excludeUid]), trả về lỗi thông báo.
  Future<String?> checkPhoneNumberUnique(String phoneNumber, {String? excludeUid}) async {
    final clean = normalizePhone(phoneNumber);
    if (clean.isEmpty) return null;
    if (await _claimedByOther('phone', clean, excludeUid: excludeUid)) {
      return 'Số điện thoại này đã được sử dụng bởi một tài khoản khác.';
    }

    final users = _firestore.collection('users');

    for (final field in const [
      'phoneNumberNormalized',
      'phoneNumber',
      'soDienThoai',
    ]) {
      if (await _hasOtherOwner(
        users.where(field, isEqualTo: clean),
        excludeUid: excludeUid,
      )) {
        return 'Số điện thoại này đã được sử dụng bởi một tài khoản khác.';
      }
    }

    return null;
  }

  /// Kiểm tra số CCCD đã được tài khoản khác xác thực chưa.
  Future<String?> checkCccdUnique(String cccdNumber, {String? excludeUid}) async {
    final clean = normalizeCccd(cccdNumber);
    if (clean.isEmpty) return null;
    if (await _claimedByOther('cccd', clean, excludeUid: excludeUid)) {
      return 'Số CCCD này đã được đăng ký/xác thực cho một tài khoản khác.';
    }

    final users = _firestore.collection('users');

    for (final field in const [
      'cccdNumberNormalized',
      'cccdNumber',
      'soCccd',
      'soGiayTo',
    ]) {
      if (await _hasOtherOwner(
        users.where(field, isEqualTo: clean),
        excludeUid: excludeUid,
      )) {
        return 'Số CCCD này đã được đăng ký/xác thực cho một tài khoản khác.';
      }
    }

    return null;
  }

  /// Kiểm tra số tài khoản ngân hàng đã được liên kết với tài khoản khác chưa.
  Future<String?> checkBankAccountUnique(String accountNumber, {String? excludeUid}) async {
    final clean = normalizeBankAccount(accountNumber);
    if (clean.isEmpty) return null;
    if (await _claimedByOther('bank', clean, excludeUid: excludeUid)) {
      return 'Số tài khoản ngân hàng này đã được liên kết với một tài khoản khác.';
    }

    final bankAccounts = _firestore.collection('bank_accounts');

    for (final field in const [
      'accountNumber',
      'soTaiKhoan',
    ]) {
      if (await _hasOtherOwner(
        bankAccounts.where(field, isEqualTo: clean),
        excludeUid: excludeUid,
        ownerFields: const ['userId', 'nguoiDungId', 'hostId'],
      )) {
        return 'Số tài khoản ngân hàng này đã được liên kết với một tài khoản khác.';
      }
    }

    // Dữ liệu cũ và các màn quản trị trước đây có thể lưu STK trong users.
    final users = _firestore.collection('users');
    for (final field in const [
      'accountNumber',
      'bankAccountNumber',
      'hostAccountNumber',
      'renterAccountNumber',
      'soTaiKhoan',
      'stk',
    ]) {
      if (await _hasOtherOwner(
        users.where(field, isEqualTo: clean),
        excludeUid: excludeUid,
      )) {
        return 'Số tài khoản ngân hàng này đã được liên kết với một tài khoản khác.';
      }
    }

    return null;
  }

  Future<bool> _hasOtherOwner(
    Query<Map<String, dynamic>> query, {
    String? excludeUid,
    List<String> ownerFields = const [],
  }) async {
    final snapshot = await query.get();
    for (final doc in snapshot.docs) {
      if (excludeUid == null || excludeUid.isEmpty) return true;
      if (doc.id == excludeUid) continue;
      final data = doc.data();
      final belongsToExcludedUser = ownerFields.any(
        (field) => '${data[field] ?? ''}'.trim() == excludeUid,
      );
      if (!belongsToExcludedUser) return true;
    }
    return false;
  }

  Future<bool> _claimedByOther(
    String kind,
    String normalizedValue, {
    String? excludeUid,
  }) async {
    final claim = await _firestore
        .collection(claimsCollection)
        .doc('${kind}_$normalizedValue')
        .get();
    if (!claim.exists) return false;
    final ownerUid = '${claim.data()?['ownerUid'] ?? ''}'.trim();
    return ownerUid.isNotEmpty && ownerUid != excludeUid;
  }
}
