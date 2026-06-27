import 'package:flutter/material.dart';
import 'category_info.dart';

class CustomCategory {
  final String name;
  final int colorValue;
  final int iconCodePoint;

  const CustomCategory({
    required this.name,
    required this.colorValue,
    required this.iconCodePoint,
  });

  Color get color => Color(colorValue);
  IconData get icon => IconData(iconCodePoint, fontFamily: 'MaterialIcons');

  CategoryInfo toInfo() => CategoryInfo(name: name, icon: icon, color: color);

  Map<String, dynamic> toMap() => {
        'name': name,
        'colorValue': colorValue,
        'iconCodePoint': iconCodePoint,
      };

  factory CustomCategory.fromMap(Map<String, dynamic> map) => CustomCategory(
        name: map['name'] as String,
        colorValue: map['colorValue'] as int,
        iconCodePoint: map['iconCodePoint'] as int,
      );
}
