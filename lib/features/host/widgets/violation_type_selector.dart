import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/violation_model.dart';

class ViolationTypeSelector extends StatefulWidget {
  final List<ViolationModel> violations;
  final List<ViolationModel> selectedViolations;
  final ValueChanged<ViolationModel> onToggle;
  final void Function(String title, double? defaultFine, bool saveToCatalog)?
      onAddCustomViolation;
  final ValueChanged<String>? onRemoveViolation;
  final TextEditingController? customTitleController;
  final TextEditingController? customFineController;

  const ViolationTypeSelector({
    super.key,
    required this.violations,
    required this.selectedViolations,
    required this.onToggle,
    this.onAddCustomViolation,
    this.onRemoveViolation,
    this.customTitleController,
    this.customFineController,
  });

  @override
  State<ViolationTypeSelector> createState() => _ViolationTypeSelectorState();
}

class _ViolationTypeSelectorState extends State<ViolationTypeSelector> {
  late final TextEditingController _titleController;
  late final TextEditingController _fineController;
  bool _ownsTitleController = false;
  bool _ownsFineController = false;
  bool _saveToCatalog = false;

  @override
  void initState() {
    super.initState();
    if (widget.customTitleController != null) {
      _titleController = widget.customTitleController!;
    } else {
      _titleController = TextEditingController();
      _ownsTitleController = true;
    }

    if (widget.customFineController != null) {
      _fineController = widget.customFineController!;
    } else {
      _fineController = TextEditingController();
      _ownsFineController = true;
    }
  }

  @override
  void dispose() {
    if (_ownsTitleController) {
      _titleController.dispose();
    }
    if (_ownsFineController) {
      _fineController.dispose();
    }
    super.dispose();
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'delete_outline':
        return Icons.delete_outline_rounded;
      case 'volume_up_outlined':
        return Icons.campaign_outlined;
      case 'smoke_free_outlined':
        return Icons.smoke_free_rounded;
      case 'group_outlined':
        return Icons.groups_outlined;
      case 'edit_note_rounded':
        return Icons.edit_note_rounded;
      default:
        return Icons.warning_amber_rounded;
    }
  }

  Color _getUnselectedIconColor(String id) {
    if (id.contains('rac')) return const Color(0xFF2563EB);
    if (id.contains('on_ao')) return const Color(0xFFEA580C);
    if (id.contains('hut_thuoc')) return const Color(0xFFEF4444);
    if (id.contains('nguoi_la')) return const Color(0xFF0284C7);
    if (id.contains('custom')) return const Color(0xFF9333EA);
    return const Color(0xFFD97706);
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
    return ' đ';
  }

  void _handleAddCustom() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập tên hành vi vi phạm'),
          backgroundColor: Color(0xFFDC2626),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final rawFine = _fineController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final fine = double.tryParse(rawFine);

    widget.onAddCustomViolation?.call(title, fine, _saveToCatalog);

    _titleController.clear();
    _fineController.clear();
    setState(() {
      _saveToCatalog = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = widget.selectedViolations.length;
    // Lọc ra các vi phạm tự nhập đã chọn
    final customSelected = widget.selectedViolations
        .where((s) => !widget.violations.any((v) => v.id == s.id))
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(
                Icons.rule_rounded,
                color: Color(0xFF2563EB),
                size: 22,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HÀNH VI VI PHẠM',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      'Chọn nội quy mẫu hoặc tự nhập vi phạm mới',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: selectedCount > 0
                      ? const Color(0xFFEFF6FF)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  selectedCount > 0 ? 'Đã chọn  lỗi' : 'Chưa chọn lỗi',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selectedCount > 0
                        ? const Color(0xFF2563EB)
                        : const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 1. Danh sách các vi phạm mẫu có sẵn
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.violations.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = widget.violations[index];
              final isSelected =
                  widget.selectedViolations.any((v) => v.id == item.id);

              return InkWell(
                onTap: () => widget.onToggle(item),
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF2563EB)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF1D4ED8)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _getIconData(item.iconName),
                        size: 20,
                        color: isSelected
                            ? Colors.white
                            : _getUnselectedIconColor(item.id),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      if (item.defaultFine > 0)
                        Text(
                          _formatCurrency(item.defaultFine),
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF334155),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),

          // 2. Danh sách các vi phạm tự nhập đã thêm
          if (customSelected.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(
                  Icons.assignment_turned_in_outlined,
                  size: 16,
                  color: Color(0xFF7C3AED),
                ),
                const SizedBox(width: 6),
                Text(
                  'Vi phạm tự nhập ()',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF4C1D95),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: customSelected.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = customSelected[index];
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF5FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFDDD6FE)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDE9FE),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Tự nhập',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF7C3AED),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item.title,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      if (item.defaultFine > 0) ...[
                        Text(
                          _formatCurrency(item.defaultFine),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF7C3AED),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      InkWell(
                        onTap: () => widget.onRemoveViolation?.call(item.id),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],

          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 14),

          // 3. Khối Tự nhập hành vi vi phạm mới
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.add_circle_outline_rounded,
                  size: 16,
                  color: Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Tự nhập hành vi vi phạm khác',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Ô nhập tên hành vi vi phạm
          TextField(
            controller: _titleController,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              hintText: 'Nhập hành vi vi phạm (VD: Nuôi thú cưng, để xe sai chỗ...)',
              hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              fillColor: const Color(0xFFF8FAFC),
              filled: true,
              prefixIcon: const Icon(
                Icons.edit_outlined,
                size: 18,
                color: Color(0xFF64748B),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF2563EB)),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
          const SizedBox(height: 8),

          // Ô nhập mức phạt đề xuất & Nút Thêm
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _fineController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _handleAddCustom(),
                  decoration: InputDecoration(
                    hintText: 'Mức phạt đề xuất (VNĐ - tùy chọn)',
                    hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                    fillColor: const Color(0xFFF8FAFC),
                    filled: true,
                    prefixIcon: const Icon(
                      Icons.attach_money_rounded,
                      size: 18,
                      color: Color(0xFF64748B),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF2563EB)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _handleAddCustom,
                icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                label: const Text(
                  'Thêm',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Checkbox lưu vào danh mục dùng lại
          InkWell(
            onTap: () {
              setState(() {
                _saveToCatalog = !_saveToCatalog;
              });
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: Checkbox(
                      value: _saveToCatalog,
                      activeColor: const Color(0xFF2563EB),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      onChanged: (val) {
                        setState(() {
                          _saveToCatalog = val ?? false;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Lưu hành vi này vào danh mục vi phạm để dùng cho các lần sau',
                      style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
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
}