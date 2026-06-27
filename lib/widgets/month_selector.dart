import 'package:flutter/material.dart';
import '../utils/formatters.dart';

class MonthSelector extends StatelessWidget {
  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const MonthSelector({
    super.key,
    required this.month,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final isCurrentMonth = month.year == DateTime.now().year &&
        month.month == DateTime.now().month;

    return Container(
      color: const Color(0xFF4F46E5),
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.white70, size: 28),
            onPressed: onPrev,
          ),
          const SizedBox(width: 8),
          Text(
            formatMonth(month),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              Icons.chevron_right,
              color: isCurrentMonth ? Colors.white24 : Colors.white70,
              size: 28,
            ),
            onPressed: isCurrentMonth ? null : onNext,
          ),
        ],
      ),
    );
  }
}
