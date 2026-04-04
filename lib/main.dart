import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'providers/theme_provider.dart';

import 'screens/splash_screen.dart';
import 'screens/main_screen.dart';
import 'screens/login_screen.dart';
import 'screens/client_list_screen.dart';
import 'screens/client_form_screen.dart';
import 'screens/invoice_create_screen.dart';
import 'screens/invoice_list_screen.dart';
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const InvoiceApp(),
    ),
  );
}

class InvoiceApp extends StatelessWidget {
  const InvoiceApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return MaterialApp(
      title: 'Sparks Invoice',
      debugShowCheckedModeBanner: false,
      theme: themeProvider.light,
      darkTheme: themeProvider.dark,
      themeMode: themeProvider.isDark ? ThemeMode.dark : ThemeMode.light,
      // SplashScreen handles auth check and routing
      home: const SplashScreen(),
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/main':   (context) => const MainScreen(),
        '/home':   (context) => const MainScreen(),
        '/login':  (context) => const LoginScreen(),
        '/clients':        (context) => const ClientListScreen(),
        '/add-client':     (context) => const ClientFormScreen(),
        '/create-invoice': (context) => const InvoiceCreateScreen(),
        '/invoices':       (context) => const InvoiceListScreen(),
        '/settings':       (context) => const SettingsScreen(),
      },
    );
  }
}
