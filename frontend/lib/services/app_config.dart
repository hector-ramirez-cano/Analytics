import 'package:flutter/services.dart' show rootBundle;
import 'package:logger/web.dart';
import 'package:yaml/yaml.dart';

class AppConfig {
  static YamlMap? _config;
  static Map<String, dynamic> cache = {};
  static Logger logger = Logger();

  static Future<void> load() async {
    final yamlString = await rootBundle.loadString('assets/config.yaml');
    _config = loadYaml(yamlString);
  }

  /// Gets a single attribute from the config file, returning null if no instance was found
  /// 
  /// [key] key on config.yaml root
  static dynamic get(String key) {
    return _config?[key];
  }

// TODO: add unit tests
  /// Traverse the config file by path, and caches the content for future requests with the same path
  /// 
  /// [path] path-like for dictionaries
  /// 
  /// [defaultValue] value to be returned if no value is found
  /// 
  /// Example:
  /// 
  /// config.yaml
  /// ```yaml
  /// api:
  ///   endpoints:
  ///     topology:
  ///       debug: "http://localhost:5050/api/topology"
  /// ```
  /// 
  /// yourfile.dart
  /// ```dart
  /// getOrDefault("api/endpoints/topology/debug") // "http://localhost:5050/api/topology"
  /// getOrDefault("api/nonexistant") // null
  /// getOrDefault("api/whogoesthere", 3) // 3
  static dynamic getOrDefault(String path, {dynamic defaultVal}) {
    if (cache.containsKey(path)) {
      return cache[path];
    }

    final keys = path.split('/');

    dynamic current = _config;

    for (final key in keys) {
      if ((current is Map<String, dynamic> || current is YamlMap) && current.containsKey(key)) {
        current = current[key];
      } else {
        cache[path] = defaultVal;

        logger.w("Using undefined config value '$path', returning default value, $defaultVal");
        return defaultVal;
      }
    }

    cache[path] = current ?? defaultVal;
    return current ?? defaultVal;
  }
}
