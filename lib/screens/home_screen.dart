import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/category_info.dart';
import '../models/transaction.dart';
import '../providers/app_provider.dart';
import '../utils/formatters.dart';
import '../widgets/month_selector.dart';
import '../widgets/summary_cards.dart';
import '../widgets/spending_pie_chart.dart';
import '../widgets/category_tile.dart';
import '../widgets/transaction_tile.dart';
import 'account_selection_screen.dart';
import 'add_transaction_screen.dart';
import 'category_detail_screen.dart';
import 'custom_rules_screen.dart';
import 'manage_categories_screen.dart';
import 'sms_debug_screen.dart';
import 'trends_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  _TypeFilter _typeFilter = _TypeFilter.all;
  _AmountFilter _amountFilter = _AmountFilter.all;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<AppProvider>();
      p.loadAccounts();
      p.loadRules();
      p.loadCustomCategories();
      p.loadMonth(DateTime.now());
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _importSMS() async {
    final provider = context.read<AppProvider>();

    final choice = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Import SMS'),
        content: const Text(
          'Import only new messages since the last scan, or do a full re-scan of all SMS history?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('New only'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Full scan'),
          ),
        ],
      ),
    );
    if (choice == null || !mounted) return;

    final msg = await provider.importFromSMS(forceFullScan: choice);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _openAddTransaction() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
    );
  }

  void _showSyncSheet(AppProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ChangeNotifierProvider.value(
        value: provider,
        child: const _SyncSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Money Tracker'),
        actions: [
          // Accounts — badge shows how many are tracked
          Stack(
            alignment: Alignment.topRight,
            children: [
              IconButton(
                tooltip: 'Bank accounts',
                icon: const Icon(Icons.account_balance_outlined),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChangeNotifierProvider.value(
                      value: provider,
                      child: const AccountSelectionScreen(),
                    ),
                  ),
                ),
              ),
              if (provider.accounts.isNotEmpty)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${provider.accounts.where((a) => a.isTracked).length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            tooltip: 'Import from SMS',
            icon: const Icon(Icons.sms_outlined),
            onPressed: provider.loading ? null : _importSMS,
          ),
          IconButton(
            tooltip: 'Extraction rules',
            icon: const Icon(Icons.tune),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChangeNotifierProvider.value(
                  value: provider,
                  child: const CustomRulesScreen(),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Manage categories',
            icon: const Icon(Icons.category_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChangeNotifierProvider.value(
                  value: provider,
                  child: const ManageCategoriesScreen(),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Diagnose SMS',
            icon: const Icon(Icons.bug_report_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChangeNotifierProvider.value(
                  value: provider,
                  child: SmsDebugScreen(month: provider.selectedMonth),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Add transaction',
            icon: const Icon(Icons.add_circle_outline),
            onPressed: _openAddTransaction,
          ),
          IconButton(
            tooltip: provider.currentUser == null ? 'Sign in to sync' : 'Sync',
            icon: provider.currentUser != null
                ? CircleAvatar(
                    radius: 12,
                    backgroundImage: provider.currentUser!.photoURL != null
                        ? NetworkImage(provider.currentUser!.photoURL!)
                        : null,
                    backgroundColor: Colors.white24,
                    child: provider.currentUser!.photoURL == null
                        ? const Icon(Icons.person, size: 14, color: Colors.white)
                        : null,
                  )
                : const Icon(Icons.cloud_outlined),
            onPressed: () => _showSyncSheet(provider),
          ),
          const SizedBox(width: 4),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Transactions'),
            Tab(text: 'Trends'),
          ],
        ),
      ),
      body: Column(
        children: [
          MonthSelector(
            month: provider.selectedMonth,
            onPrev: () => provider.changeMonth(-1),
            onNext: () => provider.changeMonth(1),
          ),
          if (provider.loading) ...[
            LinearProgressIndicator(
              value: provider.importProgress, // null = indeterminate; 0–1 = determinate
              minHeight: 3,
              backgroundColor: const Color(0xFF4F46E5).withValues(alpha: 0.12),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF4F46E5)),
            ),
            if (provider.importStatus != null)
              Container(
                width: double.infinity,
                color: const Color(0xFF4F46E5).withValues(alpha: 0.06),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Text(
                  provider.importStatus!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF4F46E5),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _OverviewTab(
                  provider: provider,
                  onCreditTap: () {
                    setState(() => _typeFilter = _TypeFilter.received);
                    _tabs.animateTo(1);
                  },
                  onDebitTap: () {
                    setState(() => _typeFilter = _TypeFilter.spent);
                    _tabs.animateTo(1);
                  },
                ),
                _TransactionsTab(
                  provider: provider,
                  typeFilter: _typeFilter,
                  amountFilter: _amountFilter,
                  onTypeChanged: (f) => setState(() => _typeFilter = f),
                  onAmountChanged: (f) => setState(() => _amountFilter = f),
                  onClearFilters: () => setState(() {
                    _typeFilter = _TypeFilter.all;
                    _amountFilter = _AmountFilter.all;
                  }),
                ),
                const TrendsScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Overview Tab ────────────────────────────────────────────────────────────

class _OverviewTab extends StatefulWidget {
  final AppProvider provider;
  final VoidCallback? onCreditTap;
  final VoidCallback? onDebitTap;

  const _OverviewTab({
    required this.provider,
    this.onCreditTap,
    this.onDebitTap,
  });

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  final Set<String> _excludedCategories = {};

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
    final allCategoryTotals = provider.categoryTotals;
    final filteredTotals = Map<String, double>.fromEntries(
      allCategoryTotals.entries.where((e) => !_excludedCategories.contains(e.key)),
    );
    final effectiveDebit = filteredTotals.values.fold(0.0, (s, v) => s + v);

    return RefreshIndicator(
      onRefresh: () => provider.loadMonth(provider.selectedMonth),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          // Summary cards (debit reflects active categories only)
          SummaryCards(
            credit: provider.totalCredit,
            debit: effectiveDebit,
            onCreditTap: widget.onCreditTap,
            onDebitTap: widget.onDebitTap,
          ),

          // Spending chart + category filter chips
          if (allCategoryTotals.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 10),
              child: Row(
                children: [
                  const Text(
                    'Spending Overview',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF1F2937)),
                  ),
                  const Spacer(),
                  if (_excludedCategories.isNotEmpty)
                    GestureDetector(
                      onTap: () => setState(() => _excludedCategories.clear()),
                      child: Text(
                        'Reset',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500),
                      ),
                    ),
                ],
              ),
            ),

            // Category filter chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: allCategoryTotals.keys.map((cat) {
                  final excluded = _excludedCategories.contains(cat);
                  final m = categoryMeta(cat);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() {
                        if (excluded) { _excludedCategories.remove(cat); }
                        else { _excludedCategories.add(cat); }
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: excluded
                              ? Colors.grey.withValues(alpha: 0.08)
                              : m.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: excluded
                                ? Colors.grey.withValues(alpha: 0.25)
                                : m.color.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              excluded ? Icons.block_outlined : m.icon,
                              size: 12,
                              color: excluded ? Colors.grey[400] : m.color,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              cat,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: excluded ? Colors.grey[400] : m.color,
                                decoration: excluded ? TextDecoration.lineThrough : null,
                                decorationColor: Colors.grey[400],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            // Pie chart
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
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
                child: filteredTotals.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: Text('All categories hidden',
                              style: TextStyle(color: Colors.grey, fontSize: 14)),
                        ),
                      )
                    : SpendingPieChart(categoryTotals: filteredTotals),
              ),
            ),
          ],

          // Net savings (uses effectiveDebit)
          if (provider.transactions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _NetSavingsCard(
                credit: provider.totalCredit,
                debit: effectiveDebit,
              ),
            ),

          // Category list (only included categories)
          if (filteredTotals.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Text(
                'By Category',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF1F2937)),
              ),
            ),
            ...filteredTotals.entries.map((e) => CategoryTile(
                  category: e.key,
                  amount: e.value,
                  totalSpend: effectiveDebit,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChangeNotifierProvider.value(
                        value: provider,
                        child: CategoryDetailScreen(category: e.key),
                      ),
                    ),
                  ),
                )),
          ],

          if (provider.transactions.isEmpty && !provider.loading)
            _EmptyState(month: provider.selectedMonth),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _NetSavingsCard extends StatelessWidget {
  final double credit;
  final double debit;

  const _NetSavingsCard({required this.credit, required this.debit});

  @override
  Widget build(BuildContext context) {
    final net = credit - debit;
    final isPositive = net >= 0;
    final color = isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(
            isPositive ? Icons.savings_outlined : Icons.warning_amber_outlined,
            color: color,
            size: 22,
          ),
          const SizedBox(width: 12),
          Text(
            isPositive ? 'Net Savings' : 'Overspent',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          Text(
            '${isPositive ? '+' : ''}${formatAmount(net)}',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final DateTime month;

  const _EmptyState({required this.month});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Icon(Icons.account_balance_wallet_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No transactions in ${formatMonth(month)}',
            style: TextStyle(color: Colors.grey[500], fontSize: 15),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the SMS icon to import bank messages\nor + to add manually.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[400], fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ─── Transactions Tab ─────────────────────────────────────────────────────────

enum _TypeFilter { all, spent, received }

enum _AmountFilter {
  all,
  under500,
  s500to2000,
  s2000to10000,
  above10000,
}

extension _AmountFilterLabel on _AmountFilter {
  String get label {
    switch (this) {
      case _AmountFilter.all: return 'Any amount';
      case _AmountFilter.under500: return 'Under ₹500';
      case _AmountFilter.s500to2000: return '₹500 – ₹2K';
      case _AmountFilter.s2000to10000: return '₹2K – ₹10K';
      case _AmountFilter.above10000: return 'Above ₹10K';
    }
  }

  bool matches(double amount) {
    switch (this) {
      case _AmountFilter.all: return true;
      case _AmountFilter.under500: return amount < 500;
      case _AmountFilter.s500to2000: return amount >= 500 && amount < 2000;
      case _AmountFilter.s2000to10000: return amount >= 2000 && amount < 10000;
      case _AmountFilter.above10000: return amount >= 10000;
    }
  }
}

class _TransactionsTab extends StatelessWidget {
  final AppProvider provider;
  final _TypeFilter typeFilter;
  final _AmountFilter amountFilter;
  final ValueChanged<_TypeFilter> onTypeChanged;
  final ValueChanged<_AmountFilter> onAmountChanged;
  final VoidCallback onClearFilters;

  const _TransactionsTab({
    required this.provider,
    required this.typeFilter,
    required this.amountFilter,
    required this.onTypeChanged,
    required this.onAmountChanged,
    required this.onClearFilters,
  });

  List<Transaction> _filtered(List<Transaction> all) {
    return all.where((t) {
      if (typeFilter == _TypeFilter.spent && t.type != TransactionType.debit) return false;
      if (typeFilter == _TypeFilter.received && t.type != TransactionType.credit) return false;
      if (!amountFilter.matches(t.amount)) return false;
      return true;
    }).toList();
  }

  String _filteredSummary(List<Transaction> txns) {
    if (typeFilter == _TypeFilter.spent) {
      return '${formatAmount(txns.fold(0.0, (s, t) => s + t.amount))} spent';
    }
    if (typeFilter == _TypeFilter.received) {
      return '${formatAmount(txns.fold(0.0, (s, t) => s + t.amount))} received';
    }
    final out = txns.where((t) => t.type == TransactionType.debit).fold(0.0, (s, t) => s + t.amount);
    final inc = txns.where((t) => t.type == TransactionType.credit).fold(0.0, (s, t) => s + t.amount);
    if (out > 0 && inc > 0) return '${formatAmount(out)} out · ${formatAmount(inc)} in';
    if (out > 0) return '${formatAmount(out)} out';
    if (inc > 0) return '${formatAmount(inc)} in';
    return '₹0';
  }

  @override
  Widget build(BuildContext context) {
    final txns = _filtered(provider.transactions);
    final hasFilter = typeFilter != _TypeFilter.all || amountFilter != _AmountFilter.all;

    return Column(
      children: [
        // ── Filter bar ──────────────────────────────────────────────────────
        Container(
          color: const Color(0xFFF9FAFB),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Type pills
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Row(
                  children: _TypeFilter.values.map((f) {
                    final selected = typeFilter == f;
                    final label = switch (f) {
                      _TypeFilter.all => 'All',
                      _TypeFilter.spent => 'Spent',
                      _TypeFilter.received => 'Received',
                    };
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(label),
                        selected: selected,
                        onSelected: (_) => onTypeChanged(f),
                        selectedColor: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                        checkmarkColor: const Color(0xFF4F46E5),
                        labelStyle: TextStyle(
                          fontSize: 13,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                          color: selected ? const Color(0xFF4F46E5) : Colors.grey[700],
                        ),
                        side: BorderSide(
                          color: selected
                              ? const Color(0xFF4F46E5)
                              : Colors.grey.withValues(alpha: 0.3),
                        ),
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                    );
                  }).toList(),
                ),
              ),
              // Amount slab pills
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: Row(
                  children: _AmountFilter.values.map((f) {
                    final selected = amountFilter == f;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(f.label),
                        selected: selected,
                        onSelected: (_) => onAmountChanged(f),
                        selectedColor: const Color(0xFF10B981).withValues(alpha: 0.12),
                        checkmarkColor: const Color(0xFF10B981),
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                          color: selected ? const Color(0xFF047857) : Colors.grey[700],
                        ),
                        side: BorderSide(
                          color: selected
                              ? const Color(0xFF10B981)
                              : Colors.grey.withValues(alpha: 0.3),
                        ),
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),

        // ── Results count + filtered total ───────────────────────────────────
        if (!provider.loading)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Text(
                  '${txns.length} transaction${txns.length == 1 ? '' : 's'}',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
                const SizedBox(width: 6),
                Text('·', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                const SizedBox(width: 6),
                Text(
                  _filteredSummary(txns),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                ),
                const Spacer(),
                if (hasFilter)
                  GestureDetector(
                    onTap: onClearFilters,
                    child: const Text(
                      'Clear',
                      style: TextStyle(
                        color: Color(0xFF4F46E5),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),

        // ── List ─────────────────────────────────────────────────────────────
        Expanded(
          child: txns.isEmpty && !provider.loading
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.filter_list_off, size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text(
                        hasFilter
                            ? 'No transactions match this filter'
                            : 'No transactions',
                        style: TextStyle(color: Colors.grey[500], fontSize: 14),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 24),
                  itemCount: txns.length,
                  itemBuilder: (_, i) => TransactionTile(
                    transaction: txns[i],
                    onDelete: txns[i].id != null
                        ? () => provider.deleteTransaction(txns[i].id!)
                        : null,
                  ),
                ),
        ),
      ],
    );
  }
}

// ─── Sync bottom sheet ────────────────────────────────────────────────────────

class _SyncSheet extends StatefulWidget {
  const _SyncSheet();

  @override
  State<_SyncSheet> createState() => _SyncSheetState();
}

class _SyncSheetState extends State<_SyncSheet> {
  String? _statusMessage;

  Future<void> _run(Future<String> Function() action) async {
    final msg = await action();
    if (mounted) setState(() => _statusMessage = msg);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final user = provider.currentUser;
    final syncing = provider.syncing;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          if (user == null) ...[
            const Icon(Icons.cloud_sync_outlined, size: 48, color: Color(0xFF4F46E5)),
            const SizedBox(height: 12),
            const Text(
              'Sync across devices',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Sign in with Google to back up your transactions and restore them on a new phone.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.login),
              label: const Text('Sign in with Google'),
              onPressed: () async {
                final ok = await provider.signInWithGoogle();
                if (!ok && mounted) {
                  setState(() => _statusMessage = 'Sign-in cancelled or failed.');
                }
              },
            ),
          ] else ...[
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundImage: user.photoURL != null
                      ? NetworkImage(user.photoURL!)
                      : null,
                  backgroundColor: const Color(0xFF4F46E5),
                  child: user.photoURL == null
                      ? const Icon(Icons.person, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.displayName ?? 'Signed in',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                      Text(user.email ?? '',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (provider.lastSyncedAt != null)
              Text(
                'Last synced: ${_formatTs(provider.lastSyncedAt!)}',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            const SizedBox(height: 20),
            FilledButton.icon(
              icon: syncing
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.cloud_upload_outlined),
              label: const Text('Push to cloud'),
              onPressed: syncing ? null : () => _run(provider.pushToCloud),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              icon: syncing
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.cloud_download_outlined),
              label: const Text('Pull from cloud'),
              onPressed: syncing ? null : () => _run(provider.pullFromCloud),
            ),
            if (_statusMessage != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(_statusMessage!,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF4F46E5))),
              ),
            ],
            const SizedBox(height: 16),
            TextButton(
              onPressed: () async {
                final nav = Navigator.of(context);
                await provider.signOut();
                if (mounted) nav.pop();
              },
              child: Text('Sign out', style: TextStyle(color: Colors.grey[500])),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTs(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
