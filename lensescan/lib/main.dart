/// LenseScan — Secure Legal Metrology Compliance Checking System.
///
/// Main application entry point. Configures providers, routing, and theming.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'config/theme.dart';
import 'config/routes.dart';
import 'core/auth/auth_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait mode for consistent scanning experience
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Set system UI overlay style for light theme
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xFFF8F9FF),
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const LenseScanApp());
}

/// Root application widget.
class LenseScanApp extends StatelessWidget {
  const LenseScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          final router = AppRouter.createRouter(authProvider);
          return MaterialApp.router(
            title: 'LegalLens AI',
            debugShowCheckedModeBanner: false,
            theme: LenseScanTheme.lightTheme,
            routerConfig: router,
          );
        },
      ),
    );
  }
}
