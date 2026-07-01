import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/custom_rule.dart';
import '../models/transaction.dart';
import '../models/category_info.dart';
import '../providers/app_provider.dart';
import '../services/sms_service.dart';
import '../utils/formatters.dart';

class SmsDebugScreen extends StatefulWidget {
  final DateTime initialMonth;

  const SmsDebugScreen({super.key, required this.initialMonth});

  @override
  State<SmsDebugScreen> createState() => _SmsDebugScreenState();
}

class _SmsDebugScreenState extends State<SmsDebugScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  List<SmsDebugEntry>? _entries;
  List<Transaction>? _deleted;
  bool _loading = true;
  String? _error;

  // null = all months
  late DateTime? _month;

  @override
  void initState() {
    super.initState();
    _month = widget.initialMonth;
    _tabs = TabController(length: 4, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        SmsService().diagnose(month: _month),
        context.read<AppProvider>().getDeletedTransactions(),
      ]);
      setState(() {
        _entries = results[0] as List<SmsDebugEntry>;
        _deleted = results[1] as List<Transaction>;
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _prevMonth() {
    setState(() {
      if (_month == null) {
        _month = DateTime(DateTime.now().year, DateTime.now().month);
      } else {
        _month = DateTime(_month!.year, _month!.month - 1);
      }
    });
    _load();
  }

  void _nextMonth() {
    if (_month == null) return;
    final now = DateTime.now();
    final next = DateTime(_month!.year, _month!.month + 1);
    if (next.isAfter(DateTime(now.year, now.month))) return;
    setState(() => _month = next);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final all = _entries ?? [];
    final parsed = all.where((e) => e.isParsed).toList();
    final skipped = all.where((e) => !e.isBank || (e.isBank && !e.isParsed)).toList();
    final deleted = _deleted ?? [];

    final now = DateTime.now();
    final isCurrentMonth = _month != null &&
        _month!.year == now.year && _month!.month == now.month;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('SMS Diagnostic'),
            // Month navigation row
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: _prevMonth,
                  child: const Icon(Icons.chevron_left, color: Colors.white70, size: 18),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () {
                    setState(() => _month = null);
                    _load();
                  },
                  child: Text(
                    _month == null ? 'All months' : formatMonth(_month!),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: isCurrentMonth ? null : _nextMonth,
                  child: Icon(Icons.chevron_right,
                      color: isCurrentMonth ? Colors.white24 : Colors.white70, size: 18),
                ),
              ],
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(text: 'All (${all.length})'),
            Tab(text: 'Parsed (${parsed.length})'),
            Tab(text: 'Skipped (${skipped.length})'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Deleted'),
                  if (deleted.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.red[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${deleted.length}',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : TabBarView(
                  controller: _tabs,
                  children: [
                    _SmsListView(entries: all),
                    _SmsListView(entries: parsed),
                    _SmsListView(entries: skipped, showCreateRule: true),
                    _DeletedListView(
                      transactions: deleted,
                      onRestore: (id) async {
                        await context.read<AppProvider>().restoreTransaction(id);
                        _load();
                      },
                      onPermanentDelete: (id) async {
                        await context.read<AppProvider>().permanentlyDeleteFromDeleted(id);
                        _load();
                      },
                    ),
                  ],
                ),
    );
  }
}

// ─── SMS debug list ───────────────────────────────────────────────────────────

class _SmsListView extends StatelessWidget {
  final List<SmsDebugEntry> entries;
  final bool showCreateRule;
  const _SmsListView({required this.entries, this.showCreateRule = false});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Center(child: Text('No messages', style: TextStyle(color: Colors.grey)));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: entries.length,
      itemBuilder: (_, i) => _SmsDebugTile(entry: entries[i], showCreateRule: showCreateRule),
    );
  }
}

class _SmsDebugTile extends StatefulWidget {
  final SmsDebugEntry entry;
  final bool showCreateRule;
  const _SmsDebugTile({required this.entry, this.showCreateRule = false});

  @override
  State<_SmsDebugTile> createState() => _SmsDebugTileState();
}

class _SmsDebugTileState extends State<_SmsDebugTile> {
  bool _expanded = false;

  Color get _statusColor {
    if (widget.entry.isParsed) return const Color(0xFF10B981);
    if (widget.entry.isBank) return const Color(0xFFF59E0B);
    return const Color(0xFF9CA3AF);
  }

  IconData get _statusIcon {
    if (widget.entry.isParsed) return Icons.check_circle_outline;
    if (widget.entry.isBank) return Icons.warning_amber_outlined;
    return Icons.remove_circle_outline;
  }

  String get _statusLabel {
    if (widget.entry.isParsed) {
      final sign = widget.entry.type?.name == 'credit' ? '+' : '-';
      return '$sign₹${widget.entry.amount?.toStringAsFixed(0)}  •  ${widget.entry.merchant}';
    }
    if (widget.entry.isBank) return 'Bank SMS but: ${widget.entry.filterReason}';
    return widget.entry.filterReason ?? 'Skipped';
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: e.body));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Copied SMS body'), duration: Duration(seconds: 1)),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _statusColor.withValues(alpha: 0.3)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_statusIcon, color: _statusColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(e.sender,
                              style: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w700,
                                  color: Color(0xFF4F46E5), fontFamily: 'monospace')),
                        ),
                        const SizedBox(width: 8),
                        Text(formatDate(e.date),
                            style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(_statusLabel,
                        style: TextStyle(
                            color: _statusColor, fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                      e.body.length > 80 && !_expanded
                          ? '${e.body.substring(0, 80)}…'
                          : e.body,
                      style: TextStyle(fontSize: 12, color: Colors.grey[700], height: 1.4),
                    ),
                    if (_expanded && widget.showCreateRule) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: () => _showCreateRuleSheet(context, e.body),
                          icon: const Icon(Icons.add_circle_outline, size: 15),
                          label: const Text('Create Extraction Rule',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF4F46E5),
                            side: const BorderSide(color: Color(0xFF4F46E5)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.grey[400], size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCreateRuleSheet(BuildContext context, String smsBody) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateExtractionRuleSheet(smsBody: smsBody),
    );
  }
}

// ─── Create extraction rule bottom sheet ─────────────────────────────────────

class _CreateExtractionRuleSheet extends StatefulWidget {
  final String smsBody;
  const _CreateExtractionRuleSheet({required this.smsBody});

  @override
  State<_CreateExtractionRuleSheet> createState() => _CreateExtractionRuleSheetState();
}

class _CreateExtractionRuleSheetState extends State<_CreateExtractionRuleSheet> {
  final _prefixCtrl = TextEditingController();
  final _terminatorCtrl = TextEditingController();
  final _keywordsCtrl = TextEditingController();
  String _forcedType = 'debit';
  bool _saving = false;
  String? _previewResult;

  @override
  void dispose() {
    _prefixCtrl.dispose();
    _terminatorCtrl.dispose();
    _keywordsCtrl.dispose();
    super.dispose();
  }

  void _updatePreview() {
    final rule = CustomRule.smsExtraction(
      prefix: _prefixCtrl.text.trim().isEmpty ? null : _prefixCtrl.text.trim(),
      terminator: _terminatorCtrl.text.trim().isEmpty ? null : _terminatorCtrl.text.trim(),
      keywords: _keywordsCtrl.text
          .split(',')
          .map((k) => k.trim())
          .where((k) => k.isNotEmpty)
          .toList(),
      forcedType: _forcedType,
    );
    final amount = rule.extractAmount(widget.smsBody);
    setState(() {
      _previewResult = amount != null
          ? 'Extracted: ${_forcedType == 'debit' ? '-' : '+'}${amount.toStringAsFixed(2)}'
          : 'No amount found — adjust prefix/terminator';
    });
  }

  Future<void> _save() async {
    if (_prefixCtrl.text.trim().isEmpty && _terminatorCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter at least a prefix or terminator')),
      );
      return;
    }
    setState(() => _saving = true);
    final rule = CustomRule.smsExtraction(
      prefix: _prefixCtrl.text.trim().isEmpty ? null : _prefixCtrl.text.trim(),
      terminator: _terminatorCtrl.text.trim().isEmpty ? null : _terminatorCtrl.text.trim(),
      keywords: _keywordsCtrl.text
          .split(',')
          .map((k) => k.trim())
          .where((k) => k.isNotEmpty)
          .toList(),
      forcedType: _forcedType,
    );
    await context.read<AppProvider>().addRule(rule);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            const Text('Create Extraction Rule',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('Teach CashTrace how to read amounts from this message format.',
                style: TextStyle(fontSize: 13, color: Colors.grey[500])),
            const SizedBox(height: 16),

            // SMS preview box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.15)),
              ),
              child: Text(
                widget.smsBody,
                style: const TextStyle(fontSize: 12, height: 1.5, fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(height: 20),

            // Prefix field
            const Text('Text before the amount (prefix)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            TextField(
              controller: _prefixCtrl,
              decoration: InputDecoration(
                hintText: 'e.g. "Auto pay of INR "',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 13),
              onChanged: (_) => _updatePreview(),
            ),
            const SizedBox(height: 14),

            // Terminator field
            const Text('Text after the amount (terminator — optional)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            TextField(
              controller: _terminatorCtrl,
              decoration: InputDecoration(
                hintText: 'e.g. " for" or leave blank',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 13),
              onChanged: (_) => _updatePreview(),
            ),
            const SizedBox(height: 14),

            // Keywords field
            const Text('Must-contain keywords (comma-separated, optional)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            TextField(
              controller: _keywordsCtrl,
              decoration: InputDecoration(
                hintText: 'e.g. "processed, axis bank"',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 13),
              onChanged: (_) => _updatePreview(),
            ),
            const SizedBox(height: 14),

            // Type selector
            const Text('Transaction type',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Row(
              children: [
                _TypeChip(
                  label: 'Debit',
                  selected: _forcedType == 'debit',
                  color: const Color(0xFFEF4444),
                  onTap: () { setState(() => _forcedType = 'debit'); _updatePreview(); },
                ),
                const SizedBox(width: 10),
                _TypeChip(
                  label: 'Credit',
                  selected: _forcedType == 'credit',
                  color: const Color(0xFF10B981),
                  onTap: () { setState(() => _forcedType = 'credit'); _updatePreview(); },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Live preview
            if (_previewResult != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: _previewResult!.startsWith('Extracted')
                      ? const Color(0xFF10B981).withValues(alpha: 0.08)
                      : const Color(0xFFEF4444).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _previewResult!,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _previewResult!.startsWith('Extracted')
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Save button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save Rule',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _TypeChip({
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : Colors.grey.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? color : Colors.grey.withValues(alpha: 0.3),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: selected ? color : Colors.grey[500],
          ),
        ),
      ),
    );
  }
}

// ─── Deleted transactions list ────────────────────────────────────────────────

class _DeletedListView extends StatelessWidget {
  final List<Transaction> transactions;
  final Future<void> Function(int id) onRestore;
  final Future<void> Function(int id) onPermanentDelete;

  const _DeletedListView({
    required this.transactions,
    required this.onRestore,
    required this.onPermanentDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline, size: 56, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('No deleted transactions',
                style: TextStyle(color: Colors.grey[500], fontSize: 15)),
            const SizedBox(height: 6),
            Text('Swipe-deleted transactions appear here\nso you can add them back.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[400], fontSize: 13, height: 1.5)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
      itemCount: transactions.length,
      itemBuilder: (_, i) => _DeletedTile(
        transaction: transactions[i],
        onRestore: () => onRestore(transactions[i].id!),
        onPermanentDelete: () => onPermanentDelete(transactions[i].id!),
      ),
    );
  }
}

class _DeletedTile extends StatefulWidget {
  final Transaction transaction;
  final Future<void> Function() onRestore;
  final Future<void> Function() onPermanentDelete;

  const _DeletedTile({
    required this.transaction,
    required this.onRestore,
    required this.onPermanentDelete,
  });

  @override
  State<_DeletedTile> createState() => _DeletedTileState();
}

class _DeletedTileState extends State<_DeletedTile> {
  bool _restoring = false;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.transaction;
    final isCredit = t.type == TransactionType.credit;
    final meta = categoryMeta(t.category);
    final amountColor = isCredit ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return GestureDetector(
      onTap: t.rawMessage != null ? () => setState(() => _expanded = !_expanded) : null,
      onLongPress: t.rawMessage != null
          ? () {
              Clipboard.setData(ClipboardData(text: t.rawMessage!));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Copied SMS body'), duration: Duration(seconds: 1)),
              );
            }
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 1)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Category icon
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: meta.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(meta.icon, color: meta.color, size: 18),
                  ),
                  const SizedBox(width: 12),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.merchant == 'Unknown' ? t.subCategory : t.merchant,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${t.category} · ${formatDate(t.date)}',
                          style: TextStyle(color: Colors.grey[500], fontSize: 12),
                        ),
                      ],
                    ),
                  ),

                  // Amount + buttons
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${isCredit ? '+' : '-'}${formatAmount(t.amount)}',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14, color: amountColor),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Remove permanently button
                          SizedBox(
                            height: 28,
                            child: OutlinedButton(
                              onPressed: () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text('Remove permanently?'),
                                    content: const Text(
                                        'This removes the transaction from the deleted list. '
                                        'The SMS will be re-imported on next full scan.'),
                                    actions: [
                                      TextButton(
                                          onPressed: () => Navigator.pop(context, false),
                                          child: const Text('Cancel')),
                                      TextButton(
                                          onPressed: () => Navigator.pop(context, true),
                                          child: const Text('Remove',
                                              style: TextStyle(color: Colors.red))),
                                    ],
                                  ),
                                );
                                if (confirmed == true) await widget.onPermanentDelete();
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6)),
                              ),
                              child: const Text('Remove',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Add Back button
                          SizedBox(
                            height: 28,
                            child: _restoring
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2))
                                : FilledButton(
                                    onPressed: () async {
                                      setState(() => _restoring = true);
                                      await widget.onRestore();
                                    },
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFF4F46E5),
                                      padding: const EdgeInsets.symmetric(horizontal: 10),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(6)),
                                    ),
                                    child: const Text('Add Back',
                                        style: TextStyle(
                                            fontSize: 11, fontWeight: FontWeight.w600)),
                                  ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),

              // Expandable raw SMS body
              if (t.rawMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _expanded
                      ? t.rawMessage!
                      : (t.rawMessage!.length > 80
                          ? '${t.rawMessage!.substring(0, 80)}…'
                          : t.rawMessage!),
                  style: TextStyle(fontSize: 11, color: Colors.grey[500], height: 1.4),
                ),
                if (t.rawMessage!.length > 80)
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.grey[400], size: 16),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
