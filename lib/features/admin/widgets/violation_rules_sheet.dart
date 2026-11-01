import 'package:flutter/material.dart';
import '../../../core/services/violation_rules_service.dart';
import '../../../data/models/violation_rule_model.dart';
import '../theme/admin_colors.dart';

/// Modal quản lý khung phạt và điểm uy tín lưu trữ trên Firebase cho Admin
class ViolationRulesSheet extends StatefulWidget {
  const ViolationRulesSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ViolationRulesSheet(),
    );
  }

  @override
  State<ViolationRulesSheet> createState() => _ViolationRulesSheetState();
}

class _ViolationRulesSheetState extends State<ViolationRulesSheet> {
  final ViolationRulesService _service = ViolationRulesService();
  bool _isProcessing = false;

  static Color get _primary => AdminColors.successInk;
  static Color get _red => AdminColors.danger;
  static Color get _textDark => AdminColors.ink;
  static Color get _textGrey => AdminColors.muted;

  void _showEditRuleDialog({ViolationRuleModel? rule}) {
    final isNew = rule == null;
    final titleCtrl = TextEditingController(text: rule?.title ?? '');
    final descCtrl = TextEditingController(text: rule?.description ?? '');
    int points = rule?.defaultPoints ?? 10;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AdminColors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            isNew ? 'Thêm lỗi vi phạm mới' : 'Chỉnh sửa quy định vi phạm',
            style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: _textDark),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tên lỗi vi phạm:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _textDark)),
                const SizedBox(height: 6),
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(
                    hintText: 'Ví dụ: Tự ý tăng tiền điện nước...',
                    hintStyle: TextStyle(fontSize: 12.5),
                    filled: true,
                    fillColor: AdminColors.paper,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AdminColors.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AdminColors.border)),
                  ),
                ),
                const SizedBox(height: 12),
                Text('Mô tả hành vi vi phạm:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _textDark)),
                const SizedBox(height: 6),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Giải thích hành vi vi phạm để hiển thị cho người dùng...',
                    hintStyle: TextStyle(fontSize: 12.5),
                    filled: true,
                    fillColor: AdminColors.paper,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AdminColors.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AdminColors.border)),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Text('Số điểm trừ mặc định:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _textDark)),
                    const Spacer(),
                    Container(
                      decoration: BoxDecoration(
                        color: AdminColors.accentSoft,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AdminColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: points > 1 ? () => setDialogState(() => points = (points - 5).clamp(1, 100)) : null,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: Icon(Icons.remove, size: 16),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              '-$points đ',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _red),
                            ),
                          ),
                          InkWell(
                            onTap: points < 100 ? () => setDialogState(() => points = (points + 5).clamp(1, 100)) : null,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: Icon(Icons.add, size: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [5, 10, 15, 20, 25, 30].map((pts) {
                    final isSel = points == pts;
                    return ChoiceChip(
                      label: Text('-$pts đ', style: TextStyle(fontSize: 11, color: isSel ? Colors.white : _textDark, fontWeight: FontWeight.w600)),
                      selected: isSel,
                      selectedColor: _red,
                      backgroundColor: AdminColors.paper,
                      onSelected: (_) => setDialogState(() => points = pts),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Hủy', style: TextStyle(color: _textGrey)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _primary),
              onPressed: () async {
                final title = titleCtrl.text.trim();
                final desc = descCtrl.text.trim();
                if (title.isEmpty) return;

                Navigator.pop(ctx);
                setState(() => _isProcessing = true);
                try {
                  final newRule = ViolationRuleModel(
                    id: rule?.id ?? 'rule_${DateTime.now().millisecondsSinceEpoch}',
                    title: title,
                    description: desc.isNotEmpty ? desc : 'Vi phạm quy tắc hệ thống HomeShare',
                    defaultPoints: points,
                    isActive: rule?.isActive ?? true,
                    createdAt: rule?.createdAt ?? DateTime.now(),
                    updatedAt: DateTime.now(),
                  );
                  await _service.addOrUpdateRule(newRule);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(backgroundColor: AdminColors.success, content: Text(isNew ? 'Đã thêm lỗi vi phạm mới lên Firebase' : 'Đã cập nhật khung phạt')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(backgroundColor: _red, content: Text('Lỗi: $e')),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _isProcessing = false);
                }
              },
              child: Text(isNew ? 'Thêm mới' : 'Lưu thay đổi'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmResetToDefault() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Khôi phục khung phạt mặc định?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: Text(
          'Hệ thống sẽ đặt lại toàn bộ danh mục lỗi và số điểm phạt về 7 quy định gốc ban đầu.',
          style: TextStyle(fontSize: 13, color: _textGrey, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Hủy')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Khôi phục'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    setState(() => _isProcessing = true);
    try {
      await _service.resetToDefaultRules();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AdminColors.success, content: Text('Đã khôi phục khung phạt mặc định')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: _red, content: Text('Lỗi: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: AdminColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AdminColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AdminColors.accentSoft,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AdminColors.border),
                  ),
                  child: Icon(Icons.settings_suggest_rounded, color: AdminColors.accentDark, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quản lý Khung phạt & Trừ điểm UT',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _textDark),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Lưu trữ Firebase • Thay đổi áp dụng ngay lập tức',
                        style: TextStyle(fontSize: 11.5, color: _textGrey),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: _textGrey),
                  onSelected: (val) {
                    if (val == 'reset') _confirmResetToDefault();
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'reset',
                      child: Row(
                        children: [
                          Icon(Icons.restart_alt_rounded, size: 18, color: _red),
                          SizedBox(width: 8),
                          Text('Khôi phục mặc định', style: TextStyle(fontSize: 13, color: _red)),
                        ],
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.close, color: _textGrey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AdminColors.border),

          if (_isProcessing)
            LinearProgressIndicator(color: _primary, minHeight: 2),

          // Stream list from Firestore
          Expanded(
            child: StreamBuilder<List<ViolationRuleModel>>(
              stream: _service.streamRules(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final rules = snapshot.data ?? [];
                if (rules.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.gavel_rounded, size: 48, color: AdminColors.border),
                        const SizedBox(height: 8),
                        Text('Chưa có quy định phạt nào', style: TextStyle(color: _textGrey)),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: _confirmResetToDefault,
                          child: Text('Khởi tạo danh mục mặc định'),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  itemCount: rules.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final rule = rules[index];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: rule.isActive ? AdminColors.card : AdminColors.paper,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: rule.isActive ? AdminColors.border : AdminColors.border,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Active switch
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Switch(
                              value: rule.isActive,
                              activeThumbColor: _primary,
                              onChanged: (val) async {
                                await _service.addOrUpdateRule(rule.copyWith(isActive: val));
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        rule.title,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          color: rule.isActive ? _textDark : _textGrey,
                                          decoration: rule.isActive ? null : TextDecoration.lineThrough,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: rule.isActive ? AdminColors.dangerContainer : AdminColors.accentSoft,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '-${rule.defaultPoints}đ UT',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: rule.isActive ? _red : _textGrey,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  rule.description,
                                  style: TextStyle(fontSize: 12, color: _textGrey, height: 1.3),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    InkWell(
                                      onTap: () => _showEditRuleDialog(rule: rule),
                                      borderRadius: BorderRadius.circular(6),
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit_outlined, size: 14, color: _primary),
                                            SizedBox(width: 4),
                                            Text('Sửa khung phạt', style: TextStyle(fontSize: 11.5, color: _primary, fontWeight: FontWeight.w600)),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    InkWell(
                                      onTap: () async {
                                        final del = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: Text('Xóa quy định vi phạm?', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                                            content: Text('Bạn có chắc muốn xóa lỗi "${rule.title}" khỏi khung phạt?'),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Hủy')),
                                              FilledButton(style: FilledButton.styleFrom(backgroundColor: _red), onPressed: () => Navigator.pop(ctx, true), child: Text('Xóa')),
                                            ],
                                          ),
                                        );
                                        if (del == true) {
                                          await _service.deleteRule(rule.id);
                                        }
                                      },
                                      borderRadius: BorderRadius.circular(6),
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete_outline, size: 14, color: _red),
                                            SizedBox(width: 4),
                                            Text('Xóa', style: TextStyle(fontSize: 11.5, color: _red, fontWeight: FontWeight.w600)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Bottom Action: Add new rule
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AdminColors.card,
              border: Border(top: BorderSide(color: AdminColors.border)),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _showEditRuleDialog(),
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: Text('Thêm lỗi vi phạm mới vào khung phạt', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
