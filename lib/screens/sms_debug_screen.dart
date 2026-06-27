import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/transaction.dart';
import '../models/category_info.dart';
import '../providers/app_provider.dart';
import '../services/sms_service.dart';
import '../utils/formatters.dart';

class SmsDebugScreen extends StatefulWidget {
  final DateTime month;

  const SmsDebugScreen({super.key, required this.month});

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

  @override
  void initState() {
    super.initState();
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
        SmsService().diagnose(widget.month),
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

  @override
  Widget build(BuildContext context) {
    final all = _entries ?? [];
    final parsed = all.where((e) => e.isParsed).toList();
    final skipped = all.where((e) => !e.isBank || (e.isBank && !e.isParsed)).toList();
    final deleted = _deleted ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('SMS Diagnostic'),
            Text(
              formatMonth(widget.month),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
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
                    _SmsListView(entries: skipped),
                    _DeletedListView(
                      transactions: deleted,
                      onRestore: (id) async {
                        await context.read<AppProvider>().restoreTransaction(id);
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
  const _SmsListView({required this.entries});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Center(child: Text('No messages', style: TextStyle(color: Colors.grey)));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: entries.length,
      itemBuilder: (_, i) => _SmsDebugTile(entry: entries[i]),
    );
  }
}

class _SmsDebugTile extends StatefulWidget {
  final SmsDebugEntry entry;
  const _SmsDebugTile({required this.entry});

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
}

// ─── Deleted transactions list ────────────────────────────────────────────────

class _DeletedListView extends StatelessWidget {
  final List<Transaction> transactions;
  final Future<void> Function(int id) onRestore;

  const _DeletedListView({required this.transactions, required this.onRestore});

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
      ),
    );
  }
}

class _DeletedTile extends StatefulWidget {
  final Transaction transaction;
  final Future<void> Function() onRestore;

  const _DeletedTile({required this.transaction, required this.onRestore});

  @override
  State<_DeletedTile> createState() => _DeletedTileState();
}

class _DeletedTileState extends State<_DeletedTile> {
  bool _restoring = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.transaction;
    final isCredit = t.type == TransactionType.credit;
    final meta = categoryMeta(t.category);
    final amountColor = isCredit ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return Container(
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
        child: Row(
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

            // Amount
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isCredit ? '+' : '-'}${formatAmount(t.amount)}',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14, color: amountColor),
                ),
                const SizedBox(height: 6),
                // Add Back button
                SizedBox(
                  height: 28,
                  child: _restoring
                      ? const SizedBox(
                          width: 16, height: 16,
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
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
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
