import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/transaction.dart';
import '../models/category_info.dart';
import '../providers/app_provider.dart';
import '../services/categorizer_service.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _merchantCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  TransactionType _type = TransactionType.debit;
  String _category = 'Others';
  String _subCategory = 'Miscellaneous';
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _merchantCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _autoCategory() {
    final result = categorize(_merchantCtrl.text, _descCtrl.text);
    setState(() {
      _category = result.category;
      _subCategory = result.subCategory;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final t = Transaction(
      amount: double.parse(_amountCtrl.text.replaceAll(',', '')),
      type: _type,
      category: _category,
      subCategory: _subCategory,
      merchant: _merchantCtrl.text.trim().isEmpty ? 'Manual Entry' : _merchantCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      date: _date,
    );

    await context.read<AppProvider>().addManual(t);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final categories = allCategories;

    return Scaffold(
      appBar: AppBar(title: const Text('Add Transaction')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Type toggle
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _TypeBtn(
                    label: 'Debit (Out)',
                    selected: _type == TransactionType.debit,
                    color: const Color(0xFFEF4444),
                    onTap: () => setState(() => _type = TransactionType.debit),
                  ),
                  _TypeBtn(
                    label: 'Credit (In)',
                    selected: _type == TransactionType.credit,
                    color: const Color(0xFF10B981),
                    onTap: () => setState(() => _type = TransactionType.credit),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Amount
            TextFormField(
              controller: _amountCtrl,
              decoration: const InputDecoration(
                labelText: 'Amount (₹)',
                prefixIcon: Icon(Icons.currency_rupee),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d,.]'))],
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter amount';
                if (double.tryParse(v.replaceAll(',', '')) == null) return 'Invalid amount';
                return null;
              },
            ),
            const SizedBox(height: 12),
            // Merchant
            TextFormField(
              controller: _merchantCtrl,
              decoration: const InputDecoration(
                labelText: 'Merchant / Payer',
                prefixIcon: Icon(Icons.store_outlined),
              ),
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => _autoCategory(),
            ),
            const SizedBox(height: 12),
            // Description
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
              onChanged: (_) => _autoCategory(),
            ),
            const SizedBox(height: 16),
            // Category
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: categories.map((c) {
                final meta = categoryMeta(c);
                return DropdownMenuItem(
                  value: c,
                  child: Row(
                    children: [
                      Icon(meta.icon, color: meta.color, size: 18),
                      const SizedBox(width: 10),
                      Text(c),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (v) => setState(() {
                _category = v!;
                _subCategory = 'Miscellaneous';
              }),
            ),
            const SizedBox(height: 12),
            // Date
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date',
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                ),
                child: Text(
                  '${_date.day}/${_date.month}/${_date.year}',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save Transaction'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _TypeBtn({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
