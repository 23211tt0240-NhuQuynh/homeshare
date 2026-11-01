import 'package:flutter/material.dart';
import '../../../core/utils/room_deposit.dart';
import '../../../core/utils/vnd_input.dart';

// Chủ trọ - Chọn cọc theo phần trăm - Luồng đi: Ô nhỏ chọn tỷ lệ,
// số tiền chỉ hiển thị và tự đổi khi giá thuê hoặc tỷ lệ thay đổi.
class HostDepositInput extends StatelessWidget {
  const HostDepositInput({
    super.key,
    required this.priceController,
    required this.percentage,
    required this.onChanged,
    this.formattedPrice = true,
    this.legacyDeposit = 0,
  });
  final TextEditingController priceController;
  final int? percentage;
  final ValueChanged<int?> onChanged;
  final bool formattedPrice;
  final double legacyDeposit;

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: priceController,
        builder: (context, value, _) {
          final price = double.tryParse(vndDigits(value.text));
          final validPrice = price != null && price.isFinite && price >= 0;
          final amount = percentage == null
              ? legacyDeposit
              : validPrice
              ? roomDeposit(price, percentage!)
              : 0;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Tiền cọc (đ)',
                        suffixIcon: Icon(Icons.lock_outline),
                      ),
                      child: Text(
                        formatVnd(amount),
                        key: const ValueKey('host_deposit_amount'),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  SizedBox(
                    width: 112,
                    child: DropdownButtonFormField<int>(
                      key: const ValueKey('host_deposit_percentage'),
                      initialValue: percentage,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: 'Tỷ lệ cọc'),
                      hint: Text('Chọn %'),
                      items: [
                        for (final percent in roomDepositPercentages)
                          DropdownMenuItem(
                            value: percent,
                            child: Text('$percent%'),
                          ),
                      ],
                      onChanged: onChanged,
                      validator: (value) =>
                          value == null ? 'Chọn tỷ lệ cọc' : null,
                    ),
                  ),
                ],
              ),
              if (percentage == null)
                Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    'Chọn tỷ lệ để áp dụng theo giá thuê hiện tại.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
            ],
          );
        },
      );
}
