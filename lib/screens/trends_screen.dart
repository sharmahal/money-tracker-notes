import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/category_info.dart';
import '../models/transaction.dart';
import '../providers/app_provider.dart';
import '../utils/formatters.dart';

class TrendsScreen extends StatefulWidget {
  const TrendsScreen({super.key});

  @override
  State<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends State<TrendsScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // Independent, combinable filters
  TransactionType? _typeFilter;   // null = all, debit = spent, credit = received
  bool _above10k = false;
  bool _byCategory = false;
  String _selectedCategory = 'Food';

  List<({DateTime month, List<Transaction> transactions})> _history = [];
  bool _loading = true;
  int _touchedBar = -1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _touchedBar = -1; });
    final data = await context.read<AppProvider>().getHistoryMonths(6);
    if (mounted) setState(() { _history = data; _loading = false; });
  }

  double _valueFor(List<Transaction> txns) {
    return txns.where((t) {
      if (_typeFilter != null && t.type != _typeFilter) return false;
      if (_byCategory && t.category != _selectedCategory) return false;
      if (_above10k && t.amount < 10000) return false;
      return true;
    }).fold(0.0, (s, t) => s + t.amount);
  }

  Color get _barColor {
    if (_byCategory) return categoryMeta(_selectedCategory).color;
    if (_typeFilter == TransactionType.credit) return const Color(0xFF10B981);
    if (_typeFilter == TransactionType.debit) return const Color(0xFFEF4444);
    if (_above10k) return const Color(0xFFF59E0B);
    return const Color(0xFF6366F1);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final values = _history.map((h) => _valueFor(h.transactions)).toList();
    final maxVal = values.isEmpty ? 1.0 : values.reduce((a, b) => a > b ? a : b);
    final total = values.fold(0.0, (a, b) => a + b);
    final activeMonths = values.where((v) => v > 0).length;
    final avg = activeMonths == 0 ? 0.0 : total / activeMonths;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        children: [
          // ── Filter bar ─────────────────────────────────────────────────────
          _FilterBar(
            typeFilter: _typeFilter,
            above10k: _above10k,
            byCategory: _byCategory,
            onTypeChanged: (t) => setState(() { _typeFilter = t; _touchedBar = -1; }),
            onAbove10kChanged: (v) => setState(() { _above10k = v; _touchedBar = -1; }),
            onByCategoryChanged: (v) => setState(() { _byCategory = v; _touchedBar = -1; }),
          ),

          // ── Category picker (only when byCategory is active) ───────────────
          if (_byCategory) ...[
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: allCategories.map((cat) {
                  final m = categoryMeta(cat);
                  final sel = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() {
                        if (_selectedCategory == cat) {
                          _byCategory = false;
                        } else {
                          _selectedCategory = cat;
                        }
                        _touchedBar = -1;
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: sel ? m.color : m.color.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(m.icon, size: 14, color: sel ? Colors.white : m.color),
                            const SizedBox(width: 5),
                            Text(cat,
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: sel ? Colors.white : m.color)),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          const SizedBox(height: 20),

          // ── Summary card ───────────────────────────────────────────────────
          if (!_loading && _history.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: _barColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _barColor.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('6-month total',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        const SizedBox(height: 4),
                        Text(formatAmount(total),
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: _barColor,
                                letterSpacing: -0.5)),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 40, color: _barColor.withValues(alpha: 0.2)),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activeMonths > 0 ? 'avg / month ($activeMonths mo)' : 'avg / month',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 4),
                        Text(formatAmount(avg),
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: _barColor,
                                letterSpacing: -0.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 24),

          // ── Bar chart ──────────────────────────────────────────────────────
          if (_loading)
            const SizedBox(
              height: 220,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (_history.isEmpty)
            const SizedBox(
              height: 120,
              child: Center(
                  child: Text('No data yet — import some SMS first',
                      style: TextStyle(color: Colors.grey))),
            )
          else
            Container(
              padding: const EdgeInsets.fromLTRB(8, 20, 8, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  AnimatedOpacity(
                    opacity: _touchedBar >= 0 && _touchedBar < _history.length ? 1 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: _touchedBar >= 0 && _touchedBar < _history.length
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  formatMonth(_history[_touchedBar].month),
                                  style: TextStyle(
                                      fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  formatAmount(values[_touchedBar]),
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: _barColor),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox(height: 37),
                  ),

                  SizedBox(
                    height: 180,
                    child: BarChart(
                      BarChartData(
                        maxY: maxVal * 1.25,
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipColor: (_) => Colors.transparent,
                            tooltipPadding: EdgeInsets.zero,
                            getTooltipItem: (_, __, ___, ____) => null,
                          ),
                          touchCallback: (event, response) {
                            if (event is! FlTapUpEvent) return;
                            final idx = response?.spot?.touchedBarGroupIndex ?? -1;
                            setState(() => _touchedBar = _touchedBar == idx ? -1 : idx);
                          },
                        ),
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 28,
                              getTitlesWidget: (v, _) {
                                final i = v.toInt();
                                if (i < 0 || i >= _history.length) return const SizedBox();
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    _shortMonth(_history[i].month),
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: i == _touchedBar ? _barColor : Colors.grey[500],
                                        fontWeight: i == _touchedBar ? FontWeight.w700 : FontWeight.normal),
                                  ),
                                );
                              },
                            ),
                          ),
                          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        gridData: const FlGridData(show: false),
                        barGroups: List.generate(_history.length, (i) {
                          final isTouched = i == _touchedBar;
                          return BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: values[i],
                                color: isTouched ? _barColor : _barColor.withValues(alpha: 0.5),
                                width: 32,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                              ),
                            ],
                          );
                        }),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 24),

          // ── Month-by-month breakdown list ──────────────────────────────────
          if (!_loading && _history.isNotEmpty) ...[
            const Text('Month breakdown',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
            const SizedBox(height: 12),
            ...List.generate(_history.length, (i) {
              final h = _history[_history.length - 1 - i];
              final v = _valueFor(h.transactions);
              final pct = maxVal > 0 ? v / maxVal : 0.0;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 1)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(formatMonth(h.month),
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                        const Spacer(),
                        Text(formatAmount(v),
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: _barColor)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Stack(
                      children: [
                        Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: _barColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: pct,
                          child: Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: _barColor,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  String _shortMonth(DateTime m) {
    const names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return names[m.month - 1];
  }
}

// ── Filter bar ────────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final TransactionType? typeFilter;
  final bool above10k;
  final bool byCategory;
  final ValueChanged<TransactionType?> onTypeChanged;
  final ValueChanged<bool> onAbove10kChanged;
  final ValueChanged<bool> onByCategoryChanged;

  const _FilterBar({
    required this.typeFilter,
    required this.above10k,
    required this.byCategory,
    required this.onTypeChanged,
    required this.onAbove10kChanged,
    required this.onByCategoryChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Row 1: type (mutually exclusive radio)
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _TypeChip(
              label: 'All',
              icon: Icons.swap_vert,
              value: null,
              selected: typeFilter,
              onTap: onTypeChanged,
            ),
            _TypeChip(
              label: 'Spent',
              icon: Icons.arrow_upward_rounded,
              value: TransactionType.debit,
              selected: typeFilter,
              onTap: onTypeChanged,
            ),
            _TypeChip(
              label: 'Received',
              icon: Icons.arrow_downward_rounded,
              value: TransactionType.credit,
              selected: typeFilter,
              onTap: onTypeChanged,
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Row 2: independent toggles
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ToggleChip(
              label: 'By Category',
              icon: Icons.label_outline,
              active: byCategory,
              activeColor: const Color(0xFF6366F1),
              onTap: () => onByCategoryChanged(!byCategory),
            ),
            _ToggleChip(
              label: 'Above ₹10K',
              icon: Icons.trending_up,
              active: above10k,
              activeColor: const Color(0xFFF59E0B),
              onTap: () => onAbove10kChanged(!above10k),
            ),
          ],
        ),
      ],
    );
  }
}

// Radio chip: one of All / Spent / Received
class _TypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final TransactionType? value;
  final TransactionType? selected;
  final ValueChanged<TransactionType?> onTap;

  const _TypeChip({
    required this.label,
    required this.icon,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sel = selected == value;
    final color = value == TransactionType.debit
        ? const Color(0xFFEF4444)
        : value == TransactionType.credit
            ? const Color(0xFF10B981)
            : const Color(0xFF6366F1);
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? color : Colors.grey.withValues(alpha: 0.3)),
          boxShadow: sel
              ? [BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 2))]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: sel ? Colors.white : Colors.grey[600]),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: sel ? Colors.white : Colors.grey[700])),
          ],
        ),
      ),
    );
  }
}

// Independent toggle chip
class _ToggleChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  const _ToggleChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? activeColor.withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? activeColor : Colors.grey.withValues(alpha: 0.3),
            width: active ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: active ? activeColor : Colors.grey[600]),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: active ? activeColor : Colors.grey[700])),
          ],
        ),
      ),
    );
  }
}
