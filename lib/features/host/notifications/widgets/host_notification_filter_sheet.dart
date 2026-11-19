import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../filters/host_notification_filter.dart';

Future<HostNotificationFilter?> showHostNotificationFilterSheet(
  BuildContext context, {
  required HostNotificationFilter initialFilter,
}) {
  return showModalBottomSheet<HostNotificationFilter>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _HostNotificationFilterSheet(initialFilter: initialFilter),
  );
}

class _HostNotificationFilterSheet extends StatefulWidget {
  final HostNotificationFilter initialFilter;

  const _HostNotificationFilterSheet({required this.initialFilter});

  @override
  State<_HostNotificationFilterSheet> createState() =>
      _HostNotificationFilterSheetState();
}

class _HostNotificationFilterSheetState
    extends State<_HostNotificationFilterSheet> {
  late HostNotificationFilter _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.initialFilter;
  }

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  void _selectRecentDays(int days) {
    final end = _today;
    setState(() {
      _draft = _draft.copyWith(
        startDate: end.subtract(Duration(days: days - 1)),
        endDate: end,
      );
    });
  }

  bool _isRecentDays(int days) {
    if (_draft.startDate == null || _draft.endDate == null) return false;
    final expectedStart = _today.subtract(Duration(days: days - 1));
    return _sameDay(_draft.startDate!, expectedStart) &&
        _sameDay(_draft.endDate!, _today);
  }

  Future<void> _pickDateRange() async {
    final now = _today;
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _draft.startDate != null && _draft.endDate != null
          ? DateTimeRange(start: _draft.startDate!, end: _draft.endDate!)
          : null,
      helpText: 'Chọn khoảng ngày tạo thông báo',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
      saveText: 'Chọn',
    );
    if (range == null || !mounted) return;
    setState(() {
      _draft = _draft.copyWith(startDate: range.start, endDate: range.end);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD0D5DD),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Bộ lọc thông báo',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF101828),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Đóng',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const Text(
              'Khoảng ngày tạo thông báo',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF344054),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Tất cả ngày'),
                  selected: !_draft.hasDateRange,
                  onSelected: (_) {
                    setState(() {
                      _draft = _draft.copyWith(clearDateRange: true);
                    });
                  },
                ),
                ChoiceChip(
                  label: const Text('Hôm nay'),
                  selected: _isRecentDays(1),
                  onSelected: (_) => _selectRecentDays(1),
                ),
                ChoiceChip(
                  label: const Text('7 ngày'),
                  selected: _isRecentDays(7),
                  onSelected: (_) => _selectRecentDays(7),
                ),
                ChoiceChip(
                  label: const Text('30 ngày'),
                  selected: _isRecentDays(30),
                  onSelected: (_) => _selectRecentDays(30),
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickDateRange,
              icon: const Icon(Icons.date_range_outlined, size: 19),
              label: Text(
                _draft.hasDateRange
                    ? '${_formatDate(_draft.startDate)} – ${_formatDate(_draft.endDate)}'
                    : 'Chọn khoảng ngày tùy chỉnh',
              ),
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                foregroundColor: const Color(0xFF344054),
                side: BorderSide(
                  color: _draft.hasDateRange
                      ? AppColors.primary
                      : const Color(0xFFD0D5DD),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Trạng thái đọc',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF344054),
              ),
            ),
            const SizedBox(height: 10),
            SegmentedButton<HostNotificationReadFilter>(
              segments: const [
                ButtonSegment(
                  value: HostNotificationReadFilter.all,
                  label: Text('Tất cả'),
                ),
                ButtonSegment(
                  value: HostNotificationReadFilter.unread,
                  label: Text('Chưa đọc'),
                ),
                ButtonSegment(
                  value: HostNotificationReadFilter.read,
                  label: Text('Đã đọc'),
                ),
              ],
              selected: {_draft.readFilter},
              onSelectionChanged: (selection) {
                setState(() {
                  _draft = _draft.copyWith(readFilter: selection.first);
                });
              },
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                textStyle: WidgetStatePropertyAll(theme.textTheme.labelMedium),
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Sắp xếp theo ngày',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF344054),
              ),
            ),
            const SizedBox(height: 10),
            SegmentedButton<HostNotificationSortOrder>(
              segments: const [
                ButtonSegment(
                  value: HostNotificationSortOrder.newest,
                  icon: Icon(Icons.arrow_downward_rounded, size: 17),
                  label: Text('Mới nhất'),
                ),
                ButtonSegment(
                  value: HostNotificationSortOrder.oldest,
                  icon: Icon(Icons.arrow_upward_rounded, size: 17),
                  label: Text('Cũ nhất'),
                ),
              ],
              selected: {_draft.sortOrder},
              onSelectionChanged: (selection) {
                setState(() {
                  _draft = _draft.copyWith(sortOrder: selection.first);
                });
              },
            ),
            const SizedBox(height: 26),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _draft = const HostNotificationFilter();
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Đặt lại'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, _draft),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Áp dụng'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

bool _sameDay(DateTime left, DateTime right) =>
    left.year == right.year &&
    left.month == right.month &&
    left.day == right.day;

String _formatDate(DateTime? date) {
  if (date == null) return '...';
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  return '${twoDigits(date.day)}/${twoDigits(date.month)}/${date.year}';
}
