import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_analytics/services/app_config.dart' show AppConfig;

import 'ui/main_layout.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.load();

  // Force landscape orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(ProviderScope(child: const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MainLayout(),

      theme: ThemeData(
        colorScheme:
          ColorScheme.fromSeed(
            seedColor: Color.fromRGBO(163, 213, 255, 1),
            secondary: Color.fromRGBO(2, 66, 105, 1)
          ),
          floatingActionButtonTheme: FloatingActionButtonThemeData(
            backgroundColor: Color.fromRGBO(163, 213, 255, 1),
            foregroundColor: const Color.fromRGBO(248, 253, 255, 1),
          ),

      ),
    );
  }
}
