import 'dart:async';
import 'package:flutter/material.dart';
import '../models/violation_record_model.dart';

class ViolationRecordCard extends StatefulWidget {
  final ViolationRecordModel record;
  final VoidCallback onCollectCash;
  final VoidCallback onSendReminder;
  final VoidCallback? onDeductInvoice;

  const ViolationRecordCard({
    super.key,
    required this.record,
    required this.onCollectCash,
    required this.onSendReminder,
    this.onDeductInvoice,
  });

  @override
  State<ViolationRecordCard> createState() => _ViolationRecordCardState();
}

class _ViolationRecordCardState extends State<ViolationRecordCard> {
  bool _isExpanded = false;
  Timer? _cooldownTimer;
  int _cooldownSeconds = 0;

  @override
  void initState() {
    super.initState();
    _checkInitialCooldown();
  }

  @override
  void didUpdateWidget(ViolationRecordCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.record.lastReminderAt != widget.record.lastReminderAt) {
      _checkInitialCooldown();
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _checkInitialCooldown() {
    final last = widget.record.lastReminderAt;
    if (last != null) {
      final elapsed = DateTime.now().difference(last).inSeconds;
      if (elapsed < 60) {
        _cooldownSeconds = 60 - elapsed;
        _startTimer();
      } else {
        _cooldownSeconds = 0;
      }
    }
  }

  void _startTimer() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cooldownSeconds > 1) {
        setState(() {
          _cooldownSeconds--;
        });
      } else {
        timer.cancel();
        setState(() {
          _cooldownSeconds = 0;
        });
      }
    });
  }

  void _triggerReminder() {
    if (_cooldownSeconds > 0) return;
    setState(() {
      _cooldownSeconds = 60;
    });
    _startTimer();
    widget.onSendReminder();
  }

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
      bg = const Color(0xFFDCFCE7);
      text = const Color(0xFF15803D);
    } else if (record.isAddedToInvoice) {
      bg = const Color(0xFFDBEAFE);
      text = const Color(0xFF1D4ED8);
    } else if (record.isCancelled) {
      bg = const Color(0xFFF1F5F9);
      text = const Color(0xFF64748B);
    } else {
      bg = const Color(0xFFFEF3C7);
      text = const Color(0xFFB45309);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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

  Widget _buildReminderButton() {
    final isCoolingDown = _cooldownSeconds > 0;

    return InkWell(
      onTap: isCoolingDown ? null : _triggerReminder,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isCoolingDown
              ? const Color(0xFFF1F5F9)
              : const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isCoolingDown
                ? const Color(0xFFCBD5E1)
                : const Color(0xFFBFDBFE),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isCoolingDown
                  ? Icons.hourglass_top_rounded
                  : Icons.send_rounded,
              size: 14,
              color: isCoolingDown
                  ? const Color(0xFF94A3B8)
                  : const Color(0xFF2563EB),
            ),
            const SizedBox(width: 4),
            Text(
              isCoolingDown ? 'Chờ ${_cooldownSeconds}s' : 'Nhắc',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: isCoolingDown
                    ? const Color(0xFF64748B)
                    : const Color(0xFF2563EB),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.record;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header: Mã biên bản, Phòng, Người thuê & Trạng thái
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  r.id.length > 12 ? r.id.substring(r.id.length - 12) : r.id,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.tenantName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_formatDate(r.createdAt)}${r.propertyName.isNotEmpty ? " • ${r.propertyName}" : ""}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(r),
            ],
          ),
          const SizedBox(height: 12),

          // 2. Danh sách các vi phạm
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: r.violationTitles.map((title) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFFFEDD5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 13,
                      color: Color(0xFFEA580C),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFC2410C),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),

          // 3. Mô tả vi phạm (nếu có - chạm để xem thêm/thu gọn)
          if (r.description.isNotEmpty) ...[
            InkWell(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              borderRadius: BorderRadius.circular(4),
              child: Text(
                r.description,
                maxLines: _isExpanded ? null : 2,
                overflow: _isExpanded ? null : TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF475569),
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // 4. Mức phạt & Bằng chứng
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              RichText(
                text: TextSpan(
                  text: 'Mức phạt: ',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                  children: [
                    TextSpan(
                      text: _formatCurrency(r.totalFine),
                      style: const TextStyle(
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
                    const Icon(Icons.attach_file,
                        size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 2),
                    Text(
                      '${r.evidenceUrls.length} bằng chứng',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),

          // 5. Nút xử lý (chỉ hiện khi chưa thanh toán / chờ nộp)
          if (r.isPending) ...[
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 10),
            Row(
              children: [
                // Nút: Thu tiền mặt
                Expanded(
                  child: ElevatedButton(
                    onPressed: widget.onCollectCash,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('💵 ', style: TextStyle(fontSize: 13)),
                        Text(
                          'Thu tiền mặt',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Nút: Gửi nhắc nộp kèm Anti-Spam Cooldown
                _buildReminderButton(),
              ],
            ),
          ] else if (r.isAddedToInvoice) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: Color(0xFF2563EB)),
                  SizedBox(width: 6),
                  Text(
                    'Đã ghi nhận cộng vào hóa đơn tiền phòng tháng sau',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1D4ED8),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (r.isPaid) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 14, color: Color(0xFF16A34A)),
                  SizedBox(width: 6),
                  Text(
                    'Đã nộp tiền mặt và xuất biên lai',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF15803D),
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
