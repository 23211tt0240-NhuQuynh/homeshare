import 'package:flutter/material.dart';
import '../models/violation_record_model.dart';
import '../../../core/constants/app_colors.dart';

class ViolationRecordCard extends StatefulWidget {
  final ViolationRecordModel record;
  final VoidCallback onDeductInvoice;
  final VoidCallback onCollectCash;
  final VoidCallback onSendReminder;

  const ViolationRecordCard({
    super.key,
    required this.record,
    required this.onDeductInvoice,
    required this.onCollectCash,
    required this.onSendReminder,
  });

  @override
  State<ViolationRecordCard> createState() => _ViolationRecordCardState();
}

class _ViolationRecordCardState extends State<ViolationRecordCard> {
  bool _isExpanded = false;

  String _formatCurrency(double amount) {
    final s = amount.toInt().toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      buffer.write(s[i]);
      count++;
      if (count % 3 == 0 && i != 0) {
        buffer.write('.');
      }
    }
    return '${buffer.toString().split('').reversed.join()} đ';
  }

  String _formatDate(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    final y = dt.year;
    return '$h:$m • $d/$mo/$y';
  }

  Widget _buildStatusBadge(ViolationRecordModel record) {
    Color bg;
    Color text;
    String label = record.statusDisplayText;

    if (record.isPaid) {
      bg = AppColors.successContainer;
      text = const Color(0xFF15803D);
    } else if (record.isAddedToInvoice) {
      bg = AppColors.primaryContainer;
      text = (AppColors.isDark ? AppColors.textDark : const Color(0xFF1D4ED8));
    } else if (record.isCancelled) {
      bg = AppColors.surfaceVariant;
      text = const Color(0xFF64748B);
    } else {
      bg = AppColors.warningContainer;
      text = const Color(0xFFB45309);
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: text,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.record;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
        border: Border.all(color: AppColors.border),
      ),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Hàng đầu: Số phòng + Tên người thuê + Status badge
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                ),
                child: Text(
                  r.roomCode.isNotEmpty ? r.roomCode : 'P.---',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: (AppColors.isDark ? AppColors.textDark : const Color(0xFF1D4ED8)),
                  ),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.tenantName.isNotEmpty ? r.tenantName : 'Cư dân',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${_formatDate(r.createdAt)}${r.propertyName.isNotEmpty ? ' • ${r.propertyName}' : ''}',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF64748B),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(r),
            ],
          ),
          SizedBox(height: 12),

          // 2. Danh sách hành vi vi phạm (Chips)
          if (r.violationTitles.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: r.violationTitles.map((t) {
                return Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 13,
                        color: (AppColors.isDark ? const Color(0xFFFDE68A) : const Color(0xFFD97706)),
                      ),
                      SizedBox(width: 4),
                      Text(
                        t,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          SizedBox(height: 8),

          // 3. Mô tả vi phạm
          if (r.description.isNotEmpty)
            InkWell(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              child: Text(
                r.description,
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF475569),
                  height: 1.4,
                ),
                maxLines: _isExpanded ? 10 : 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          SizedBox(height: 12),

          // 4. Mức phạt & bằng chứng count
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Mức phạt: ',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    Text(
                      _formatCurrency(r.totalFine),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
              ),
              if (r.evidenceUrls.isNotEmpty)
                Row(
                  children: [
                    Icon(Icons.attach_file,
                        size: 14, color: Color(0xFF64748B)),
                    SizedBox(width: 2),
                    Text(
                      '${r.evidenceUrls.length} bằng chứng',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          SizedBox(height: 12),

          // 5. Nút xử lý (chỉ hiện khi chưa thanh toán / chờ nộp)
          if (r.isPending) ...[
            Divider(height: 1, color: AppColors.border),
            SizedBox(height: 10),
            Row(
              children: [
                // Nút 1: Trừ hóa đơn
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onDeductInvoice,
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      side: BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Trừ hóa đơn',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                // Nút 2: Thu tiền mặt
                Expanded(
                  child: ElevatedButton(
                    onPressed: widget.onCollectCash,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      padding: EdgeInsets.symmetric(vertical: 8),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('💵 ', style: TextStyle(fontSize: 12)),
                          Text(
                            'Thu tiền mặt',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                // Nút 3: Gửi nhắc nộp
                InkWell(
                  onTap: widget.onSendReminder,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.send_rounded,
                            size: 14, color: (AppColors.isDark ? AppColors.textDark : const Color(0xFF2563EB))),
                        SizedBox(width: 4),
                        Text(
                          'Nhắc',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: (AppColors.isDark ? AppColors.textDark : const Color(0xFF2563EB)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ] else if (r.isAddedToInvoice) ...[
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: (AppColors.isDark ? AppColors.textDark : const Color(0xFF2563EB))),
                  SizedBox(width: 6),
                  Text(
                    'Đã ghi nhận cộng vào hóa đơn tiền phòng tháng sau',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: (AppColors.isDark ? AppColors.textDark : const Color(0xFF1D4ED8)),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (r.isPaid) ...[
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 14, color: (AppColors.isDark ? const Color(0xFF86EFAC) : const Color(0xFF16A34A))),
                  SizedBox(width: 6),
                  Text(
                    'Đã nộp tiền mặt và xuất biên lai',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: (AppColors.isDark ? const Color(0xFF86EFAC) : const Color(0xFF15803D)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
