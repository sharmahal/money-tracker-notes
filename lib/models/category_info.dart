import 'package:flutter/material.dart';

class CategoryInfo {
  final String name;
  final IconData icon;
  final Color color;

  const CategoryInfo({
    required this.name,
    required this.icon,
    required this.color,
  });
}

const Map<String, CategoryInfo> kCategoryMeta = {
  'Grocery': CategoryInfo(name: 'Grocery', icon: Icons.shopping_cart, color: Color(0xFF26A69A)),
  'Food': CategoryInfo(name: 'Food', icon: Icons.restaurant, color: Color(0xFFFF7043)),
  'Essential': CategoryInfo(name: 'Essential', icon: Icons.home, color: Color(0xFF42A5F5)),
  'Transport': CategoryInfo(name: 'Transport', icon: Icons.directions_car, color: Color(0xFF66BB6A)),
  'Fun': CategoryInfo(name: 'Fun', icon: Icons.celebration, color: Color(0xFFAB47BC)),
  'Shopping': CategoryInfo(name: 'Shopping', icon: Icons.shopping_bag, color: Color(0xFFEC407A)),
  'Health': CategoryInfo(name: 'Health', icon: Icons.favorite, color: Color(0xFFEF5350)),
  'Travel': CategoryInfo(name: 'Travel', icon: Icons.flight, color: Color(0xFF26C6DA)),
  'Investment': CategoryInfo(name: 'Investment', icon: Icons.trending_up, color: Color(0xFF5C6BC0)),
  'Others': CategoryInfo(name: 'Others', icon: Icons.more_horiz, color: Color(0xFF78909C)),
};

// ── Dynamic registry ──────────────────────────────────────────────────────────
// Starts as a copy of built-in; updated via updateCategoryRegistry() when the
// provider loads user-defined categories from the database.

Map<String, CategoryInfo> _registry = Map.of(kCategoryMeta);

/// All known categories in display order: built-ins first, then custom.
List<String> get allCategories => _registry.keys.toList();

/// Look up a category by name. Returns a grey fallback for unknown names.
CategoryInfo categoryMeta(String category) =>
    _registry[category] ??
    const CategoryInfo(name: 'Others', icon: Icons.more_horiz, color: Color(0xFF78909C));

/// Called by AppProvider whenever custom categories are loaded or changed.
void updateCategoryRegistry(Map<String, CategoryInfo> customEntries) {
  _registry = {...kCategoryMeta, ...customEntries};
}

// ── Pickable icons for the category builder ───────────────────────────────────

const kPickableIcons = <(IconData, String)>[
  (Icons.payments, 'Salary'),
  (Icons.work_outline, 'Work'),
  (Icons.home_outlined, 'Rent'),
  (Icons.school_outlined, 'Education'),
  (Icons.fitness_center, 'Gym'),
  (Icons.child_care, 'Kids'),
  (Icons.pets, 'Pets'),
  (Icons.volunteer_activism, 'Charity'),
  (Icons.coffee, 'Coffee'),
  (Icons.local_bar, 'Drinks'),
  (Icons.movie_outlined, 'Movies'),
  (Icons.music_note, 'Music'),
  (Icons.book_outlined, 'Books'),
  (Icons.phone_android, 'Gadgets'),
  (Icons.local_gas_station, 'Fuel'),
  (Icons.medical_services_outlined, 'Medical'),
  (Icons.spa, 'Wellness'),
  (Icons.sports_esports, 'Gaming'),
  (Icons.business_center, 'Business'),
  (Icons.attach_money, 'Finance'),
];

const kPickableColors = <Color>[
  Color(0xFF4F46E5),
  Color(0xFF10B981),
  Color(0xFFEF4444),
  Color(0xFFF59E0B),
  Color(0xFF3B82F6),
  Color(0xFF8B5CF6),
  Color(0xFFF97316),
  Color(0xFF06B6D4),
  Color(0xFFEC4899),
  Color(0xFF14B8A6),
  Color(0xFF84CC16),
  Color(0xFF6B7280),
];
