
import 'dart:convert';

import 'package:logger/web.dart';
import 'package:network_analytics/extensions/development_filter.dart';
import 'package:network_analytics/models/alerts/alert_rule.dart';
import 'package:network_analytics/services/app_config.dart';
import 'package:network_analytics/services/http_fetcher.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'alert_rules_service.g.dart';

class AlertRuleSet {
  final Map<int, AlertRule> rules;

  const AlertRuleSet({
    required this.rules,
  });

  factory AlertRuleSet.fromJsonArr(List<dynamic> arr) {
    final ruleList = arr.map((rule) =>  AlertRule.fromJson(rule) ).toList();
    return AlertRuleSet(rules: Map.fromEntries(ruleList.map((rule) => MapEntry(rule.id, rule))));
  }
}

@riverpod
class AlertRulesService extends _$AlertRulesService {

  static Logger logger = Logger(filter: ConfigFilter.fromConfig("debug/enable_alert_rules_service_logging", false));

  @override
  Future<AlertRuleSet> build() async {

    int retries = AppConfig.getOrDefault("api/retries", defaultVal: 3);
    Duration retryDelay = Duration(seconds: AppConfig.getOrDefault("api/retry_delay_s", defaultVal: 5));
    Duration timeout = Duration(seconds: AppConfig.getOrDefault("api/timeout_s", defaultVal: 20));
    Uri endpoint = Uri.parse(AppConfig.getOrDefault("api/alert_endpoint"));

    return HttpFetcher<AlertRuleSet>().fetch(retries, retryDelay, timeout, endpoint, logger, (response) {
      return AlertRuleSet.fromJsonArr(json.decode(response));
    });
  }
}