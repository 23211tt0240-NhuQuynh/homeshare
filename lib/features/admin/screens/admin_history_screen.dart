import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../services/admin_service.dart';

class AdminHistoryScreen extends ConsumerWidget {
  const AdminHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(adminTransactionsHistoryProvider);
    final transactions = transactionsAsync.value ?? [];
    final currencyFormatter = NumberFormat('#,###', 'vi_VN');
    final dateFormatter = DateFormat('HH:mm dd/MM/yyyy');

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        title: const Text(
          'LỊCH SỬ GIAO DỊCH & ĐỐI SOÁT',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Color(0xFF101828),
          ),
        ),
      ),
      body: transactions.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history_toggle_off_rounded, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text(
                    'Chưa có lịch sử giao dịch nào được ghi nhận',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: transactions.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = transactions[index];
                final isIncome = item.isIncome;

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFEAECF0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isIncome ? const Color(0xFFECFDF3) : const Color(0xFFFEF3F2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                          color: isIncome ? const Color(0xFF12B76A) : const Color(0xFFF04438),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF101828),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              item.subtitle,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF667085)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              dateFormatter.format(item.timestamp),
                              style: const TextStyle(fontSize: 11, color: Color(0xFF98A2B3)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${isIncome ? '+' : '-'}${currencyFormatter.format(item.amount)} đ',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: isIncome ? const Color(0xFF027A48) : const Color(0xFFB42318),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF2F4F7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.type,
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475467)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
