import 'dart:convert';
import 'package:logger/web.dart';
import 'package:network_analytics/extensions/development_filter.dart';
import 'package:network_analytics/models/topology.dart';
import 'package:network_analytics/services/app_config.dart';
import 'package:network_analytics/services/http_fetcher.dart';

class TopologyService {
  TopologyService({required this.endpoint});

  static Logger logger = Logger(filter: ConfigFilter.fromConfig("debug/enable_topology_service_logging", false));

  final Uri endpoint;

  Future<Topology> fetchItems() async {
    int retries = AppConfig.getOrDefault("api/retries", defaultVal: 3);
    Duration retryDelay = Duration(seconds: AppConfig.getOrDefault("api/retry_delay_s", defaultVal: 5));
    Duration timeout = Duration(seconds: AppConfig.getOrDefault("api/timeout_s", defaultVal: 20));
    return HttpFetcher<Topology>().fetch(retries, retryDelay, timeout, endpoint, logger, 
      (response) => Topology.fromJson(json.decode(response))
    );

  }
}

