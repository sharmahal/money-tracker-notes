import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/bank_account.dart';
import '../providers/app_provider.dart';

class AccountSelectionScreen extends StatefulWidget {
  /// If true, shows a "Continue" button instead of a plain "Save" — used on
  /// first-run so the user knows they're moving to the import step.
  final bool isFirstRun;

  const AccountSelectionScreen({super.key, this.isFirstRun = false});

  @override
  State<AccountSelectionScreen> createState() => _AccountSelectionScreenState();
}

class _AccountSelectionScreenState extends State<AccountSelectionScreen> {
  bool _discovering = true;

  @override
  void initState() {
    super.initState();
    _discover();
  }

  Future<void> _discover() async {
    await context.read<AppProvider>().discoverAndMergeAccounts();
    if (mounted) setState(() => _discovering = false);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final accounts = provider.accounts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bank Accounts'),
        actions: [
          if (!_discovering)
            IconButton(
              tooltip: 'Re-scan SMS for new accounts',
              icon: const Icon(Icons.refresh),
              onPressed: () {
                setState(() => _discovering = true);
                _discover();
              },
            ),
        ],
      ),
      body: _discovering
          ? const _ScanningState()
          : accounts.isEmpty
              ? const _EmptyState()
              : Column(
                  children: [
                    _Header(accountCount: accounts.length),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                        itemCount: accounts.length + 1,
                        itemBuilder: (_, i) {
                          if (i == accounts.length) {
                            return _AutopayTile(
                              value: provider.includeNoAccount,
                              onChanged: provider.setIncludeNoAccount,
                            );
                          }
                          return _AccountCard(
                            account: accounts[i],
                            onToggle: (val) =>
                                provider.setAccountTracked(accounts[i].id, val),
                          );
                        },
                      ),
                    ),
                  ],
                ),
      bottomNavigationBar: _discovering || accounts.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(widget.isFirstRun ? 'Continue & Import' : 'Save'),
                ),
              ),
            ),
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _ScanningState extends StatelessWidget {
  const _ScanningState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text(
            'Scanning SMS for bank accounts…',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_balance_outlined, size: 56, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No bank accounts found',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text(
              'Make sure SMS permission is granted and you have bank transaction messages in your inbox.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final int accountCount;
  const _Header({required this.accountCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF4F46E5),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Found $accountCount account${accountCount == 1 ? '' : 's'} in your SMS',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Toggle off any accounts you don\'t want to track.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _AutopayTile extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _AutopayTile({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: value
              ? const Color(0xFF4F46E5).withValues(alpha: 0.3)
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
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFF4F46E5),
        secondary: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: value
                ? const Color(0xFF4F46E5).withValues(alpha: 0.1)
                : Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.autorenew_outlined,
            color: value ? const Color(0xFF4F46E5) : Colors.grey,
            size: 22,
          ),
        ),
        title: Text(
          'Autopay / No account',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: value ? const Color(0xFF1F2937) : Colors.grey,
          ),
        ),
        subtitle: Text(
          'Include bank messages without an account number',
          style: TextStyle(fontSize: 13, color: value ? Colors.grey[600] : Colors.grey[400]),
        ),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  final BankAccount account;
  final ValueChanged<bool> onToggle;

  const _AccountCard({required this.account, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: account.isTracked
              ? const Color(0xFF4F46E5).withValues(alpha: 0.3)
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
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        value: account.isTracked,
        onChanged: onToggle,
        activeColor: const Color(0xFF4F46E5),
        secondary: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: account.isTracked
                ? const Color(0xFF4F46E5).withValues(alpha: 0.1)
                : Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.account_balance_outlined,
            color: account.isTracked ? const Color(0xFF4F46E5) : Colors.grey,
            size: 22,
          ),
        ),
        title: Text(
          account.bankName,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: account.isTracked ? const Color(0xFF1F2937) : Colors.grey,
          ),
        ),
        subtitle: Text(
          account.maskedNumber,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            color: account.isTracked ? Colors.grey[600] : Colors.grey[400],
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}
