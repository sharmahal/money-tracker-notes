import 'package:flutter/material.dart';

// Each shimmer box owns its own animation — no shared scope needed.
class _ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius borderRadius;

  const _ShimmerBox({
    required this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
    _anim = Tween<double>(begin: -2.0, end: 2.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          gradient: LinearGradient(
            begin: Alignment(_anim.value - 1, 0),
            end: Alignment(_anim.value + 1, 0),
            colors: const [
              Color(0xFFE4E6EF),
              Color(0xFFF0F2FA),
              Color(0xFFE4E6EF),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Public placeholders ───────────────────────────────────────────────────────

class ShimmerHeroCard extends StatelessWidget {
  const ShimmerHeroCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Container(
        height: 170,
        decoration: BoxDecoration(
          color: const Color(0xFFE4E6EF),
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ShimmerBox(
                width: 90,
                height: 13,
                borderRadius: BorderRadius.circular(6)),
            const SizedBox(height: 10),
            _ShimmerBox(
                width: 160,
                height: 36,
                borderRadius: BorderRadius.circular(8)),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: _ShimmerBox(
                    width: double.infinity,
                    height: 52,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ShimmerBox(
                    width: double.infinity,
                    height: 52,
                    borderRadius: BorderRadius.circular(14),
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

class ShimmerCategoryTile extends StatelessWidget {
  const ShimmerCategoryTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _ShimmerBox(
              width: 40,
              height: 40,
              borderRadius: BorderRadius.circular(10)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ShimmerBox(
                    width: 100,
                    height: 14,
                    borderRadius: BorderRadius.circular(6)),
                const SizedBox(height: 6),
                _ShimmerBox(
                    width: 60,
                    height: 11,
                    borderRadius: BorderRadius.circular(6)),
                const SizedBox(height: 10),
                _ShimmerBox(
                  width: double.infinity,
                  height: 5,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _ShimmerBox(
              width: 64, height: 18, borderRadius: BorderRadius.circular(6)),
        ],
      ),
    );
  }
}
