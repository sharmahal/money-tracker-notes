import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

class HeroCard extends StatelessWidget {
  final double credit;
  final double debit;
  final VoidCallback? onCreditTap;
  final VoidCallback? onDebitTap;

  const HeroCard({
    super.key,
    required this.credit,
    required this.debit,
    this.onCreditTap,
    this.onDebitTap,
  });

  @override
  Widget build(BuildContext context) {
    final net = credit - debit;
    final saved = net >= 0;
    final netColor =
        saved ? const Color(0xFF34D399) : const Color(0xFFF87171);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.heroGradient,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.38),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label + main amount — tapping drills into debit transactions
            GestureDetector(
              onTap: onDebitTap,
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total Spent',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _AnimatedAmount(
                    key: ValueKey(debit.toStringAsFixed(0)),
                    value: debit,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.5,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Stat pills row
            Row(
              children: [
                Expanded(
                  child: _StatPill(
                    icon: Icons.arrow_downward_rounded,
                    label: 'Money In',
                    value: credit,
                    accentColor: AppTheme.creditGreen,
                    onTap: onCreditTap,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatPill(
                    icon: saved
                        ? Icons.savings_outlined
                        : Icons.trending_down_outlined,
                    label: saved ? 'Saved' : 'Overspent',
                    value: net.abs(),
                    accentColor: netColor,
                    onTap: onDebitTap,
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

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final double value;
  final Color accentColor;
  final VoidCallback? onTap;

  const _StatPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.accentColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.18), width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: accentColor, size: 15),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 1),
                  _AnimatedAmount(
                    key: ValueKey(value.toStringAsFixed(0)),
                    value: value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedAmount extends StatelessWidget {
  final double value;
  final TextStyle style;

  const _AnimatedAmount({super.key, required this.value, required this.style});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOut,
      tween: Tween(begin: 0, end: value),
      builder: (_, v, __) => Text(formatAmount(v), style: style),
    );
  }
}
