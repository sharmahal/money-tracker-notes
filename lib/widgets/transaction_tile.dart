import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/category_info.dart';
import '../models/custom_rule.dart';
import '../models/transaction.dart';
import '../providers/app_provider.dart';
import '../screens/add_rule_screen.dart';
import '../screens/manage_categories_screen.dart';
import '../utils/formatters.dart';

class TransactionTile extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback? onDelete;

  const TransactionTile({super.key, required this.transaction, this.onDelete});

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TransactionDetailSheet(transaction: transaction),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCredit = transaction.type == TransactionType.credit;
    final meta = categoryMeta(transaction.category);

    return Dismissible(
      key: Key('txn-${transaction.id}'),
      direction: onDelete != null ? DismissDirection.endToStart : DismissDirection.none,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red[50],
        child: const Icon(Icons.delete_outline, color: Colors.red),
      ),
      onDismissed: (_) => onDelete?.call(),
      child: InkWell(
        onTap: () => _showDetail(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: meta.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isCredit ? Icons.arrow_downward_rounded : meta.icon,
                  color: isCredit ? const Color(0xFF10B981) : meta.color,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.merchant == 'Unknown'
                          ? transaction.subCategory
                          : transaction.merchant,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${transaction.subCategory} · ${formatDate(transaction.date)}',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
              ),
              Text(
                '${isCredit ? '+' : '-'}${formatAmount(transaction.amount)}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: isCredit ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: Colors.grey[300], size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Quick categorize sheet ───────────────────────────────────────────────────

class _QuickCategorizeSheet extends StatefulWidget {
  final Transaction transaction;
  const _QuickCategorizeSheet({required this.transaction});

  @override
  State<_QuickCategorizeSheet> createState() => _QuickCategorizeSheetState();
}

class _QuickCategorizeSheetState extends State<_QuickCategorizeSheet> {
  late final TextEditingController _keywordCtrl;
  late final TextEditingController _subCatCtrl;
  String? _selectedCategory;
  bool _saving = false;

  String get _displayName => widget.transaction.merchant == 'Unknown'
      ? widget.transaction.subCategory
      : widget.transaction.merchant;

  @override
  void initState() {
    super.initState();
    _keywordCtrl = TextEditingController(text: _displayName);
    _subCatCtrl = TextEditingController(text: _displayName);
  }

  @override
  void dispose() {
    _keywordCtrl.dispose();
    _subCatCtrl.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _selectedCategory != null &&
      _keywordCtrl.text.trim().isNotEmpty &&
      _subCatCtrl.text.trim().isNotEmpty;

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    final rule = CustomRule.categorization(
      keywords: [_keywordCtrl.text.trim()],
      category: _selectedCategory!,
      subCategory: _subCatCtrl.text.trim(),
    );
    await context.read<AppProvider>().addRule(rule);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              'Categorize "$_displayName"',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'SMS messages containing this keyword will be categorised as:',
              style: TextStyle(fontSize: 13, color: Colors.grey[500], height: 1.4),
            ),

            const SizedBox(height: 16),

            // Keyword field
            TextField(
              controller: _keywordCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Keyword in SMS',
                prefixIcon: const Icon(Icons.search, size: 18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Category grid
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...allCategories.map((cat) {
                  final m = categoryMeta(cat);
                  final selected = _selectedCategory == cat;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? m.color.withValues(alpha: 0.15)
                            : const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected ? m.color : const Color(0xFFE5E7EB),
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(m.icon,
                              size: 15,
                              color: selected ? m.color : Colors.grey[500]),
                          const SizedBox(width: 6),
                          Text(
                            cat,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight:
                                  selected ? FontWeight.w600 : FontWeight.normal,
                              color: selected ? m.color : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                GestureDetector(
                  onTap: () async {
                    final provider = context.read<AppProvider>();
                    await Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(
                        builder: (_) => ChangeNotifierProvider.value(
                          value: provider,
                          child: const ManageCategoriesScreen(),
                        ),
                      ),
                    );
                    setState(() {}); // refresh grid after returning
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_circle_outline, size: 15, color: Color(0xFF4F46E5)),
                        SizedBox(width: 6),
                        Text(
                          'New category',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4F46E5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Sub-category (shown after category is selected)
            if (_selectedCategory != null) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _subCatCtrl,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Sub-category label',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: Color(0xFF4F46E5), width: 2),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),

            FilledButton(
              onPressed: _canSave && !_saving ? _save : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: const Color(0xFF4F46E5),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Save Rule',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Applies instantly — no re-import needed',
                style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Detail sheet ─────────────────────────────────────────────────────────────

class _RecategorizeSheet extends StatefulWidget {
  final Transaction transaction;
  const _RecategorizeSheet({required this.transaction});

  @override
  State<_RecategorizeSheet> createState() => _RecategorizeSheetState();
}

class _RecategorizeSheetState extends State<_RecategorizeSheet> {
  late String _selectedCategory;
  late final TextEditingController _subCatCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.transaction.category;
    _subCatCtrl = TextEditingController(text: widget.transaction.subCategory);
  }

  @override
  void dispose() {
    _subCatCtrl.dispose();
    super.dispose();
  }

  bool get _canSave => _subCatCtrl.text.trim().isNotEmpty;

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    await context.read<AppProvider>().recategorizeTransaction(
          widget.transaction.id!,
          _selectedCategory,
          _subCatCtrl.text.trim(),
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Change category',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              'Only this transaction is affected — no rule is created.',
              style: TextStyle(fontSize: 13, color: Colors.grey[500], height: 1.4),
            ),
            const SizedBox(height: 16),

            // Category grid
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: allCategories.map((cat) {
                final m = categoryMeta(cat);
                final selected = _selectedCategory == cat;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? m.color.withValues(alpha: 0.15)
                          : const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected ? m.color : const Color(0xFFE5E7EB),
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(m.icon,
                            size: 15,
                            color: selected ? m.color : Colors.grey[500]),
                        const SizedBox(width: 6),
                        Text(
                          cat,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                selected ? FontWeight.w600 : FontWeight.normal,
                            color: selected ? m.color : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),
            TextField(
              controller: _subCatCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Sub-category label',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _canSave && !_saving ? _save : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: const Color(0xFF4F46E5),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Save',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

void _openRecategorize(BuildContext context, Transaction t) {
  final provider = context.read<AppProvider>();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ChangeNotifierProvider.value(
      value: provider,
      child: _RecategorizeSheet(transaction: t),
    ),
  );
}

void _openQuickCategorize(BuildContext context, Transaction t) {
  final provider = context.read<AppProvider>();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ChangeNotifierProvider.value(
      value: provider,
      child: _QuickCategorizeSheet(transaction: t),
    ),
  );
}

class _TransactionDetailSheet extends StatelessWidget {
  final Transaction t;
  const _TransactionDetailSheet({required Transaction transaction})
      : t = transaction;

  @override
  Widget build(BuildContext context) {
    final isCredit = t.type == TransactionType.credit;
    final meta = categoryMeta(t.category);
    final amountColor = isCredit ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    final rawMsg = t.rawMessage;

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 4),

            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  // Amount + merchant header
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: meta.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(meta.icon, color: meta.color, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.merchant == 'Unknown' ? t.subCategory : t.merchant,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              formatFullDate(t.date),
                              style: TextStyle(color: Colors.grey[500], fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${isCredit ? '+' : '-'}${formatAmount(t.amount)}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: amountColor,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                  const Divider(height: 1),
                  const SizedBox(height: 16),

                  // Category row
                  _DetailRow(
                    label: 'Category',
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: meta.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            t.category,
                            style: TextStyle(
                              color: meta.color,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '→ ${t.subCategory}',
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Type row
                  _DetailRow(
                    label: 'Type',
                    child: Text(
                      isCredit ? 'Credit (money in)' : 'Debit (money out)',
                      style: TextStyle(
                        color: amountColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),

                  // Recategorize this transaction only
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => _openRecategorize(context, t),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Change category (this transaction only)'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF4F46E5),
                      side: const BorderSide(color: Color(0xFF4F46E5)),
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),

                  // Quick categorize (creates a rule for all future imports)
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _openQuickCategorize(context, t),
                    icon: const Icon(Icons.sell_outlined, size: 16),
                    label: const Text('Categorize all transactions like this'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF10B981),
                      side: const BorderSide(color: Color(0xFF10B981)),
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),

                  // Original SMS message
                  if (rawMsg != null) ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Text(
                          'Original SMS',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: rawMsg));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('SMS copied to clipboard'),
                                duration: Duration(seconds: 1),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          child: Row(
                            children: [
                              Icon(Icons.copy, size: 14, color: Colors.grey[400]),
                              const SizedBox(width: 4),
                              Text(
                                'Copy',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[400],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Text(
                        rawMsg,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF374151),
                          height: 1.5,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 16),
                    Text(
                      'No original SMS — this was added manually.',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],

                  // ── Create Rule button ─────────────────────────────────────
                  if (rawMsg != null) ...[
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChangeNotifierProvider.value(
                            value: context.read<AppProvider>(),
                            child: AddRuleScreen(rawMessage: rawMsg),
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.tune, size: 16),
                      label: const Text('Create extraction rule from this SMS'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF4F46E5),
                        side: const BorderSide(color: Color(0xFF4F46E5)),
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final Widget child;
  const _DetailRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF9CA3AF),
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}
