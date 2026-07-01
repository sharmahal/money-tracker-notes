import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/app_provider.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  final prefs = await SharedPreferences.getInstance();
  final onboardingDone = prefs.getBool('onboarding_done') ?? false;
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppProvider(),
      child: MoneyTrackerApp(showOnboarding: !onboardingDone),
    ),
  );
}

class MoneyTrackerApp extends StatelessWidget {
  final bool showOnboarding;

  const MoneyTrackerApp({super.key, required this.showOnboarding});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CashTrace',
      theme: AppTheme.theme,
      home: showOnboarding ? const OnboardingScreen() : const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
