import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Diện tích chính xác; ô nhập và thanh kéo dùng chung một giá trị.
class HostAreaInput extends StatefulWidget {
  const HostAreaInput({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final double value;
  final ValueChanged<double> onChanged;

  @override
  State<HostAreaInput> createState() => _HostAreaInputState();
}

class _HostAreaInputState extends State<HostAreaInput> {
  late final TextEditingController _controller;

  String _text(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _text(widget.value));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maximum = math.max(100.0, widget.value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Diện tích phòng',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: const ValueKey('room_area_input'),
          controller: _controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          decoration: const InputDecoration(
            labelText: 'Diện tích *',
            suffixText: 'm²',
          ),
          validator: (raw) {
            final value = double.tryParse((raw ?? '').replaceAll(',', '.'));
            if (value == null ||
                !value.isFinite ||
                value <= 0 ||
                value > 1000000000) {
              return 'Nhập diện tích lớn hơn 0 và không quá 1 tỷ m².';
            }
            return null;
          },
          onChanged: (raw) {
            final value = double.tryParse(raw.replaceAll(',', '.'));
            if (value != null &&
                value.isFinite &&
                value > 0 &&
                value <= 1000000000) {
              widget.onChanged(value);
            }
          },
        ),
        Slider(
          key: const ValueKey('room_area_slider'),
          min: 0.1,
          max: maximum,
          value: widget.value.clamp(0.1, maximum),
          label: '${_text(widget.value)} m²',
          onChanged: (raw) {
            final value = (raw * 10).round() / 10;
            _controller.text = _text(value);
            widget.onChanged(value);
          },
        ),
      ],
    );
  }
}
