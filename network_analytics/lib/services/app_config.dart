import 'package:flutter/services.dart' show rootBundle;
import 'package:yaml/yaml.dart';

class AppConfig {
  static YamlMap? _config;

  static Future<void> load() async {
    final yamlString = await rootBundle.loadString('assets/config.yaml');
    _config = loadYaml(yamlString);
  }

  static dynamic get(String key) {
    return _config?[key];
  }
}
