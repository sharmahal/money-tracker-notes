import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/category_info.dart';
import '../models/custom_rule.dart';
import '../providers/app_provider.dart';
import 'add_rule_screen.dart';

class CustomRulesScreen extends StatelessWidget {
  const CustomRulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final rules = provider.rules;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Extraction Rules'),
        actions: [
          if (rules.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Text('${rules.length} rule${rules.length == 1 ? '' : 's'}',
                    style: const TextStyle(fontSize: 13, color: Colors.white70)),
              ),
            ),
        ],
      ),
      body: rules.isEmpty
          ? _EmptyState(onAdd: () => _openAdd(context, provider))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: rules.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _RuleCard(
                rule: rules[i],
                onToggle: (v) => provider.setRuleEnabled(rules[i].id, v),
                onDelete: () => _confirmDelete(context, provider, rules[i]),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAdd(context, provider),
        backgroundColor: const Color(0xFF4F46E5),
        icon: const Icon(Icons.add),
        label: const Text('Add Rule'),
      ),
    );
  }

  void _openAdd(BuildContext context, AppProvider provider) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: provider,
          child: const AddRuleScreen(),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, AppProvider provider, CustomRule rule) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete rule?'),
        content: Text('Remove the rule for prefix "${rule.prefix}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              provider.deleteRule(rule.id);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _RuleCard extends StatelessWidget {
  final CustomRule rule;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  const _RuleCard({required this.rule, required this.onToggle, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final meta = categoryMeta(rule.category ?? 'Others');
    final enabled = rule.isEnabled;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: enabled
              ? meta.color.withValues(alpha: 0.3)
              : Colors.grey.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            // Category icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: (enabled ? meta.color : Colors.grey).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(meta.icon,
                  size: 20, color: enabled ? meta.color : Colors.grey),
            ),
            const SizedBox(width: 12),

            // Rule info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (rule.ruleType == RuleType.merchantExtraction) ...[
                    Wrap(spacing: 4, runSpacing: 4, children: [
                      if (rule.prefix != null)
                        _Chip(label: rule.prefix!, color: const Color(0xFF4F46E5), enabled: enabled),
                      if (rule.terminator != null) ...[
                        Text('→', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                        _Chip(label: rule.terminator!, color: const Color(0xFF059669), enabled: enabled),
                      ],
                    ]),
                  ] else ...[
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        ...rule.keywords.take(4).map(
                            (kw) => _Chip(label: kw, color: const Color(0xFFF59E0B), enabled: enabled)),
                        if (rule.keywords.length > 4)
                          _Chip(label: '+${rule.keywords.length - 4} more', color: Colors.grey, enabled: enabled),
                      ],
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    rule.ruleType == RuleType.merchantExtraction
                        ? 'Extracts payee name only'
                        : '${rule.category}  ›  ${rule.subCategory}',
                    style: TextStyle(
                      fontSize: 13,
                      color: enabled ? const Color(0xFF374151) : Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // Toggle + delete
            Column(
              children: [
                Switch(
                  value: enabled,
                  onChanged: onToggle,
                  activeColor: const Color(0xFF4F46E5),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  color: Colors.red[300],
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  final bool enabled;

  const _Chip({required this.label, required this.color, required this.enabled});

  @override
  Widget build(BuildContext context) {
    final c = enabled ? color : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: c.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: c,
              fontWeight: FontWeight.w600)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.rule, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text('No extraction rules yet',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              'Rules let you teach the app how to read your bank\'s SMS format — '
              'which text comes before the merchant name and where it ends.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500], fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Create your first rule'),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
            ),
          ],
        ),
      ),
    );
  }
}
