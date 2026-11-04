import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/booking_model.dart';

/// Modal Hiển thị Mã QR Nhận Phòng & Bàn Giao Thiết Bị cho Khách Thuê
/// Sau khi đơn được Admin/Chủ trọ duyệt, khách đưa mã này cho Chủ trọ quét
class CheckinQrBottomSheet extends StatelessWidget {
  final BookingRequestModel booking;

  const CheckinQrBottomSheet({super.key, required this.booking});

  static void show(BuildContext context, BookingRequestModel booking) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CheckinQrBottomSheet(booking: booking),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat('#,###', 'vi_VN');
    final qrData = booking.toQrJson();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF8FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFB2DDFF)),
                  ),
                  child: const Icon(
                    Icons.qr_code_2_rounded,
                    color: Color(0xFF155EEF),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MÃ QR NHẬN PHÒNG',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textDark,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Color(0xFF12B76A),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Text(
                            'Đã duyệt • Sẵn sàng nhận phòng',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF027A48),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: AppColors.textMuted),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Scrollable Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                children: [
                  // QR Card Container
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppColors.border, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF155EEF).withValues(alpha: 0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        QrImageView(
                          data: qrData,
                          version: QrVersions.auto,
                          size: 210,
                          backgroundColor: Colors.white,
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: Color(0xFF155EEF),
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Mã Đơn & Nút copy
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: booking.id));
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Đã sao chép mã đơn: ${booking.id}'),
                                duration: const Duration(seconds: 1),
                                backgroundColor: const Color(0xFF155EEF),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Mã: ${booking.id}',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF344054),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.copy_rounded, size: 14, color: Color(0xFF155EEF)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── THẺ 1: THÔNG TIN PHÒNG TRỌ ──
                  _buildSectionCard(
                    title: 'THÔNG TIN PHÒNG TRỌ',
                    icon: Icons.meeting_room_outlined,
                    iconColor: const Color(0xFF155EEF),
                    children: [
                      _buildInfoRow('Tên phòng:', booking.roomTitle, isBold: true),
                      if (booking.roomCode.isNotEmpty)
                        _buildInfoRow('Mã phòng:', booking.roomCode),
                      _buildInfoRow('Địa chỉ:', booking.roomAddress),
                      _buildInfoRow(
                        'Giá thuê:',
                        '${currencyFormatter.format(booking.roomPrice)} đ/tháng',
                        highlightColor: const Color(0xFF155EEF),
                      ),
                        _buildInfoRow(
                          'Tiền cọc đã duyệt:',
                          '${currencyFormatter.format(booking.deposit)} đ',
                          highlightColor: const Color(0xFF12B76A),
                        ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // ── THẺ 2: THÔNG TIN NGƯỜI THUÊ ──
                  _buildSectionCard(
                    title: 'THÔNG TIN KHÁCH THUÊ',
                    icon: Icons.person_outline_rounded,
                    iconColor: const Color(0xFF7F56D9),
                    children: [
                      _buildInfoRow('Họ và tên:', booking.renterName, isBold: true),
                      _buildInfoRow('Số điện thoại:', booking.renterPhone),
                      if (booking.renterUserCode.isNotEmpty)
                        _buildInfoRow('Mã người dùng:', booking.renterUserCode),
                      _buildInfoRow(
                        'Ngày dự kiến vào:',
                        DateFormat('dd/MM/yyyy').format(booking.moveInDate),
                      ),
                      _buildInfoRow('Thời hạn hợp đồng:', '${booking.rentalMonths} tháng'),
                      _buildInfoRow('Chủ trọ phụ trách:', booking.hostName),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Hướng dẫn nhận phòng
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF8FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFD1E9FF)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Icon(Icons.info_outline, color: Color(0xFF175CD3), size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Xuất trình mã QR này cho Chủ trọ khi đến nhận phòng. Chủ trọ sẽ quét mã để kiểm tra thông tin, bàn giao chìa khóa & chốt chỉ số điện nước, sau đó kích hoạt trạng thái "Đang ở".',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF1849A9),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Nút Đóng
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF155EEF),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'ĐÓNG',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: iconColor,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    bool isBold = false,
    Color? highlightColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                color: highlightColor ?? (isBold ? AppColors.textDark : const Color(0xFF344054)),
                fontWeight: (isBold || highlightColor != null)
                    ? FontWeight.bold
                    : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
