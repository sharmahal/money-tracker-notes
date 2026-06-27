import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/category_info.dart';
import '../utils/formatters.dart';

class SpendingPieChart extends StatefulWidget {
  final Map<String, double> categoryTotals;

  const SpendingPieChart({super.key, required this.categoryTotals});

  @override
  State<SpendingPieChart> createState() => _SpendingPieChartState();
}

class _SpendingPieChartState extends State<SpendingPieChart> {
  int _touched = -1;

  @override
  Widget build(BuildContext context) {
    if (widget.categoryTotals.isEmpty) {
      return const SizedBox(
        height: 160,
        child: Center(
          child: Text(
            'No spending data this month',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ),
      );
    }

    final total = widget.categoryTotals.values.fold(0.0, (a, b) => a + b);
    final entries = widget.categoryTotals.entries.toList();

    return SizedBox(
      height: 200,
      child: Row(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                pieTouchData: PieTouchData(
                  touchCallback: (event, response) {
                    if (event is! FlTapUpEvent) return;
                    final idx = response?.touchedSection?.touchedSectionIndex ?? -1;
                    setState(() => _touched = _touched == idx ? -1 : idx);
                  },
                ),
                sections: List.generate(entries.length, (i) {
                  final entry = entries[i];
                  final meta = categoryMeta(entry.key);
                  final isTouched = i == _touched;
                  return PieChartSectionData(
                    value: entry.value,
                    color: meta.color,
                    radius: isTouched ? 70 : 58,
                    title: isTouched ? formatPercent(entry.value, total) : '',
                    titleStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  );
                }),
                sectionsSpace: 2,
                centerSpaceRadius: 36,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: entries.take(6).map((e) {
              final meta = categoryMeta(e.key);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: meta.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      e.key,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }
}
