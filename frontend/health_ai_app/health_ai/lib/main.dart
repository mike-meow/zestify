import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/debug/file_explorer_screen.dart';
import 'screens/debug/health_data_download_screen_v2.dart';
import 'screens/settings_screen.dart';
import 'screens/simplified_health_sync_screen.dart';

void main() {
  // Add error handling for Flutter errors
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Flutter error: ${details.exception}');
  };

  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Run the app with error handling
  runZonedGuarded(() => runApp(const MyApp()), (error, stack) {
    debugPrint('Caught error: $error');
    debugPrint('Stack trace: $stack');
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Health AI Coach',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: '/', // Start with the home screen
      routes: {
        '/': (context) => const HomeScreen(),
        '/file_explorer': (context) => const FileExplorerScreen(),
        '/health_data_download':
            (context) => const SimplifiedHealthSyncScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}

// Main app entry point
