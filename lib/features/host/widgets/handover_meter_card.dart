import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';

class HandoverMeterCard extends StatelessWidget {
  final String title;
  final String unit;
  final double rate;
  final TextEditingController controller;
  final bool isElectricity;
  final ValueChanged<String>? onChanged;

  const HandoverMeterCard({
    super.key,
    required this.title,
    required this.unit,
    required this.rate,
    required this.controller,
    required this.isElectricity,
    this.onChanged,
  });

  String _formatRate(double val) {
    return NumberFormat.decimalPattern('vi').format(val);
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = isElectricity
        ? const Color(0xFFEA580C)
        : (AppColors.isDark ? AppColors.textDark : const Color(0xFF2563EB));
    final iconBg = isElectricity
        ? const Color(0xFFFFEDD5)
        : AppColors.primaryContainer;

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Icon + Tiêu đề + Đơn giá
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isElectricity ? Icons.bolt : Icons.water_drop,
                  size: 18,
                  color: iconColor,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              Text(
                'Đơn giá: ${_formatRate(rate)} đ/$unit',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          // Input chỉ số lớn
          Container(
            height: 48,
            padding: EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d*'),
                      ),
                    ],
                    onChanged: onChanged,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      hintText: '0',
                    ),
                  ),
                ),
                Text(
                  unit,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
