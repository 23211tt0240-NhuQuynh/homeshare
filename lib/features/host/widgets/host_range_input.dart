import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/utils/vnd_input.dart';

class HostRangeInput extends StatefulWidget {
  const HostRangeInput({
    super.key,
    required this.label,
    required this.unit,
    required this.values,
    required this.sliderMax,
    required this.onChanged,
    this.minimum = 0,
    this.limit = 1000000000,
    this.money = false,
    this.optional = false,
  });
  final String label, unit;
  final bool money, optional;
  final RangeValues values;
  final double sliderMax, minimum, limit;
  final ValueChanged<RangeValues> onChanged;
  @override
  State<HostRangeInput> createState() => _HostRangeInputState();
}

class _HostRangeInputState extends State<HostRangeInput> {
  late final TextEditingController low, high;
  String number(double value) => widget.money
      ? formatVnd(value)
      : value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();
  @override
  void initState() {
    super.initState();
    final empty = widget.optional && widget.values.end == 0;
    low = TextEditingController(text: empty ? '' : number(widget.values.start));
    high = TextEditingController(text: empty ? '' : number(widget.values.end));
  }

  @override
  void dispose() {
    low.dispose();
    high.dispose();
    super.dispose();
  }

  // Chủ trọ - Khoảng giá dự kiến - Luồng đi: Cho để trống cả hai ô;
  // nếu nhập phải đủ hai giá nguyên dương, tối đa không dưới tối thiểu.
  double? parsed(String text) =>
      double.tryParse(widget.money ? vndDigits(text) : text);
  void typed(String _) {
    if (widget.optional && low.text.isEmpty && high.text.isEmpty) {
      widget.onChanged(const RangeValues(0, 0));
      return;
    }
    final a = parsed(low.text), b = parsed(high.text);
    if (a != null &&
        b != null &&
        a.isFinite &&
        b.isFinite &&
        a >= widget.minimum &&
        b >= a &&
        b <= widget.limit) {
      widget.onChanged(RangeValues(a, b));
    }
  }

  Widget input(TextEditingController controller, String label) => TextFormField(
    controller: controller,
    keyboardType: TextInputType.numberWithOptions(decimal: !widget.money),
    inputFormatters: widget.money ? [VndInputFormatter()] : null,
    decoration: InputDecoration(labelText: label, suffixText: widget.unit),
    onChanged: typed,
    validator: (_) {
      if (widget.optional && low.text.isEmpty && high.text.isEmpty) return null;
      final a = parsed(low.text), b = parsed(high.text);
      if (widget.money && (a == null || b == null || a <= 0 || b <= 0)) {
        return 'Nhập đủ hai giá lớn hơn 0';
      }
      if (a == null ||
          b == null ||
          !a.isFinite ||
          !b.isFinite ||
          a < widget.minimum ||
          b < a ||
          b > widget.limit) {
        return widget.money
            ? 'Giá tối đa phải ≥ tối thiểu, không quá 1 tỷ'
            : 'Nhập khoảng hợp lệ: tối đa ≥ tối thiểu';
      }
      return null;
    },
  );
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(widget.label, style: TextStyle(fontWeight: FontWeight.w600)),
      SizedBox(height: 14),
      Row(
        children: [
          Expanded(child: input(low, 'Tối thiểu')),
          SizedBox(width: 12),
          Expanded(child: input(high, 'Tối đa')),
        ],
      ),
      RangeSlider(
        values: widget.values,
        min: widget.minimum,
        max: math.max(widget.sliderMax, widget.values.end),
        labels: RangeLabels(
          number(widget.values.start),
          number(widget.values.end),
        ),
        onChanged: (values) {
          // Chủ trọ - Kéo giá thuê - Luồng đi: Làm tròn bước 100.000đ;
          // khoảng diện tích giữ cách làm tròn theo mét vuông như trước.
          final step = widget.money ? 100000.0 : 1.0;
          double snap(double value) => ((value / step).round() * step)
              .clamp(widget.money ? step : widget.minimum, widget.limit)
              .toDouble();
          final rounded = RangeValues(snap(values.start), snap(values.end));
          low.text = number(rounded.start);
          high.text = number(rounded.end);
          widget.onChanged(rounded);
        },
      ),
    ],
  );
}
