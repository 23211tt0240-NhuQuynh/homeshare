import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/user_provider.dart';
import '../models/cccd_validation_models.dart';
import '../services/cccd_image_evidence_extractor.dart';
import '../services/cccd_image_evidence_validator.dart';
import 'cccd_scanner_screen.dart';

/// Trạng thái thẩm định ảnh thẻ CCCD on-device qua Google ML Kit
enum CccdSideValidationStatus {
  idle,
  validating,
  valid,
  invalid,
}

/// Màn hình Xác thực CCCD (eKYC) với 3 mục bắt buộc:
/// 1. Ảnh mặt trước CCCD (quét OCR qua Google ML Kit, đối soát dấu hiệu & QR)
/// 2. Ảnh mặt sau CCCD (quét OCR qua Google ML Kit, kiểm tra chip, phôi BCA, MRZ)
/// 3. Quét lấy thông tin từ mã QR CCCD
/// Nút xác thực chỉ được kích hoạt khi cả 3 mục đều hợp lệ.
class CccdVerificationScreen extends ConsumerStatefulWidget {
  const CccdVerificationScreen({super.key});

  @override
  ConsumerState<CccdVerificationScreen> createState() => _CccdVerificationScreenState();
}

class _CccdVerificationScreenState extends ConsumerState<CccdVerificationScreen> {
  final ImagePicker _picker = ImagePicker();
  final CccdImageEvidenceExtractor _extractor = const CccdImageEvidenceExtractor();
  final CccdImageEvidenceValidator _validator = const CccdImageEvidenceValidator();

  XFile? _frontImage;
  CccdSideValidationStatus _frontStatus = CccdSideValidationStatus.idle;
  String? _frontMessage;
  CccdImageEvidence? _frontEvidence;

  XFile? _backImage;
  CccdSideValidationStatus _backStatus = CccdSideValidationStatus.idle;
  String? _backMessage;
  CccdImageEvidence? _backEvidence;

  CccdData? _cccdData;
  String? _qrRawPayload;
  bool _isSubmitting = false;

  static const String _kDraftFront = 'draft_cccd_front_image';
  static const String _kDraftBack = 'draft_cccd_back_image';
  static const String _kDraftData = 'draft_cccd_data_json';
  static const String _kDraftQr = 'draft_cccd_qr_payload';

  @override
  void initState() {
    super.initState();
    _loadDraft();
  }

  Future<void> _loadDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final frontPath = prefs.getString(_kDraftFront);
      final backPath = prefs.getString(_kDraftBack);
      final cccdJson = prefs.getString(_kDraftData);
      final qrPayload = prefs.getString(_kDraftQr);

      bool hasUpdate = false;

      if (frontPath != null && frontPath.isNotEmpty && File(frontPath).existsSync()) {
        _frontImage = XFile(frontPath);
        _frontStatus = CccdSideValidationStatus.valid;
        _frontMessage = 'Đã khôi phục ảnh mặt trước đã chụp ✓';
        hasUpdate = true;
      }

      if (backPath != null && backPath.isNotEmpty && File(backPath).existsSync()) {
        _backImage = XFile(backPath);
        _backStatus = CccdSideValidationStatus.valid;
        _backMessage = 'Đã khôi phục ảnh mặt sau đã chụp ✓';
        hasUpdate = true;
      }

      if (cccdJson != null && cccdJson.isNotEmpty) {
        try {
          final map = jsonDecode(cccdJson) as Map<String, dynamic>;
          _cccdData = CccdData.fromMap(map);
          _qrRawPayload = qrPayload;
          hasUpdate = true;
        } catch (_) {}
      }

      if (hasUpdate && mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Lỗi tải draft CCCD: $e');
    }
  }

  Future<void> _saveDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_frontImage != null && _frontStatus == CccdSideValidationStatus.valid) {
        await prefs.setString(_kDraftFront, _frontImage!.path);
      } else {
        await prefs.remove(_kDraftFront);
      }

      if (_backImage != null && _backStatus == CccdSideValidationStatus.valid) {
        await prefs.setString(_kDraftBack, _backImage!.path);
      } else {
        await prefs.remove(_kDraftBack);
      }

      if (_cccdData != null) {
        await prefs.setString(_kDraftData, jsonEncode(_cccdData!.toMap()));
        if (_qrRawPayload != null) {
          await prefs.setString(_kDraftQr, _qrRawPayload!);
        }
      } else {
        await prefs.remove(_kDraftData);
        await prefs.remove(_kDraftQr);
      }
    } catch (e) {
      debugPrint('Lỗi lưu draft CCCD: $e');
    }
  }

  Future<void> _clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kDraftFront);
      await prefs.remove(_kDraftBack);
      await prefs.remove(_kDraftData);
      await prefs.remove(_kDraftQr);
    } catch (_) {}
  }

  bool get _hasQrData => _cccdData != null;

  bool get _isComplete =>
      _frontImage != null &&
      _frontStatus == CccdSideValidationStatus.valid &&
      _backImage != null &&
      _backStatus == CccdSideValidationStatus.valid &&
      _hasQrData;

  bool get _canSubmit => _isComplete;

  int get _completedCount {
    int count = 0;
    if (_frontImage != null && _frontStatus == CccdSideValidationStatus.valid) count++;
    if (_backImage != null && _backStatus == CccdSideValidationStatus.valid) count++;
    if (_cccdData != null) count++;
    return count;
  }

  List<String> get _missingItems {
    final list = <String>[];
    if (_frontImage == null || _frontStatus != CccdSideValidationStatus.valid) {
      list.add('Ảnh mặt trước hợp lệ');
    }
    if (_backImage == null || _backStatus != CccdSideValidationStatus.valid) {
      list.add('Ảnh mặt sau hợp lệ');
    }
    if (_cccdData == null) {
      list.add('Quét mã QR');
    }
    return list;
  }

  /// Chụp hoặc chọn ảnh mặt trước/sau
  Future<void> _pickImage(bool isFront, ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 92,
        maxWidth: 1920,
      );
      if (picked != null) {
        await _processAndValidateImage(isFront: isFront, pickedFile: picked);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể truy cập camera hoặc thư viện: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  /// Xử lý quét chữ bằng Google ML Kit on-device và thẩm định thẻ CCCD
  Future<void> _processAndValidateImage({
    required bool isFront,
    required XFile pickedFile,
  }) async {
    setState(() {
      if (isFront) {
        _frontImage = pickedFile;
        _frontStatus = CccdSideValidationStatus.validating;
        _frontMessage = 'Đang dùng Google ML Kit nhận diện chữ và thẩm định ảnh mặt trước...';
        _frontEvidence = null;
      } else {
        _backImage = pickedFile;
        _backStatus = CccdSideValidationStatus.validating;
        _backMessage = 'Đang dùng Google ML Kit nhận diện chữ và thẩm định ảnh mặt sau...';
        _backEvidence = null;
      }
    });

    try {
      final side = isFront ? CccdImageSide.front : CccdImageSide.back;
      final resultBundle = await _extractor.extractAndValidate(
        filePath: pickedFile.path,
        side: side,
        explicitQrPayload: isFront ? _qrRawPayload : null,
      );

      final evidence = resultBundle.evidence;
      final valResult = resultBundle.result;

      if (!mounted) return;

      // 1. Kiểm tra trùng lặp ảnh với mặt đối diện
      if (evidence != null) {
        final otherEvidence = isFront ? _backEvidence : _frontEvidence;
        if (otherEvidence != null && evidence.imageByteHash == otherEvidence.imageByteHash) {
          setState(() {
            if (isFront) {
              _frontStatus = CccdSideValidationStatus.invalid;
              _frontMessage = 'Cảnh báo: Ảnh mặt trước bị trùng với ảnh mặt sau! Vui lòng chụp 2 mặt khác nhau.';
              _frontEvidence = evidence;
            } else {
              _backStatus = CccdSideValidationStatus.invalid;
              _backMessage = 'Cảnh báo: Ảnh mặt sau bị trùng với ảnh mặt trước! Vui lòng chụp 2 mặt khác nhau.';
              _backEvidence = evidence;
            }
          });
          return;
        }
      }

      // 2. Phân tích kết quả theo từng mặt
      if (isFront) {
        if (valResult.isValid) {
          setState(() {
            _frontStatus = CccdSideValidationStatus.valid;
            _frontEvidence = evidence;
            _frontMessage = 'Hợp lệ: Đã nhận diện đúng thẻ Căn cước công dân mặt trước ✓';
            if (valResult.strictData != null) {
              _cccdData = valResult.strictData;
              _qrRawPayload = evidence?.qrPayload;
            }
          });
        } else {
          final String warning;
          final norm = evidence != null ? evidence.normalizedOcrText.toUpperCase() : '';
          final hasCccdMarker = norm.contains('CAN CUOC') || norm.contains('CĂN CƯỚC');

          if (valResult.reasonCode == CccdValidationReasonCodes.wrongSideDetected) {
            warning = 'Cảnh báo: Ảnh bạn chọn là MẶT SAU của thẻ CCCD! Vui lòng chọn đúng MẶT TRƯỚC (có ảnh chân dung, Quốc huy).';
          } else if (valResult.reasonCode == CccdValidationReasonCodes.resolutionTooLow ||
              valResult.reasonCode == CccdValidationReasonCodes.imageTooSmall) {
            warning = 'Cảnh báo: Ảnh bị mờ hoặc độ phân giải quá thấp, không đọc được chữ. Vui lòng chụp lại rõ nét hơn!';
          } else if (valResult.reasonCode == CccdValidationReasonCodes.frontMarkersMissing) {
            warning = 'Cảnh báo: Không nhận diện được thẻ Căn cước công dân! Ảnh có thể bị mờ, lóa sáng hoặc không phải thẻ CCCD. Vui lòng chụp lại rõ nét.';
          } else if (valResult.reasonCode == CccdValidationReasonCodes.qrMissingOrInvalid ||
              valResult.reasonCode == CccdValidationReasonCodes.qrMissingRequiredFields) {
            if (hasCccdMarker) {
              setState(() {
                _frontStatus = CccdSideValidationStatus.valid;
                _frontEvidence = evidence;
                _frontMessage = 'Hợp lệ: Đã nhận diện thẻ CCCD mặt trước ✓ (Vui lòng hoàn tất quét mã QR ở mục 3).';
              });
              return;
            } else {
              warning = 'Cảnh báo: Không thể nhận diện thẻ CCCD hoặc mã QR. Ảnh bị mờ, chụp nghiêng hoặc lóa sáng. Vui lòng chụp lại!';
            }
          } else {
            warning = 'Cảnh báo: Ảnh không hợp lệ hoặc không phải thẻ Căn cước công dân. Vui lòng chụp lại thẻ thật rõ ràng.';
          }

          setState(() {
            _frontStatus = CccdSideValidationStatus.invalid;
            _frontEvidence = evidence;
            _frontMessage = warning;
          });
        }
      } else {
        // Mặt sau
        if (valResult.isValid) {
          setState(() {
            _backStatus = CccdSideValidationStatus.valid;
            _backEvidence = evidence;
            _backMessage = 'Hợp lệ: Đã nhận diện đúng thẻ CCCD mặt sau (có chip điện tử / phôi Bộ Công An) ✓';
          });
        } else {
          final String warning;
          if (valResult.reasonCode == CccdValidationReasonCodes.wrongSideDetected) {
            warning = 'Cảnh báo: Ảnh bạn chọn là MẶT TRƯỚC của thẻ CCCD! Vui lòng chọn đúng MẶT SAU (có chip điện tử, mã MRZ).';
          } else if (valResult.reasonCode == CccdValidationReasonCodes.resolutionTooLow ||
              valResult.reasonCode == CccdValidationReasonCodes.imageTooSmall) {
            warning = 'Cảnh báo: Ảnh mặt sau bị mờ hoặc độ phân giải quá thấp. Vui lòng chụp lại rõ nét hơn!';
          } else if (valResult.reasonCode == CccdValidationReasonCodes.backMarkersInsufficient) {
            warning = 'Cảnh báo: Không nhận diện được mặt sau CCCD! Ảnh bị mờ, lóa hoặc không thấy chip điện tử / phôi Bộ Công An. Vui lòng chụp lại.';
          } else {
            warning = 'Cảnh báo: Ảnh không hợp lệ hoặc không phải mặt sau thẻ CCCD. Vui lòng chụp lại!';
          }

          setState(() {
            _backStatus = CccdSideValidationStatus.invalid;
            _backEvidence = evidence;
            _backMessage = warning;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          if (isFront) {
            _frontStatus = CccdSideValidationStatus.invalid;
            _frontMessage = 'Cảnh báo: Không thể đọc được ảnh. Vui lòng kiểm tra lại chất lượng ảnh chụp!';
          } else {
            _backStatus = CccdSideValidationStatus.invalid;
            _backMessage = 'Cảnh báo: Không thể đọc được ảnh. Vui lòng kiểm tra lại chất lượng ảnh chụp!';
          }
        });
      }
    }

    if (mounted) {
      await _saveDraft();
    }
  }

  /// Hiển thị BottomSheet chọn nguồn ảnh
  void _showImagePickerModal(bool isFront) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                isFront ? 'CHỤP / CHỌN ẢNH MẶT TRƯỚC CCCD' : 'CHỤP / CHỌN ẢNH MẶT SAU CCCD',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isFront
                    ? 'Yêu cầu: Rõ nét họ tên, số CCCD, chân dung, không bị lóa hoặc che khuất'
                    : 'Yêu cầu: Rõ nét chip điện tử, mã MRZ và thông tin Bộ Công An',
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.primaryContainer,
                  child: Icon(Icons.camera_alt, color: AppColors.primary),
                ),
                title: const Text('Chụp ảnh trực tiếp từ Camera', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Mở máy ảnh chụp trực tiếp thẻ thật'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(isFront, ImageSource.camera);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.primaryContainer,
                  child: Icon(Icons.photo_library, color: AppColors.primary),
                ),
                title: const Text('Chọn ảnh từ Thư viện (Bộ sưu tập)', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Chọn ảnh thẻ đã chụp sẵn trên máy'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(isFront, ImageSource.gallery);
                },
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield_outlined, size: 16, color: AppColors.primary),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Google ML Kit on-device sẽ tự động phân tích và thẩm định thẻ CCCD ngay khi chọn ảnh.',
                        style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Mở màn hình quét mã QR thẻ CCCD
  Future<void> _scanCccdQr() async {
    final result = await Navigator.push<CccdData>(
      context,
      MaterialPageRoute(
        builder: (_) => const CccdScannerScreen(returnDataOnly: true),
      ),
    );

    if (result != null && mounted) {
      final rawPayload = _reconstructQrPayload(result);
      setState(() {
        _cccdData = result;
        _qrRawPayload = rawPayload;
        if (_frontEvidence != null) {
          _frontEvidence = _frontEvidence!.copyWith(qrPayload: rawPayload);
        }
      });

      // Nếu mặt trước đã chọn trước đó, chạy lại kiểm định với mã QR vừa quét
      if (_frontImage != null && _frontStatus != CccdSideValidationStatus.valid) {
        await _processAndValidateImage(isFront: true, pickedFile: _frontImage!);
      }

      await _saveDraft();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã trích xuất thông tin: ${result.fullName} (${result.idNumber}) ✓'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    }
  }

  String _reconstructQrPayload(CccdData cccd) {
    String stripSlash(String d) => d.replaceAll('/', '');
    return '${cccd.idNumber}|${cccd.oldCmnd}|${cccd.fullName}|${stripSlash(cccd.birthDate)}|${cccd.gender}|${cccd.address}|${stripSlash(cccd.issueDate)}';
  }

  /// Nhấn nút Xác thực và lưu toàn bộ thông tin
  Future<void> _submitVerification() async {
    if (!_canSubmit || _isSubmitting) return;

    final effectiveFront = _frontEvidence != null
        ? ((_frontEvidence!.qrPayload == null || _frontEvidence!.qrPayload!.isEmpty)
            ? _frontEvidence!.copyWith(
                qrPayload: _qrRawPayload ??
                    (_cccdData != null ? _reconstructQrPayload(_cccdData!) : null))
            : _frontEvidence!)
        : null;

    if (effectiveFront != null && _backEvidence != null && _cccdData != null) {
      final proof = _validator.createProof(
        frontEvidence: effectiveFront,
        backEvidence: _backEvidence!,
        explicitVerifiedData: _cccdData,
      );
      if (!_validator.canSave(proof)) {
        if (mounted) {
          String reasonMessage =
              'Bằng chứng xác thực chưa đạt tiêu chuẩn an toàn để lưu. Vui lòng kiểm tra lại ảnh!';
          if (proof.isDemo) {
            reasonMessage = 'Không thể dùng ảnh mẫu demo để xác thực tài khoản thật.';
          } else if (proof.rejectionReasonCode ==
              CccdValidationReasonCodes.duplicateImageHash) {
            reasonMessage =
                'Cảnh báo: Ảnh mặt trước và mặt sau bị trùng nhau! Vui lòng chụp 2 mặt khác nhau.';
          } else if (proof.rejectionReasonCode ==
              CccdValidationReasonCodes.wrongSideDetected) {
            reasonMessage =
                'Ảnh chụp bị đảo ngược thứ tự mặt trước và mặt sau. Vui lòng kiểm tra lại!';
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(reasonMessage),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    setState(() => _isSubmitting = true);

    try {
      final user = ref.read(currentUserProvider);
      final uid = (user?.uid != null && user!.uid.isNotEmpty)
          ? user.uid
          : (FirebaseAuth.instance.currentUser?.uid ?? 'guest_uid');

      DateTime? parsedBirth;
      try {
        final parts = _cccdData!.birthDate.split('/');
        if (parts.length == 3) {
          parsedBirth = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
        }
      } catch (_) {}

      final role = ref.read(userProfileProvider).value?.role ?? 'renter';
      final isHost = role == 'host' || role == 'landlord' || role == 'chutro';

      await submitCccdVerificationRequest(
        uid: uid,
        cccdNumber: _cccdData!.idNumber,
        cccdFullName: _cccdData!.fullName,
        cccdIssueDate: _cccdData!.issueDate,
        cccdHometown: _cccdData!.address,
        gender: _cccdData!.gender,
        birthDate: parsedBirth,
        frontImagePath: _frontImage?.path ?? '',
        backImagePath: _backImage?.path ?? '',
        role: role,
      );

      await _clearDraft();
      ref.invalidate(userProfileProvider);

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.hourglass_top_rounded, color: Color(0xFFD97706), size: 28),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Đã Gửi Hồ Sơ Xác Thực!',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Hồ sơ của bạn đã được gửi sang Quản trị viên xem xét, đang chờ xác thực tài khoản:',
                  style: TextStyle(fontSize: 13.5, height: 1.4),
                ),
                const SizedBox(height: 12),
                if (_frontImage != null)
                  const Text('✓ Ảnh mặt trước thẻ CCCD (lưu trữ Storage an toàn)',
                      style: TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.w600, fontSize: 12.5)),
                if (_backImage != null)
                  const Text('✓ Ảnh mặt sau thẻ CCCD (lưu trữ Storage an toàn)',
                      style: TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.w600, fontSize: 12.5)),
                Text('✓ Dữ liệu trích xuất từ QR: ${_cccdData!.fullName} - ${_cccdData!.idNumber}',
                    style: const TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.w600, fontSize: 12.5)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, size: 18, color: Color(0xFFB45309)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isHost
                              ? 'Tài khoản chủ trọ đang chờ Admin phê duyệt. Sau khi được duyệt, bạn sẽ mở khóa đầy đủ quyền tạo cơ sở, phòng trọ và đăng tin.'
                              : 'Tài khoản đang chờ Admin phê duyệt. Sau khi được duyệt, bạn có thể thực hiện đặt phòng nhanh chóng.',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF92400E), height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context, true);
                },
                child: const Text('Đã hiểu & Hoàn tất'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Có lỗi xảy ra khi lưu xác thực: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Xác thực CCCD (eKYC)'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thanh tiến độ 3 mục
            _buildProgressCard(),

            const SizedBox(height: 16),

            // Mục 1: Ảnh mặt trước CCCD
            _buildImageUploadCard(
              title: 'Mục 1: Lưu ảnh mặt trước CCCD',
              subtitle: 'Chụp rõ nét mặt trước (ảnh chân dung, Quốc huy, số CCCD, họ tên)',
              image: _frontImage,
              isFront: true,
              status: _frontStatus,
              message: _frontMessage,
            ),

            const SizedBox(height: 16),

            // Mục 2: Ảnh mặt sau CCCD
            _buildImageUploadCard(
              title: 'Mục 2: Lưu ảnh mặt sau CCCD',
              subtitle: 'Chụp rõ nét mặt sau (chip điện tử, phôi Bộ Công An, mã MRZ)',
              image: _backImage,
              isFront: false,
              status: _backStatus,
              message: _backMessage,
            ),

            const SizedBox(height: 16),

            // Mục 3: Quét lấy thông tin mã CCCD
            _buildQrScanCard(),

            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomActionBar(),
    );
  }

  /// Card tiến độ hoàn thành các bước
  Widget _buildProgressCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Quy trình xác thực định danh',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textDark),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _isComplete ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_completedCount/3 mục',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _isComplete ? AppColors.primary : const Color(0xFFD97706),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _completedCount / 3,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(_isComplete ? AppColors.primary : Colors.amber.shade700),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStepIndicator(
                1,
                'Mặt trước',
                _frontImage != null && _frontStatus == CccdSideValidationStatus.valid,
              ),
              const SizedBox(width: 8),
              _buildStepIndicator(
                2,
                'Mặt sau',
                _backImage != null && _backStatus == CccdSideValidationStatus.valid,
              ),
              const SizedBox(width: 8),
              _buildStepIndicator(3, 'Quét mã QR', _cccdData != null),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(int step, String label, bool isDone) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: isDone ? const Color(0xFFECFDF5) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDone ? const Color(0xFF6EE7B7) : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isDone ? Icons.check_circle : Icons.circle_outlined,
              size: 14,
              color: isDone ? AppColors.primary : Colors.grey.shade500,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isDone ? FontWeight.bold : FontWeight.normal,
                  color: isDone ? AppColors.primary : AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Khung tải ảnh mặt trước hoặc mặt sau
  Widget _buildImageUploadCard({
    required String title,
    required String subtitle,
    required XFile? image,
    required bool isFront,
    required CccdSideValidationStatus status,
    required String? message,
  }) {
    final bool hasImage = image != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: status == CccdSideValidationStatus.valid
              ? const Color(0xFF86EFAC)
              : (status == CccdSideValidationStatus.invalid ? const Color(0xFFFCA5A5) : Colors.grey.shade300),
          width: (status == CccdSideValidationStatus.valid || status == CccdSideValidationStatus.invalid) ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textDark),
                ),
              ),
              _buildStatusBadge(status),
            ],
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(height: 12),

          // Khung hiển thị ảnh hoặc ô bấm chụp
          if (hasImage)
            _buildImagePreview(image, isFront, status, message)
          else
            _buildEmptyImagePlaceholder(isFront),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(CccdSideValidationStatus status) {
    switch (status) {
      case CccdSideValidationStatus.idle:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'Cần chọn ảnh mới để xác nhận',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFFD97706),
            ),
          ),
        );
      case CccdSideValidationStatus.validating:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF2563EB)),
              ),
              SizedBox(width: 4),
              Text(
                'Đang thẩm định...',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
              ),
            ],
          ),
        );
      case CccdSideValidationStatus.valid:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFD1FAE5),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'Đã xác nhận CCCD ✓',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
        );
      case CccdSideValidationStatus.invalid:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFFEE2E2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'Không hợp lệ ✕',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red),
          ),
        );
    }
  }

  /// Placeholder khi chưa có ảnh
  Widget _buildEmptyImagePlaceholder(bool isFront) {
    return InkWell(
      onTap: () => _showImagePickerModal(isFront),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.primaryContainer,
                child: Icon(
                  isFront ? Icons.credit_card : Icons.flip_to_back,
                  size: 28,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                isFront ? 'Chạm để chụp / tải ảnh mặt trước' : 'Chạm để chụp / tải ảnh mặt sau',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textDark),
              ),
              const SizedBox(height: 4),
              const Text(
                'Google ML Kit tự động kiểm tra tính hợp lệ',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Preview khi đã có ảnh kèm hộp thông báo kết quả thẩm định
  Widget _buildImagePreview(
    XFile image,
    bool isFront,
    CccdSideValidationStatus status,
    String? message,
  ) {
    final isRealFile = File(image.path).existsSync();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: isRealFile
                ? Image.file(
                    File(image.path),
                    fit: BoxFit.cover,
                  )
                : Container(
                    color: Colors.grey.shade200,
                    child: const Center(
                      child: Icon(Icons.image, size: 48, color: Colors.grey),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 10),

        // Hộp thông báo / Cảnh báo chi tiết từ Google ML Kit
        if (message != null) _buildValidationFeedbackBanner(status, message, isFront),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: () => _showImagePickerModal(isFront),
              icon: const Icon(Icons.refresh, size: 16, color: AppColors.primary),
              label: const Text('Chụp lại / Đổi ảnh',
                  style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
            ),
            TextButton.icon(
              onPressed: () async {
                setState(() {
                  if (isFront) {
                    _frontImage = null;
                    _frontStatus = CccdSideValidationStatus.idle;
                    _frontMessage = null;
                    _frontEvidence = null;
                  } else {
                    _backImage = null;
                    _backStatus = CccdSideValidationStatus.idle;
                    _backMessage = null;
                    _backEvidence = null;
                  }
                });
                await _saveDraft();
              },
              icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
              label: const Text('Xóa', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ],
    );
  }

  /// Banner phản hồi kết quả nhận diện từ Google ML Kit
  Widget _buildValidationFeedbackBanner(
    CccdSideValidationStatus status,
    String message,
    bool isFront,
  ) {
    Color bg;
    Color border;
    Color textColor;
    IconData icon;

    switch (status) {
      case CccdSideValidationStatus.validating:
        bg = const Color(0xFFEFF6FF);
        border = const Color(0xFFBFDBFE);
        textColor = const Color(0xFF1E40AF);
        icon = Icons.hourglass_top_rounded;
        break;
      case CccdSideValidationStatus.valid:
        bg = const Color(0xFFECFDF5);
        border = const Color(0xFFA7F3D0);
        textColor = const Color(0xFF065F46);
        icon = Icons.check_circle_rounded;
        break;
      case CccdSideValidationStatus.invalid:
        bg = const Color(0xFFFEF2F2);
        border = const Color(0xFFFECACA);
        textColor = const Color(0xFF991B1B);
        icon = Icons.warning_amber_rounded;
        break;
      case CccdSideValidationStatus.idle:
        return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: textColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                color: textColor,
                fontWeight: status == CccdSideValidationStatus.invalid ? FontWeight.w600 : FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Thẻ quét mã QR CCCD
  Widget _buildQrScanCard() {
    final bool hasQr = _cccdData != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasQr ? const Color(0xFF86EFAC) : Colors.grey.shade300,
          width: hasQr ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Mục 3: Quét lấy thông tin mã CCCD',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textDark),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: hasQr ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  hasQr ? 'Đã trích xuất ✓' : 'Bắt buộc',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: hasQr ? AppColors.primary : Colors.red.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Quét mã QR góc trên bên phải thẻ CCCD để lấy thông tin thật 100%',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),

          if (hasQr) _buildQrDataPreview(_cccdData!) else _buildEmptyQrPlaceholder(),
        ],
      ),
    );
  }

  /// Placeholder khi chưa quét QR
  Widget _buildEmptyQrPlaceholder() {
    return InkWell(
      onTap: _scanCccdQr,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFBBF7D0)),
        ),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.primary,
              child: Icon(Icons.qr_code_scanner, size: 30, color: Colors.white),
            ),
            const SizedBox(height: 12),
            const Text(
              'Nhấn để Mở Camera Quét Mã QR CCCD',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
            ),
            const SizedBox(height: 4),
            const Text(
              'Hệ thống tự động phân tích và giải mã số thẻ, họ tên, ngày sinh',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  /// Hiển thị thông tin trích xuất từ QR
  Widget _buildQrDataPreview(CccdData cccd) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'THÔNG TIN ĐÃ TRÍCH XUẤT TỪ QR',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green.shade900),
                ),
              ),
              InkWell(
                onTap: _scanCccdQr,
                child: const Text('Quét lại',
                    style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const Divider(height: 16),
          _buildInfoRow('Số CCCD:', cccd.idNumber, isHighlight: true),
          const SizedBox(height: 6),
          _buildInfoRow('Họ và tên:', cccd.fullName, isBold: true),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: _buildInfoRow('Ngày sinh:', cccd.birthDate)),
              Expanded(child: _buildInfoRow('Giới tính:', cccd.gender)),
            ],
          ),
          if (cccd.provinceName != null) ...[
            const SizedBox(height: 6),
            _buildInfoRow('Nơi sinh:', cccd.provinceName!),
          ],
          const SizedBox(height: 6),
          _buildInfoRow('Thường trú:', cccd.address),
          const SizedBox(height: 6),
          _buildInfoRow('Ngày cấp:', cccd.issueDate),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isHighlight = false, bool isBold = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 85,
          child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: (isHighlight || isBold) ? FontWeight.bold : FontWeight.w500,
              color: isHighlight ? AppColors.primary : AppColors.textDark,
            ),
          ),
        ),
      ],
    );
  }

  /// Thanh hành động dưới cùng (Khóa nút nếu chưa đủ 3 mục hoặc ảnh không hợp lệ)
  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thông báo điều kiện xác thực (bắt buộc đủ 3/3 bước)
            if (!_canSubmit)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: Colors.red),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Thiếu: ${_missingItems.join(', ')}. Bắt buộc hoàn tất đủ cả 3 bước (Mặt trước + Mặt sau + Quét mã QR) để gửi xác thực.',
                        style: const TextStyle(fontSize: 11.5, color: Colors.red, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_outline, size: 16, color: AppColors.primary),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Đã đủ 3/3 bước hợp lệ! Bạn có thể nhấn nút xác nhận bên dưới để hoàn tất.',
                        style: TextStyle(fontSize: 11.5, color: AppColors.primary, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),

            // NÚT XÁC THỰC
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _canSubmit ? AppColors.primary : Colors.grey.shade300,
                foregroundColor: _canSubmit ? Colors.white : Colors.grey.shade500,
                elevation: _canSubmit ? 2 : 0,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: (_canSubmit && !_isSubmitting) ? _submitVerification : null,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _canSubmit ? Icons.send_rounded : Icons.lock_outline,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _canSubmit
                              ? 'GỬI HỒ SƠ CHO ADMIN XÉT DUYỆT (3/3)'
                              : 'CHƯA ĐỦ ĐIỀU KIỆN XÁC THỰC ($_completedCount/3)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: _canSubmit ? Colors.white : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
