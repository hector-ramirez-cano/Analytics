import 'dart:convert';
import 'package:http/http.dart' as http;
// ignore: unused_import
import 'package:logger/web.dart';
import 'package:network_analytics/extensions/development_filter.dart';
import 'package:network_analytics/models/topology.dart';
import 'package:network_analytics/services/app_config.dart';

class TopologyService {
  static Logger logger = Logger(filter: ConfigFilter.fromConfig("debug/enable_topology_service_logging", false));

  final Uri endpoint;

  TopologyService({required this.endpoint});

  Future<Topology> fetchItems() async {
    int attempts = 0;
    int retries = AppConfig.getOrDefault("api/retries", defaultVal: 3);
    Duration retryDelayS = Duration(seconds: AppConfig.getOrDefault("api/retry_delay_s", defaultVal: 5));
    Duration timeoutS = Duration(seconds: AppConfig.getOrDefault("api/timeout_s", defaultVal: 20));

    logger.d("Fetching items..., retries=$retries, retryAfter=$retryDelayS, timeout=$timeoutS");
    while (true) {
      try {
        final response = await http
          .get(endpoint)
          .timeout(timeoutS);

        if (response.statusCode != 200) {
          throw Exception("Failed to load items with HTTP Code = ${response.statusCode}");
        }

        return Topology.fromJson(json.decode(response.body));
      } catch (e) {
        logger.e("Failed to connect to endpoint, attempt $attempts, Error=${e.toString()}");
        attempts++;

        if (attempts >= retries) { 
          logger.w("Returning Future with error for Exception handling!");
          return Future.error(e.toString());
        }

        await Future.delayed(retryDelayS);
      }
    }
  }
}


