import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../data/models/violation_rule_model.dart';

/// Dịch vụ quản lý khung phạt và điểm uy tín lưu trữ trên Firebase Firestore
class ViolationRulesService {
  static final ViolationRulesService _instance = ViolationRulesService._internal();
  factory ViolationRulesService() => _instance;
  ViolationRulesService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _rulesDoc =>
      _db.collection('system_configs').doc('violation_rules');

  /// Danh mục 7 khung phạt mặc định chuẩn của HomeShare
  static List<ViolationRuleModel> get defaultRules => [
        const ViolationRuleModel(
          id: 'scam',
          title: 'Lừa đảo / Yêu cầu đặt cọc bất thường',
          description:
              'Yêu cầu chuyển khoản tiền cọc giữ phòng trước khi xem hoặc không có hợp đồng rõ ràng.',
          defaultPoints: 20,
          isActive: true,
        ),
        const ViolationRuleModel(
          id: 'fake_info',
          title: 'Thông tin phòng sai sự thật / Ảnh giả mạo',
          description:
              'Hình ảnh, tiện nghi hoặc địa chỉ thực tế khác xa với bài đăng trên hệ thống.',
          defaultPoints: 15,
          isActive: true,
        ),
        const ViolationRuleModel(
          id: 'harassment',
          title: 'Thái độ khiếm nhã / Quấy rối hoặc đe dọa',
          description:
              'Sử dụng lời lẽ thô tục, xúc phạm, gây phiền hà hoặc đe dọa khách thuê.',
          defaultPoints: 15,
          isActive: true,
        ),
        const ViolationRuleModel(
          id: 'price_mismatch',
          title: 'Giá thuê / Tiền cọc chênh lệch thực tế',
          description:
              'Đăng giá thấp nhưng khi đến thuê ép tăng giá hoặc phát sinh các khoản phí bất hợp lý.',
          defaultPoints: 10,
          isActive: true,
        ),
        const ViolationRuleModel(
          id: 'safety_fire',
          title: 'Không đảm bảo PCCC / Điều kiện vệ sinh tệ',
          description:
              'Phòng trọ ẩm mốc, thiếu lối thoát hiểm hoặc vi phạm an toàn phòng cháy chữa cháy.',
          defaultPoints: 10,
          isActive: true,
        ),
        const ViolationRuleModel(
          id: 'not_removed',
          title: 'Phòng đã cho thuê nhưng không gỡ bài',
          description:
              'Giữ bài đăng ảo khi phòng đã hết để câu khách xem các phòng khác.',
          defaultPoints: 5,
          isActive: true,
        ),
        const ViolationRuleModel(
          id: 'other',
          title: 'Vi phạm quy tắc ứng xử / Điều khoản khác',
          description:
              'Các vi phạm khác ảnh hưởng đến trải nghiệm của cộng đồng HomeShare.',
          defaultPoints: 5,
          isActive: true,
        ),
      ];

  /// Lắng nghe stream danh sách khung phạt theo thời gian thực (realtime)
  Stream<List<ViolationRuleModel>> streamRules() {
    return _rulesDoc.snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) {
        return defaultRules;
      }
      final rawList = snap.data()?['rules'];
      if (rawList is List && rawList.isNotEmpty) {
        return rawList
            .map((e) => ViolationRuleModel.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      return defaultRules;
    });
  }

  /// Lấy danh sách khung phạt hiện hành từ Firestore, tự động khởi tạo nếu chưa có
  Future<List<ViolationRuleModel>> getRules() async {
    try {
      final snap = await _rulesDoc.get();
      if (!snap.exists || snap.data() == null) {
        // Tự động khởi tạo dữ liệu chuẩn lên Firestore lần đầu
        await resetToDefaultRules();
        return defaultRules;
      }
      final rawList = snap.data()?['rules'];
      if (rawList is List && rawList.isNotEmpty) {
        return rawList
            .map((e) => ViolationRuleModel.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      // Nếu danh sách rỗng, khởi tạo lại
      await resetToDefaultRules();
      return defaultRules;
    } catch (e) {
      debugPrint('Lỗi đọc violation_rules từ Firestore: $e');
      return defaultRules;
    }
  }

  /// Lưu toàn bộ danh sách quy định lên Firestore
  Future<void> saveRules(List<ViolationRuleModel> rules, {String? updatedBy}) async {
    final listData = rules.map((r) => r.toMap()).toList();
    await _rulesDoc.set({
      'rules': listData,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': updatedBy ?? 'Admin',
    }, SetOptions(merge: true));
  }

  /// Thêm hoặc cập nhật một lỗi vi phạm cụ thể
  Future<void> addOrUpdateRule(ViolationRuleModel rule, {String? updatedBy}) async {
    final currentRules = await getRules();
    final index = currentRules.indexWhere((r) => r.id == rule.id);
    if (index >= 0) {
      currentRules[index] = rule;
    } else {
      currentRules.add(rule);
    }
    await saveRules(currentRules, updatedBy: updatedBy);
  }

  /// Xóa hoặc ẩn một lỗi vi phạm
  Future<void> deleteRule(String ruleId, {String? updatedBy}) async {
    final currentRules = await getRules();
    currentRules.removeWhere((r) => r.id == ruleId);
    await saveRules(currentRules, updatedBy: updatedBy);
  }

  /// Cập nhật nhanh số điểm phạt của một lỗi
  Future<void> updateRulePoints(String ruleId, int newPoints, {String? updatedBy}) async {
    final currentRules = await getRules();
    final index = currentRules.indexWhere((r) => r.id == ruleId);
    if (index >= 0) {
      currentRules[index] = currentRules[index].copyWith(defaultPoints: newPoints);
      await saveRules(currentRules, updatedBy: updatedBy);
    }
  }

  /// Khôi phục về bộ 7 quy định chuẩn mặc định
  Future<void> resetToDefaultRules({String? updatedBy}) async {
    await saveRules(defaultRules, updatedBy: updatedBy ?? 'System');
  }
}
