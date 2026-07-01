import 'package:flutter/material.dart';
import '../models/category_info.dart';
import '../utils/formatters.dart';

class CategoryTile extends StatelessWidget {
  final String category;
  final double amount;
  final double totalSpend;
  final VoidCallback onTap;

  const CategoryTile({
    super.key,
    required this.category,
    required this.amount,
    required this.totalSpend,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final meta = categoryMeta(category);
    final pct = totalSpend > 0 ? amount / totalSpend : 0.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // Content — determines the tile height
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: meta.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(meta.icon, color: meta.color, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                category,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                formatPercent(amount, totalSpend),
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          formatAmount(amount),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        backgroundColor: meta.color.withValues(alpha: 0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(meta.color),
                        minHeight: 4,
                      ),
                    ),
                  ],
                ),
              ),
              // Left accent bar — Positioned fills the full tile height via Stack
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(width: 4, color: meta.color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
