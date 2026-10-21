import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Modal quét mã QR tốc hành cho Chủ nhà khi Check-in / Check-out
class HostQrScannerModal extends StatefulWidget {
  final bool isCheckin;
  final String sampleCode;
  final String sampleRoomCode;
  final ValueChanged<String> onCodeScanned;

  const HostQrScannerModal({
    super.key,
    required this.isCheckin,
    required this.sampleCode,
    required this.sampleRoomCode,
    required this.onCodeScanned,
  });

  @override
  State<HostQrScannerModal> createState() => _HostQrScannerModalState();
}

class _HostQrScannerModalState extends State<HostQrScannerModal>
    with SingleTickerProviderStateMixin {
  late final MobileScannerController _controller;
  late final AnimationController _animController;
  late final Animation<double> _laserAnimation;

  bool _isTorchOn = false;
  CameraFacing _cameraFacing = CameraFacing.back;
  bool _hasDetected = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      detectionTimeoutMs: 250,
      formats: const [BarcodeFormat.qrCode],
      facing: _cameraFacing,
      torchEnabled: false,
    );

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _laserAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _toggleTorch() async {
    try {
      await _controller.toggleTorch();
      setState(() => _isTorchOn = !_isTorchOn);
    } catch (_) {}
  }

  void _switchCamera() async {
    try {
      await _controller.switchCamera();
      setState(() {
        _cameraFacing = _cameraFacing == CameraFacing.back
            ? CameraFacing.front
            : CameraFacing.back;
      });
    } catch (_) {}
  }

  void _triggerDetect(String code) {
    if (_hasDetected) return;
    _hasDetected = true;
    Navigator.of(context).pop();
    widget.onCodeScanned(code);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isCheckin
        ? 'Quét QR Check-in Nhận Phòng'
        : 'Quét QR Check-out Trả Phòng';
    final subtitle = widget.isCheckin
        ? 'Hướng camera vào mã QR nhận phòng của khách thuê'
        : 'Hướng camera vào mã QR phòng hoặc hợp đồng cần trả';

    final boxSize = (MediaQuery.of(context).size.width * 0.68).clamp(220.0, 260.0);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header thanh kéo modal
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // AppBar tùy biến
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Nút bật/tắt đèn flash
                IconButton(
                  icon: Icon(
                    _isTorchOn ? Icons.flash_on : Icons.flash_off,
                    color: _isTorchOn ? const Color(0xFFFBBF24) : Colors.white70,
                  ),
                  tooltip: _isTorchOn ? 'Tắt đèn Flash' : 'Bật đèn Flash',
                  onPressed: _toggleTorch,
                ),
              ],
            ),
          ),

          // Vùng quét Camera
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Viewfinder từ thiết bị
                    MobileScanner(
                      controller: _controller,
                      onDetect: (capture) {
                        final barcodes = capture.barcodes;
                        if (barcodes.isNotEmpty) {
                          final code = barcodes.first.rawValue ?? '';
                          if (code.isNotEmpty) {
                            _triggerDetect(code);
                          }
                        }
                      },
                      errorBuilder: (ctx, error) {
                        return Container(
                          color: const Color(0xFF1E293B),
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.no_photography_outlined,
                                  color: Colors.white54,
                                  size: 48,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Không thể truy cập camera',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Vui lòng cấp quyền camera trong Cài đặt thiết bị hoặc sử dụng nút thử nghiệm bên dưới.\n(${error.errorDetails?.message ?? error.errorCode.name})',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    // Lớp tối mờ xung quanh khung quét
                    ColorFiltered(
                      colorFilter: ColorFilter.mode(
                        Colors.black.withValues(alpha: 0.5),
                        BlendMode.srcOut,
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Container(
                            decoration: const BoxDecoration(
                              color: Colors.black,
                              backgroundBlendMode: BlendMode.dstOut,
                            ),
                          ),
                          Center(
                            child: Container(
                              width: boxSize,
                              height: boxSize,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Khung viền và 4 góc căn chỉnh
                    SizedBox(
                      width: boxSize,
                      height: boxSize,
                      child: Stack(
                        children: [
                          // 4 góc căn chỉnh dạ quang
                          CustomPaint(
                            size: Size(boxSize, boxSize),
                            painter: _ScannerCornerPainter(
                              color: const Color(0xFF3B82F6),
                              strokeWidth: 4,
                            ),
                          ),

                          // Tia laser quét lên xuống
                          AnimatedBuilder(
                            animation: _laserAnimation,
                            builder: (ctx, child) {
                              return Positioned(
                                top: _laserAnimation.value * (boxSize - 12) + 6,
                                left: 12,
                                right: 12,
                                child: Container(
                                  height: 3,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Colors.transparent,
                                        Color(0xFF38BDF8),
                                        Colors.white,
                                        Color(0xFF38BDF8),
                                        Colors.transparent,
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF38BDF8).withValues(alpha: 0.8),
                                        blurRadius: 8,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    // Nút đổi camera trước / sau
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
                          tooltip: 'Đổi camera',
                          onPressed: _switchCamera,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Phần nút thử nghiệm & hướng dẫn
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              children: [
                // Nút giả lập QR trên môi trường test / giả lập
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _triggerDetect(widget.sampleCode),
                    icon: const Icon(Icons.qr_code, color: Color(0xFF60A5FA), size: 18),
                    label: Text(
                      'Thử nghiệm quét nhanh phòng P.${widget.sampleRoomCode}',
                      style: const TextStyle(
                        color: Color(0xFF93C5FD),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF3B82F6), width: 1.2),
                      backgroundColor: const Color(0xFF1E3A8A).withValues(alpha: 0.4),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.isCheckin
                      ? 'Khách thuê có thể xuất trình mã này tại mục "Quản lý đơn thuê"'
                      : 'Hỗ trợ quét định danh mã QR phòng hoặc biên bản trả phòng',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Vẽ 4 góc căn chỉnh khung quét QR
class _ScannerCornerPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _ScannerCornerPainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cornerLength = 24.0;
    const radius = 12.0;

    // Góc trên bên trái
    final pathTL = Path()
      ..moveTo(0, cornerLength)
      ..lineTo(0, radius)
      ..quadraticBezierTo(0, 0, radius, 0)
      ..lineTo(cornerLength, 0);
    canvas.drawPath(pathTL, paint);

    // Góc trên bên phải
    final pathTR = Path()
      ..moveTo(size.width - cornerLength, 0)
      ..lineTo(size.width - radius, 0)
      ..quadraticBezierTo(size.width, 0, size.width, radius)
      ..lineTo(size.width, cornerLength);
    canvas.drawPath(pathTR, paint);

    // Góc dưới bên trái
    final pathBL = Path()
      ..moveTo(0, size.height - cornerLength)
      ..lineTo(0, size.height - radius)
      ..quadraticBezierTo(0, size.height, radius, size.height)
      ..lineTo(cornerLength, size.height);
    canvas.drawPath(pathBL, paint);

    // Góc dưới bên phải
    final pathBR = Path()
      ..moveTo(size.width - cornerLength, size.height)
      ..lineTo(size.width - radius, size.height)
      ..quadraticBezierTo(size.width, size.height, size.width, size.height - radius)
      ..lineTo(size.width, size.height - cornerLength);
    canvas.drawPath(pathBR, paint);
  }

  @override
  bool shouldRepaint(covariant _ScannerCornerPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
  }
}
