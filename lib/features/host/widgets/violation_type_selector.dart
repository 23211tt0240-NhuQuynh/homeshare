import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
  bool _ownsTitleController = false;
  bool _saveToCatalog = false;
  bool _isExpanded = false;
  final List<ViolationModel> _customViolations = [];

  void _handleRemoveCustom(String id) {
    setState(() {
      _customViolations.removeWhere((c) => c.id == id);
    });
    widget.onRemoveViolation?.call(id);
  }

  @override
  void initState() {
    super.initState();
    if (widget.customTitleController != null) {
      _titleController = widget.customTitleController!;
    } else {
      _titleController = TextEditingController();
      _ownsTitleController = true;
    }
  }

  @override
  void dispose() {
    if (_ownsTitleController) {
      _titleController.dispose();
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
    if (amount <= 0) return '';
    final formatter = NumberFormat.decimalPattern('vi');
    return '${formatter.format(amount.toInt())} đ';
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

    // Kiểm tra nếu tên vi phạm trùng với mục có sẵn thì tích chọn luôn
    final matching = widget.violations.where(
      (v) => v.title.toLowerCase().trim() == title.toLowerCase(),
    );
    if (matching.isNotEmpty) {
      final existing = matching.first;
      if (!widget.selectedViolations.any((v) => v.id == existing.id)) {
        widget.onToggle(existing);
      }
      _titleController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hành vi "${existing.title}" đã có, đã chọn mục có sẵn.'),
          backgroundColor: const Color(0xFF2563EB),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    // Kiểm tra trùng trong danh sách vi phạm tùy chỉnh tạm thời
    final matchingCustom = _customViolations.where(
      (v) => v.title.toLowerCase().trim() == title.toLowerCase(),
    );
    if (matchingCustom.isNotEmpty) {
      final existing = matchingCustom.first;
      if (!widget.selectedViolations.any((v) => v.id == existing.id)) {
        widget.onToggle(existing);
      }
      _titleController.clear();
      return;
    }

    widget.onAddCustomViolation?.call(title, null, _saveToCatalog);

    _titleController.clear();
    setState(() {
      _saveToCatalog = false;
      _isExpanded = true;
    });
  }

  Widget _buildViolationTile(ViolationModel item, {required bool isCustom}) {
    final isSelected = widget.selectedViolations.any((v) => v.id == item.id);
    final formattedFine = _formatCurrency(item.defaultFine);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? const Color(0xFF93C5FD) : const Color(0xFFE2E8F0),
          width: isSelected ? 1.4 : 1.0,
        ),
      ),
      child: InkWell(
        onTap: () => widget.onToggle(item),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              // Checkbox vuông chuẩn như thẻ tiện ích HostAmenityTile
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF2563EB) : Colors.white,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF2563EB)
                        : const Color(0xFFCBD5E1),
                    width: 1.5,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 10),

              // Icon đại diện vi phạm
              Icon(
                _getIconData(item.iconName),
                size: 20,
                color: isSelected
                    ? const Color(0xFF2563EB)
                    : _getUnselectedIconColor(item.id),
              ),
              const SizedBox(width: 10),

              // Tên vi phạm
              Expanded(
                child: Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? const Color(0xFF1E40AF)
                        : const Color(0xFF1E293B),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),

              // Nếu là vi phạm tự nhập: Chip "Tự nhập" + Nút xóa
              if (isCustom) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2.5,
                  ),
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
                const SizedBox(width: 6),
                InkWell(
                  onTap: () => _handleRemoveCustom(item.id),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],

              // Mức phạt đề xuất (nếu có)
              if (formattedFine.isNotEmpty)
                Text(
                  formattedFine,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? const Color(0xFF2563EB)
                        : const Color(0xFF475569),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = widget.selectedViolations.length;

    // Đồng bộ các vi phạm tự nhập từ widget.selectedViolations vào danh sách hiển thị
    for (final s in widget.selectedViolations) {
      final isSystem = widget.violations.any((v) => v.id == s.id);
      if (!isSystem &&
          !_customViolations.any((c) =>
              c.id == s.id ||
              c.title.toLowerCase().trim() == s.title.toLowerCase().trim())) {
        _customViolations.add(s);
      }
    }

    // Toàn bộ vi phạm gồm mẫu Firestore + vi phạm tự nhập
    final allItems = <ViolationModel>[
      ...widget.violations,
      ..._customViolations,
    ];

    // Lọc danh sách hiển thị theo trạng thái Thu gọn / Mở rộng (luôn hiện các mục đang chọn)
    final displayedItems = <ViolationModel>[];
    if (_isExpanded || allItems.length <= 4) {
      displayedItems.addAll(allItems);
    } else {
      for (int i = 0; i < allItems.length; i++) {
        final item = allItems[i];
        final isSelected = widget.selectedViolations.any((v) => v.id == item.id);
        if (i < 4 || isSelected) {
          if (!displayedItems.any((d) => d.id == item.id)) {
            displayedItems.add(item);
          }
        }
      }
    }

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
          // 1. Tiêu đề khối & Badge số lượng đã chọn
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
                  selectedCount > 0 ? 'Đã chọn $selectedCount lỗi' : 'Chưa chọn lỗi',
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

          // 2. Khối nhập hành vi vi phạm riêng & Nút Thêm
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: TextField(
                    controller: _titleController,
                    textAlignVertical: TextAlignVertical.center,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      hintText: 'Nhập tên hành vi vi phạm riêng...',
                      hintStyle: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                      prefixIcon: Icon(
                        Icons.add_circle_outline_rounded,
                        color: Color(0xFF2563EB),
                        size: 18,
                      ),
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10),
                    ),
                    onSubmitted: (_) => _handleAddCustom(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  minimumSize: const Size(100, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  elevation: 0,
                ),
                onPressed: _handleAddCustom,
                icon: const Icon(Icons.add, size: 18),
                label: const Text(
                  'Thêm',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Checkbox lưu vào danh mục dùng lại
          InkWell(
            onTap: () {
              setState(() {
                _saveToCatalog = !_saveToCatalog;
              });
            },
            borderRadius: BorderRadius.circular(6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
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
                const SizedBox(width: 6),
                const Text(
                  'Lưu hành vi này vào danh mục vi phạm để dùng cho các lần sau',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 3. Danh sách các hành vi vi phạm (chuẩn hóa theo phong cách thẻ tiện ích)
          Column(
            children: [
              for (final item in displayedItems)
                _buildViolationTile(
                  item,
                  isCustom: !widget.violations.any((v) => v.id == item.id),
                ),
            ],
          ),

          // 4. Nút Thu gọn / Xem thêm khi danh sách có trên 4 mục
          if (allItems.length > 4) ...[
            const SizedBox(height: 4),
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              child: Container(
                width: double.infinity,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F5FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  _isExpanded
                      ? 'Thu gọn ^'
                      : 'Xem thêm (${allItems.length - displayedItems.length} vi phạm) v',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E60F2),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
