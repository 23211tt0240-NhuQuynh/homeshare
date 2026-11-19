import 'package:flutter/material.dart';

/// Shared navigation for property management and its room list.
class HostManagementNavigation extends StatelessWidget {
  const HostManagementNavigation({
    super.key,
    this.selectedIndex = 0,
    required this.onSelected,
    this.canCreate = true,
    this.createTooltip = 'Thêm mới',
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool canCreate;
  final String createTooltip;

  @override
  Widget build(BuildContext context) {
    const labels = [
      'Thông tin chung',
      'QL người thuê',
      'Thêm mới',
      'QL Tiền tệ',
      'Quay lại',
    ];
    const icons = [
      Icons.home_outlined,
      Icons.people_outline,
      Icons.add,
      Icons.credit_card,
      Icons.arrow_back,
    ];
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: List.generate(labels.length, (index) {
              final selected = index == selectedIndex;
              final color = selected
                  ? const Color(0xFF2563EB)
                  : const Color(0xFF64748B);
              return Expanded(
                child: Semantics(
                  selected: selected,
                  button: true,
                  label: labels[index],
                  child: InkWell(
                    onTap: index == 2 && !canCreate
                        ? null
                        : () => onSelected(index),
                    child: index == 2
                        ? Tooltip(
                            message: createTooltip,
                            child: Center(
                              heightFactor: 1,
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2563EB),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x662563EB),
                                      blurRadius: 12,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.add,
                                  color: Colors.white,
                                  size: 26,
                                ),
                              ),
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(icons[index], color: color, size: 20),
                                const SizedBox(height: 4),
                                Text(
                                  labels[index],
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
