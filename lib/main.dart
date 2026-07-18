import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/login_screen.dart';
import 'screens/payment_screen.dart';
import 'screens/calculator_screen.dart';
import 'screens/home_screen.dart';
import 'screens/deactivated_screen.dart';
import 'services/database_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  await DatabaseService.instance.initialize();
  runApp(const ThaiCalcProApp());
}

class ThaiCalcProApp extends StatelessWidget {
  const ThaiCalcProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: DatabaseService.instance.navigatorKey,
      title: 'Thai Calc Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF00D4AA),
        scaffoldBackgroundColor: const Color(0xFF0F1117),
        cardColor: const Color(0xFF1A1D27),
        dividerColor: const Color(0xFF2A2D3A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00D4AA),
          secondary: Color(0xFFFF6B35),
          surface: Color(0xFF1A1D27),
        ),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/payment': (context) => const PaymentScreen(),
        '/calculator': (context) => const CalculatorScreen(),
        '/deactivated': (context) => const DeactivatedScreen(),
      },
    );
  }
}