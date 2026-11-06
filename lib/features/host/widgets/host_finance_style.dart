import 'package:flutter/material.dart';

// Chủ trọ - Bộ giao diện tài chính riêng cho ví, hóa đơn và biểu đồ dòng tiền.
abstract final class HostFinanceStyle {
  static const ink = Color(0xFF202737);
  static const accent = Color(0xFF5B55CF);
  static const canvas = Color(0xFFF7F7FB);
  static const muted = Color(0xFF7C8193);
  static const lime = Color(0xFFDAF4A7);

  static Widget surface(
    Widget child, {
    EdgeInsets padding = const EdgeInsets.all(20),
  }) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFFEBECF3)),
    ),
    child: child,
  );

  static Widget heading(String eyebrow, String title, {String? trailing}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    eyebrow,
                    style: const TextStyle(
                      color: muted,
                      fontSize: 10,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    title,
                    style: const TextStyle(
                      color: ink,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null)
              Text(
                trailing,
                style: const TextStyle(color: muted, fontSize: 12),
              ),
          ],
        ),
      );
}

// Chủ trọ - Thẻ ví hiển thị số tiền chính và nội dung bổ sung của từng màn.
class HostFinanceWallet extends StatelessWidget {
  const HostFinanceWallet({
    super.key,
    required this.label,
    required this.amount,
    required this.footer,
    this.deposit = false,
  });
  final String label, amount;
  final Widget footer;
  final bool deposit;

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: deposit ? const Color(0xFF3F342E) : HostFinanceStyle.ink,
      borderRadius: BorderRadius.circular(28),
    ),
    child: Stack(
      children: [
        Positioned(
          right: -48,
          top: -70,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: .06),
                width: 30,
              ),
            ),
          ),
        ),
        Positioned(
          right: -60,
          bottom: -100,
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: .04),
                width: 30,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Color(0xFFCFD0DF),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Icon(
                    deposit
                        ? Icons.shield_outlined
                        : Icons.account_balance_wallet_outlined,
                    color: deposit
                        ? const Color(0xFFF4D1AC)
                        : HostFinanceStyle.lime,
                    size: 24,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  amount,
                  style: TextStyle(
                    color: deposit
                        ? const Color(0xFFF4D1AC)
                        : HostFinanceStyle.lime,
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.8,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Divider(color: Colors.white12, height: 1),
              const SizedBox(height: 16),
              footer,
            ],
          ),
        ),
      ],
    ),
  );
}

// Chủ trọ - Biểu đồ cột dòng tiền - Chạm hoặc rê chuột để xem tiền tại từng mốc.
class HostCashflowChart extends StatefulWidget {
  const HostCashflowChart({
    super.key,
    required this.values,
    required this.labels,
  });
  final List<double> values;
  final List<String> labels;
  @override
  State<HostCashflowChart> createState() => _HostCashflowChartState();
}

class _HostCashflowChartState extends State<HostCashflowChart> {
  int? _selected;
  @override
  void didUpdateWidget(covariant HostCashflowChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.values != widget.values) _selected = null;
  }

  String _money(num value) =>
      '${value.round().toString().replaceAll(RegExp(r'\B(?=(\d{3})+(?!\d))'), '.')} đ';
  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox(
        height: 26,
        child: Text(
          _selected == null
              ? 'Chạm biểu đồ để xem chi tiết'
              : '${widget.labels[_selected!]}  •  ${_money(widget.values[_selected!])}',
          style: TextStyle(
            fontSize: 11,
            color: _selected == null
                ? HostFinanceStyle.muted
                : HostFinanceStyle.accent,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      LayoutBuilder(
        builder: (context, constraints) {
          void select(double x) {
            if (widget.values.isEmpty) return;
            setState(
              () =>
                  _selected = (x / constraints.maxWidth * widget.values.length)
                      .floor()
                      .clamp(0, widget.values.length - 1),
            );
          }

          return MouseRegion(
            onHover: (e) => select(e.localPosition.dx),
            child: GestureDetector(
              onTapDown: (e) => select(e.localPosition.dx),
              onHorizontalDragUpdate: (e) => select(e.localPosition.dx),
              child: Semantics(
                label:
                    'Biểu đồ cột dòng tiền. ${widget.labels.asMap().entries.map((e) => '${e.value}: ${_money(widget.values[e.key])}').join(', ')}',
                child: CustomPaint(
                  size: Size(constraints.maxWidth, 160),
                  painter: _CashflowPainter(widget.values, _selected),
                ),
              ),
            ),
          );
        },
      ),
      const SizedBox(height: 12),
      Row(
        children: List.generate(
          widget.labels.length,
          (i) => Expanded(
            child: Text(
              widget.labels[i],
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: i == _selected
                    ? HostFinanceStyle.accent
                    : HostFinanceStyle.muted,
              ),
            ),
          ),
        ),
      ),
      if (widget.values.every((v) => v == 0))
        const Padding(
          padding: EdgeInsets.only(top: 14),
          child: Text(
            'Chưa có giải ngân trong kỳ này',
            style: TextStyle(color: HostFinanceStyle.muted, fontSize: 12),
          ),
        ),
    ],
  );
}

class _CashflowPainter extends CustomPainter {
  _CashflowPainter(this.values, this.selected);
  final List<double> values;
  final int? selected;
  // Chủ trọ - Vẽ cột theo tiền thực nhận; cột được chọn dùng tím đậm,
  // mốc không có giải ngân chỉ hiển thị vạch nhỏ ở đường đáy.
  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final baseline = size.height - 8;
    const top = 10.0;
    final plotHeight = baseline - top;
    final slot = size.width / values.length;
    final width = (slot * .52).clamp(6.0, 34.0);
    final max = values.fold<double>(1, (a, b) => a > b ? a : b);
    final grid = Paint()
      ..color = const Color(0xFFEDEDF5)
      ..strokeWidth = 1;
    for (var row = 0; row < 4; row++) {
      final y = top + plotHeight * row / 3;
      for (var x = 0.0; x < size.width; x += 8) {
        canvas.drawLine(
          Offset(x, y),
          Offset((x + 4).clamp(0, size.width), y),
          grid,
        );
      }
    }
    for (var i = 0; i < values.length; i++) {
      final center = slot * (i + .5);
      final active = i == selected;
      if (active) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              center - slot * .42,
              top - 5,
              slot * .84,
              plotHeight + 10,
            ),
            const Radius.circular(12),
          ),
          Paint()..color = const Color(0xFFF3F1FC),
        );
      }
      final height = values[i] <= 0
          ? 3.0
          : (values[i] / max * (plotHeight - 6)).clamp(4.0, plotHeight);
      final rect = Rect.fromLTWH(
        center - width / 2,
        baseline - height,
        width,
        height,
      );
      final paint = Paint();
      if (values[i] <= 0) {
        paint.color = active
            ? HostFinanceStyle.accent
            : const Color(0xFFDCDCEB);
      } else {
        paint.shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: active
              ? const [Color(0xFF5549C9), Color(0xFF8274E8)]
              : const [Color(0xFF9285EF), Color(0xFFC3BBF8)],
        ).createShader(rect);
      }
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(values[i] <= 0 ? 2 : 7)),
        paint,
      );
      if (active && values[i] > 0) {
        canvas.drawCircle(
          Offset(center, rect.top + 7),
          2.5,
          Paint()..color = Colors.white.withValues(alpha: .9),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CashflowPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.selected != selected;
}
