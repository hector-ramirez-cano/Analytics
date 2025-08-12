import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_analytics/services/app_config.dart' show AppConfig;

import 'ui/components/topology_map_layout.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.load();

  runApp(ProviderScope(child: const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: TopologyMapLayout(),
    );
  }
}
