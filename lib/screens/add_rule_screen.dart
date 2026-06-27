import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/category_info.dart';
import '../models/custom_rule.dart';
import '../providers/app_provider.dart';
import 'manage_categories_screen.dart';

class AddRuleScreen extends StatefulWidget {
  final String? rawMessage;

  const AddRuleScreen({super.key, this.rawMessage});

  @override
  State<AddRuleScreen> createState() => _AddRuleScreenState();
}

class _AddRuleScreenState extends State<AddRuleScreen> {
  RuleType _ruleType = RuleType.merchantExtraction;

  final _prefixCtrl = TextEditingController();
  final _terminatorCtrl = TextEditingController();
  final _keywordsCtrl = TextEditingController();
  final _subCatCtrl = TextEditingController();
  String _category = 'Investment';
  bool _saving = false;

  // ── Derived ────────────────────────────────────────────────────────────────

  String? _prefix() => _prefixCtrl.text.trim().isEmpty ? null : _prefixCtrl.text.trim();
  String? _terminator() => _terminatorCtrl.text.trim().isEmpty ? null : _terminatorCtrl.text.trim();

  List<String> get _parsedKeywords => _keywordsCtrl.text
      .split(RegExp(r'[,\n]'))
      .map((k) => k.trim())
      .where((k) => k.isNotEmpty)
      .toList();

  // Preview for extraction rule
  String? get _extractionPreview {
    if (widget.rawMessage == null) return null;
    final rule = CustomRule.extraction(prefix: _prefix(), terminator: _terminator());
    return rule.extractMerchant(widget.rawMessage!);
  }

  // Preview for categorization rule: which keyword hit?
  String? get _categorizationHit {
    if (widget.rawMessage == null || _parsedKeywords.isEmpty) return null;
    final rule = CustomRule.categorization(
      prefix: _prefix(),
      terminator: _terminator(),
      keywords: _parsedKeywords,
      category: _category,
      subCategory: 'x',
    );
    if (!rule.matchesMessage(widget.rawMessage!)) return null;

    // Return which keyword matched
    final window = _getWindow(widget.rawMessage!);
    if (window == null) return null;
    final lower = window.toLowerCase();
    return _parsedKeywords.firstWhere(
      (kw) => lower.contains(kw.toLowerCase()),
      orElse: () => '',
    );
  }

  String? _getWindow(String message) {
    final p = _prefix();
    if (p == null) return message;
    final idx = message.toLowerCase().indexOf(p.toLowerCase());
    if (idx == -1) return null;
    final after = message.substring(idx + p.length);
    final t = _terminator();
    if (t != null) {
      final end = after.toLowerCase().indexOf(t.toLowerCase());
      return end != -1 ? after.substring(0, end) : after;
    }
    return after;
  }

  bool get _canSave {
    if (_ruleType == RuleType.merchantExtraction) {
      return _prefix() != null || _terminator() != null;
    }
    return _parsedKeywords.isNotEmpty && _subCatCtrl.text.trim().isNotEmpty;
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);

    final CustomRule rule;
    if (_ruleType == RuleType.merchantExtraction) {
      rule = CustomRule.extraction(prefix: _prefix(), terminator: _terminator());
    } else {
      rule = CustomRule.categorization(
        prefix: _prefix(),
        terminator: _terminator(),
        keywords: _parsedKeywords,
        category: _category,
        subCategory: _subCatCtrl.text.trim(),
      );
    }

    await context.read<AppProvider>().addRule(rule);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  void dispose() {
    _prefixCtrl.dispose();
    _terminatorCtrl.dispose();
    _keywordsCtrl.dispose();
    _subCatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Rule')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [

          // ── Rule type toggle ────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                _TypeBtn(
                  label: 'Payee Name',
                  icon: Icons.person_outline,
                  selected: _ruleType == RuleType.merchantExtraction,
                  onTap: () => setState(() => _ruleType = RuleType.merchantExtraction),
                ),
                _TypeBtn(
                  label: 'Categorisation',
                  icon: Icons.label_outline,
                  selected: _ruleType == RuleType.categorization,
                  onTap: () => setState(() => _ruleType = RuleType.categorization),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _ruleType == RuleType.merchantExtraction
                ? 'Extracts the payee name from between the prefix and terminator. Does NOT change category.'
                : 'If ANY keyword is found within the prefix–terminator window (or full message if no prefix), applies the category.',
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), height: 1.4),
          ),

          const SizedBox(height: 24),

          // ── Raw message ─────────────────────────────────────────────────
          if (widget.rawMessage != null) ...[
            _sectionLabel('SMS Message'),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: SelectableText(
                widget.rawMessage!,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF374151), fontFamily: 'monospace', height: 1.5),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // ── Prefix ──────────────────────────────────────────────────────
          _sectionLabel('Prefix  (optional)'),
          const SizedBox(height: 6),
          TextField(
            controller: _prefixCtrl,
            onChanged: (_) => setState(() {}),
            decoration: _inputDeco(
              _ruleType == RuleType.merchantExtraction
                  ? 'e.g.  Fvg:    or    paid to '
                  : 'e.g.  Fvg:    (narrows where keywords are searched)',
            ),
          ),
          const SizedBox(height: 16),

          // ── Terminator ──────────────────────────────────────────────────
          _sectionLabel('Terminator  (optional)'),
          const SizedBox(height: 6),
          TextField(
            controller: _terminatorCtrl,
            onChanged: (_) => setState(() {}),
            decoration: _inputDeco('e.g.  Avl Bal    or    Ref No'),
          ),

          const SizedBox(height: 20),

          // ── Extraction preview ───────────────────────────────────────────
          if (_ruleType == RuleType.merchantExtraction && widget.rawMessage != null) ...[
            _PreviewBox(
              found: _extractionPreview != null,
              message: _extractionPreview != null
                  ? 'Will extract: "${_extractionPreview!}"'
                  : _prefix() == null
                      ? 'Enter a prefix or terminator to define the extraction window.'
                      : 'Prefix not found in this message.',
            ),
            const SizedBox(height: 24),
          ],

          // ── Keywords (categorization only) ──────────────────────────────
          if (_ruleType == RuleType.categorization) ...[
            _sectionLabel('Keywords — any match applies the category  *'),
            const SizedBox(height: 6),
            TextField(
              controller: _keywordsCtrl,
              onChanged: (_) => setState(() {}),
              maxLines: 4,
              decoration: _inputDeco('mutual fund\nsip\nelss\nnps\nzerodha'),
            ),
            const SizedBox(height: 4),
            Text(
              _parsedKeywords.isEmpty
                  ? 'Enter keywords one per line or comma-separated.'
                  : '${_parsedKeywords.length} keyword${_parsedKeywords.length == 1 ? '' : 's'}: ${_parsedKeywords.join(', ')}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
            ),
            const SizedBox(height: 12),

            if (widget.rawMessage != null && _parsedKeywords.isNotEmpty) ...[
              _PreviewBox(
                found: _categorizationHit != null,
                message: _categorizationHit != null
                    ? 'Match! Keyword "${_categorizationHit!}" found${_prefix() != null ? ' within the prefix window' : ''}.'
                    : _prefix() != null && _getWindow(widget.rawMessage!) == null
                        ? 'Prefix not found in this message — no keywords checked.'
                        : 'No keyword found in ${_prefix() != null ? 'the prefix window' : 'this message'}.',
              ),
              const SizedBox(height: 20),
            ],

            // Category + subcategory
            _sectionLabel('Category  *'),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFD1D5DB)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _category,
                        isExpanded: true,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        borderRadius: BorderRadius.circular(10),
                        onChanged: (v) => setState(() => _category = v!),
                        items: allCategories.map((cat) {
                          final m = categoryMeta(cat);
                          return DropdownMenuItem(
                            value: cat,
                            child: Row(children: [
                              Icon(m.icon, size: 18, color: m.color),
                              const SizedBox(width: 10),
                              Text(cat, style: const TextStyle(fontSize: 14)),
                            ]),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: 'New category',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () async {
                      final provider = context.read<AppProvider>();
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChangeNotifierProvider.value(
                            value: provider,
                            child: const ManageCategoriesScreen(),
                          ),
                        ),
                      );
                      // If the currently selected category was removed, reset to first available
                      if (!allCategories.contains(_category) && allCategories.isNotEmpty) {
                        setState(() => _category = allCategories.first);
                      } else {
                        setState(() {}); // refresh dropdown items
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF4F46E5).withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(Icons.add, size: 20, color: Color(0xFF4F46E5)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            _sectionLabel('Sub-category  *'),
            const SizedBox(height: 6),
            TextField(
              controller: _subCatCtrl,
              onChanged: (_) => setState(() {}),
              decoration: _inputDeco('e.g.  Mutual Fund SIP    or    NPS    or    Stocks'),
            ),

            const SizedBox(height: 20),

            // Category preview chip
            if (_subCatCtrl.text.trim().isNotEmpty) ...[
              _CategoryPreview(category: _category, subCategory: _subCatCtrl.text.trim()),
              const SizedBox(height: 8),
            ],
          ],

          const SizedBox(height: 24),

          FilledButton(
            onPressed: _canSave && !_saving ? _save : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: const Color(0xFF4F46E5),
            ),
            child: _saving
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Save Rule',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 12),
          const Text(
            'Rules apply instantly to all displayed transactions — no re-import needed.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151)));

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2)),
      );
}

// ── Shared helper widgets ─────────────────────────────────────────────────────

class _TypeBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _TypeBtn({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              boxShadow: selected
                  ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, 1))]
                  : [],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: selected ? const Color(0xFF4F46E5) : Colors.grey),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                      color: selected ? const Color(0xFF4F46E5) : Colors.grey,
                    )),
              ],
            ),
          ),
        ),
      );
}

class _PreviewBox extends StatelessWidget {
  final bool found;
  final String message;
  const _PreviewBox({required this.found, required this.message});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: found ? const Color(0xFFF0FDF4) : const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: found ? const Color(0xFF86EFAC) : const Color(0xFFFDBA74)),
        ),
        child: Row(
          children: [
            Icon(found ? Icons.check_circle_outline : Icons.info_outline,
                size: 16, color: found ? const Color(0xFF16A34A) : const Color(0xFFD97706)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message,
                  style: TextStyle(
                      fontSize: 13,
                      color: found ? const Color(0xFF15803D) : const Color(0xFF92400E),
                      fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      );
}

class _CategoryPreview extends StatelessWidget {
  final String category;
  final String subCategory;
  const _CategoryPreview({required this.category, required this.subCategory});

  @override
  Widget build(BuildContext context) {
    final meta = categoryMeta(category);
    return Row(
      children: [
        Icon(meta.icon, color: meta.color, size: 18),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: meta.color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(category,
              style: TextStyle(color: meta.color, fontWeight: FontWeight.w600, fontSize: 13)),
        ),
        const SizedBox(width: 6),
        Text('→ $subCategory', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
      ],
    );
  }
}
