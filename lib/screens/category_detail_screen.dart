import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/category_info.dart';
import '../providers/app_provider.dart';
import '../utils/formatters.dart';
import '../widgets/transaction_tile.dart';

enum _AmountFilter { all, under500, s500to2000, s2000to10000, above10000 }

extension _AmountFilterX on _AmountFilter {
  String get label => switch (this) {
        _AmountFilter.all => 'Any',
        _AmountFilter.under500 => '< ₹500',
        _AmountFilter.s500to2000 => '₹500–2K',
        _AmountFilter.s2000to10000 => '₹2K–10K',
        _AmountFilter.above10000 => '> ₹10K',
      };

  bool matches(double amount) => switch (this) {
        _AmountFilter.all => true,
        _AmountFilter.under500 => amount < 500,
        _AmountFilter.s500to2000 => amount >= 500 && amount < 2000,
        _AmountFilter.s2000to10000 => amount >= 2000 && amount < 10000,
        _AmountFilter.above10000 => amount >= 10000,
      };
}

class CategoryDetailScreen extends StatefulWidget {
  final String category;

  const CategoryDetailScreen({super.key, required this.category});

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {
  String? _selectedSub;
  _AmountFilter _amountFilter = _AmountFilter.all;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final meta = categoryMeta(widget.category);
    final subTotals = provider.subCategoryTotals(widget.category);
    final total = subTotals.values.fold(0.0, (a, b) => a + b);

    final rawTransactions = _selectedSub != null
        ? provider.transactionsForSubCategory(widget.category, _selectedSub!)
        : provider.transactionsForCategory(widget.category);
    final displayedTransactions = rawTransactions
        .where((t) => _amountFilter.matches(t.amount))
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      appBar: AppBar(
        title: Row(
          children: [
            Icon(meta.icon, size: 20, color: Colors.white),
            const SizedBox(width: 8),
            Text(widget.category),
          ],
        ),
      ),
      body: CustomScrollView(
        slivers: [
          // Total header
          SliverToBoxAdapter(
            child: Container(
              color: const Color(0xFF4F46E5),
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Spent',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatAmount(total),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Sub-category bar chart
          if (subTotals.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Breakdown',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _SubCategoryChart(
                      subTotals: subTotals,
                      total: total,
                      color: meta.color,
                      selected: _selectedSub,
                      onSelect: (sub) => setState(() {
                        _selectedSub = _selectedSub == sub ? null : sub;
                      }),
                    ),
                  ],
                ),
              ),
            ),

          // Sub-category pills
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Pill(
                    label: 'All',
                    selected: _selectedSub == null,
                    color: meta.color,
                    onTap: () => setState(() => _selectedSub = null),
                  ),
                  ...subTotals.keys.map((sub) => _Pill(
                        label: sub,
                        selected: _selectedSub == sub,
                        color: meta.color,
                        onTap: () => setState(() {
                          _selectedSub = _selectedSub == sub ? null : sub;
                        }),
                      )),
                ],
              ),
            ),
          ),

          // Amount slab filter
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: _AmountFilter.values.map((f) {
                  final selected = _amountFilter == f;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(f.label),
                      selected: selected,
                      onSelected: (_) => setState(() => _amountFilter = f),
                      selectedColor: meta.color.withValues(alpha: 0.15),
                      checkmarkColor: meta.color,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                        color: selected ? meta.color : Colors.grey[700],
                      ),
                      side: BorderSide(
                        color: selected ? meta.color : Colors.grey.withValues(alpha: 0.3),
                      ),
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Transactions header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Text(
                    _selectedSub != null
                        ? '$_selectedSub transactions'
                        : 'All transactions',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${displayedTransactions.length} items',
                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                  ),
                ],
              ),
            ),
          ),

          // Transaction list
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => TransactionTile(
                transaction: displayedTransactions[i],
                onDelete: displayedTransactions[i].id != null
                    ? () => provider.deleteTransaction(displayedTransactions[i].id!)
                    : null,
              ),
              childCount: displayedTransactions.length,
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

class _SubCategoryChart extends StatelessWidget {
  final Map<String, double> subTotals;
  final double total;
  final Color color;
  final String? selected;
  final void Function(String) onSelect;

  const _SubCategoryChart({
    required this.subTotals,
    required this.total,
    required this.color,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final entries = subTotals.entries.toList();
    final maxVal = entries.isEmpty ? 1.0 : entries.first.value;

    return Container(
      padding: const EdgeInsets.all(16),
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
        children: entries.take(8).map((e) {
          final pct = maxVal > 0 ? e.value / maxVal : 0.0;
          final isSelected = selected == e.key;
          return GestureDetector(
            onTap: () => onSelect(e.key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
              decoration: BoxDecoration(
                color: isSelected ? color.withValues(alpha: 0.08) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 110,
                    child: Text(
                      e.key,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? color : const Color(0xFF374151),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Stack(
                      children: [
                        Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: pct,
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: isSelected ? color : color.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    formatAmount(e.value),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? color : const Color(0xFF1F2937),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _Pill({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : color,
          ),
        ),
      ),
    );
  }
}
