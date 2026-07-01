import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/currency_info.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

const _kTotalSlides = 6; // Welcome + Currency + SMS + Categories + Custom Rules + Insights

class OnboardingScreen extends StatefulWidget {
  final bool isReview;
  const OnboardingScreen({super.key, this.isReview = false});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;
  String _selectedCurrency = 'INR';

  bool get _isLast => _page == _kTotalSlides - 1;

  void _next() {
    if (_isLast) {
      _finish();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  void _skip() => _finish();

  Future<void> _finish() async {
    if (!mounted) return;
    await context.read<AppProvider>().setCurrency(_selectedCurrency);
    if (!widget.isReview) {
      await Permission.sms.request();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_done', true);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      if (!mounted) return;
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _isLast ? null : _skip,
                child: Text(
                  _isLast ? '' : 'Skip',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

            // Pages
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _SlideView(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'Welcome to CashTrace',
                    body: 'Track every transaction without lifting a finger. Your bank SMS, organized automatically.',
                  ),
                  // Currency picker slide
                  _CurrencySlide(
                    selected: _selectedCurrency,
                    onChanged: (code) => setState(() => _selectedCurrency = code),
                  ),
                  _SlideView(
                    icon: Icons.sms_outlined,
                    title: 'Bank SMS, Instantly Imported',
                    body: 'We read your bank messages and pull out every debit and credit automatically — no manual entry, ever.',
                  ),
                  _SlideView(
                    icon: Icons.auto_awesome_outlined,
                    title: 'Smart Categorization',
                    body: 'Food, bills, shopping, EMIs — every transaction gets sorted automatically.',
                  ),
                  _SlideView(
                    icon: Icons.insights_outlined,
                    title: 'See Where It Goes',
                    body: 'Monthly breakdowns, trends, and pie charts at a glance. Sync across devices with Google for peace of mind.',
                  ),
                  const _CustomRulesSlide(),
                ],
              ),
            ),

            // Dot indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_kTotalSlides, (i) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _page == i ? 22 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: _page == i
                        ? AppTheme.primary
                        : AppTheme.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),

            const SizedBox(height: 32),

            // CTA button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: _next,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _isLast ? 'Get Started' : 'Next',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}

// ── Generic slide ─────────────────────────────────────────────────────────────

class _SlideView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _SlideView({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Expanded(
            flex: 5,
            child: Center(
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  gradient: AppTheme.heroGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.30),
                      blurRadius: 48,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Icon(icon, size: 88, color: Colors.white),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              children: [
                const SizedBox(height: 32),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                    height: 1.2,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey[500],
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Custom rules slide ────────────────────────────────────────────────────────

class _CustomRulesSlide extends StatelessWidget {
  const _CustomRulesSlide();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          const Text(
            "You're in Control",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
              height: 1.2,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Fine-tune how CashTrace reads your bank messages.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey[500], height: 1.5),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: const [
                _RuleExampleCard(
                  icon: Icons.person_pin_outlined,
                  color: Color(0xFF6366F1),
                  title: 'Extract the correct payee name',
                  description: 'Tell CashTrace where the payee sits in your bank\'s SMS — it picks the right name every time.',
                  before: 'INR 500 debited to VPA swiggy.order@icici',
                  after: 'Swiggy',
                  beforeLabel: 'Your SMS',
                  afterLabel: 'Payee shown',
                ),
                SizedBox(height: 12),
                _RuleExampleCard(
                  icon: Icons.category_outlined,
                  color: Color(0xFF10B981),
                  title: 'Recategorize a payee',
                  description: 'If the auto-category is wrong for a merchant, override it with one tap.',
                  before: 'Amazon → Shopping',
                  after: 'Amazon → Subscriptions',
                  beforeLabel: 'Auto-detected',
                  afterLabel: 'Your rule',
                ),
                SizedBox(height: 12),
                _RuleExampleCard(
                  icon: Icons.sms_outlined,
                  color: Color(0xFFF59E0B),
                  title: "Teach your bank's message format",
                  description: 'Some banks say "processed" not "debited". Show CashTrace where the amount is and it\'ll never miss them.',
                  before: 'Auto pay of INR 2320 processed on Axis card',
                  after: '−₹2,320  ·  captured',
                  beforeLabel: 'Missed SMS',
                  afterLabel: 'Now captured',
                ),
                SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RuleExampleCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final String before;
  final String after;
  final String beforeLabel;
  final String afterLabel;

  const _RuleExampleCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.before,
    required this.after,
    required this.beforeLabel,
    required this.afterLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: color)),
                    Text(description,
                        style:
                            TextStyle(fontSize: 11, color: Colors.grey[500], height: 1.3)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _Pill(label: beforeLabel, value: before, muted: true)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward, size: 14, color: Colors.grey[400]),
              ),
              Expanded(child: _Pill(label: afterLabel, value: after, color: color)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final bool muted;

  const _Pill({required this.label, required this.value, this.color, this.muted = false});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.grey[400]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: muted ? Colors.grey.withValues(alpha: 0.06) : c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: muted ? Colors.grey.withValues(alpha: 0.15) : c.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: muted ? Colors.grey[400] : c,
                  letterSpacing: 0.3)),
          const SizedBox(height: 2),
          Text(value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: muted ? Colors.grey[600] : c,
                  height: 1.3)),
        ],
      ),
    );
  }
}

// ── Currency picker slide ─────────────────────────────────────────────────────

class _CurrencySlide extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _CurrencySlide({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 24),
        const Text(
          'Pick your currency',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
            height: 1.2,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'All amounts will be shown in this currency.\nYou can change it later in settings.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.grey[500], height: 1.5),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: kCurrencies.length,
            itemBuilder: (_, i) {
              final c = kCurrencies[i];
              final isSelected = c.code == selected;
              return GestureDetector(
                onTap: () => onChanged(c.code),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primary.withValues(alpha: 0.08)
                        : Colors.grey.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primary
                          : Colors.grey.withValues(alpha: 0.2),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primary.withValues(alpha: 0.12)
                              : Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            c.symbol.trim(),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? AppTheme.primary : Colors.grey[600],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: isSelected ? AppTheme.primary : const Color(0xFF1F2937),
                              ),
                            ),
                            Text(
                              c.code,
                              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Icon(Icons.check_circle, color: AppTheme.primary, size: 20),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
