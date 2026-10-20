import 'package:flutter/services.dart';

// Chủ trọ - Nhập tiền đồng - Luồng đi: Hiển thị dấu chấm (.) phân cách hàng
// nghìn (vd: 1000000 -> 1.000.000), bỏ dấu định dạng trước khi kiểm tra và lưu số tiền nguyên.
String vndDigits(String value) => value.replaceAll(RegExp(r'[^0-9]'), '');

String formatVnd(num value) {
  final intVal = value.round();
  if (intVal <= 0) return '0';
  return intVal.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (Match m) => '${m[1]}.',
  );
}

class VndInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!RegExp(r'^[0-9.,]*$').hasMatch(newValue.text)) return oldValue;
    final digits = vndDigits(newValue.text);
    if (digits.isEmpty) return const TextEditingValue();
    final amount = int.tryParse(digits);
    if (amount == null || amount > 1000000000) return oldValue;
    final text = formatVnd(amount);
    // Giữ vị trí con trỏ theo số chữ số phía sau khi thêm dấu phân cách.
    final cursor = newValue.selection.extentOffset.clamp(
      0,
      newValue.text.length,
    );
    var remaining = vndDigits(newValue.text.substring(cursor)).length;
    var offset = text.length;
    while (offset > 0 && remaining > 0) {
      offset--;
      if (text[offset] != '.') remaining--;
    }
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}
