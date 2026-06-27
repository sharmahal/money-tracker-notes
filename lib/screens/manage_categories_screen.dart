import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/category_info.dart';
import '../models/custom_category.dart';
import '../providers/app_provider.dart';

class ManageCategoriesScreen extends StatelessWidget {
  const ManageCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      body: ListView(
        children: [
          const _SectionHeader('Built-in'),
          for (final key in kCategoryMeta.keys)
            _CategoryRow(
              info: kCategoryMeta[key]!,
              isCustom: false,
            ),
          const _SectionHeader('Custom'),
          if (provider.customCategories.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                'No custom categories yet. Tap + to add one.',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          for (final cat in provider.customCategories)
            _CategoryRow(
              info: cat.toInfo(),
              isCustom: true,
              onDelete: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Delete category?'),
                    content: Text(
                      'Transactions already tagged "${cat.name}" will keep that label, '
                      'but it won\'t appear in filters or rules going forward.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true && context.mounted) {
                  await context.read<AppProvider>().deleteCustomCategory(cat.name);
                }
              },
            ),
          // Spacer so FAB doesn't obscure last row
          const SizedBox(height: 80),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('New category'),
        onPressed: () => _showAddSheet(context),
      ),
    );
  }

  void _showAddSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<AppProvider>(),
        child: const _AddCategorySheet(),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.grey,
              letterSpacing: 1.2,
            ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final CategoryInfo info;
  final bool isCustom;
  final VoidCallback? onDelete;

  const _CategoryRow({
    required this.info,
    required this.isCustom,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: info.color.withAlpha(40),
        child: Icon(info.icon, color: info.color, size: 22),
      ),
      title: Text(info.name),
      trailing: isCustom
          ? IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              tooltip: 'Delete',
              onPressed: onDelete,
            )
          : null,
    );
  }
}

// ── Add category bottom sheet ─────────────────────────────────────────────────

class _AddCategorySheet extends StatefulWidget {
  const _AddCategorySheet();

  @override
  State<_AddCategorySheet> createState() => _AddCategorySheetState();
}

class _AddCategorySheetState extends State<_AddCategorySheet> {
  final _nameController = TextEditingController();
  int _selectedIconIndex = 0;
  int _selectedColorIndex = 0;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a category name')),
      );
      return;
    }

    // Check for duplicates against all known categories
    if (allCategories.map((s) => s.toLowerCase()).contains(name.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A category with that name already exists')),
      );
      return;
    }

    setState(() => _saving = true);
    final (icon, _) = kPickableIcons[_selectedIconIndex];
    final color = kPickableColors[_selectedColorIndex];

    final category = CustomCategory(
      name: name,
      colorValue: color.toARGB32(),
      iconCodePoint: icon.codePoint,
    );

    await context.read<AppProvider>().addCustomCategory(category);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('New Category',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      )),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Category name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          Text('Icon', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 8),
          SizedBox(
            height: 160,
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: kPickableIcons.length,
              itemBuilder: (_, i) {
                final (icon, label) = kPickableIcons[i];
                final selected = i == _selectedIconIndex;
                final color = kPickableColors[_selectedColorIndex];
                return GestureDetector(
                  onTap: () => setState(() => _selectedIconIndex = i),
                  child: Tooltip(
                    message: label,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: selected ? color.withAlpha(40) : Colors.grey.withAlpha(20),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected ? color : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Icon(icon, color: selected ? color : Colors.grey, size: 24),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Text('Color', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: List.generate(kPickableColors.length, (i) {
              final color = kPickableColors[i];
              final selected = i == _selectedColorIndex;
              return GestureDetector(
                onTap: () => setState(() => _selectedColorIndex = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? Colors.white : Colors.transparent,
                      width: 3,
                    ),
                    boxShadow: selected
                        ? [BoxShadow(color: color.withAlpha(120), blurRadius: 8)]
                        : null,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Add Category'),
            ),
          ),
        ],
      ),
    );
  }
}
