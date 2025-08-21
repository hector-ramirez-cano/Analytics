import 'package:logger/logger.dart';
import 'package:network_analytics/services/app_config.dart';

class ConfigFilter extends DevelopmentFilter{
  bool configSaysShouldLog;

  ConfigFilter(this.configSaysShouldLog);

  factory ConfigFilter.fromConfig(String configPath, bool defaultVal) {
    var config = AppConfig.getOrDefault(configPath, defaultVal: defaultVal);

    if (config is bool) {
      return ConfigFilter(config);
    }

    Logger().w("ConfigLogger filter created with config unset or of invalid type in config file; default to not log! path='$configPath'.");
    Logger().w("To fix ConfigLogger, create a config setting of boolean type at '$configPath' in the config file");

    return ConfigFilter(false);
  }

  @override
  bool shouldLog(LogEvent event) {
    // Always log warning or higher, degardless of whether the config file says if should log
    return super.shouldLog(event) && (event.level >= Level.warning || configSaysShouldLog);
  }
}