import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
// ignore: unused_import
import 'package:logger/web.dart';
import 'package:network_analytics/extensions/development_filter.dart';
import 'package:network_analytics/models/syslog/syslog_table_cache.dart';
import 'package:network_analytics/services/app_config.dart';


String dateString(DateTime time) {
  return "${time.year}-${time.month}-${time.day}:${time.hour}:${time.minute}.${time.second}";
}

class SyslogTableService {
  static Logger logger = Logger(filter: ConfigFilter.fromConfig("debug/enable_syslog_service_logging", false));

  final Uri endpoint;

  SyslogTableService({required this.endpoint});

  Future<SyslogTableCache> fetchItems(DateTimeRange range) async {
    int attempts = 0;
    int retries = AppConfig.getOrDefault("api/retries", defaultVal: 3);
    Duration retryDelayS = Duration(seconds: AppConfig.getOrDefault("api/retry_delay_s", defaultVal: 5));
    Duration timeoutS = Duration(seconds: AppConfig.getOrDefault("api/timeout_s", defaultVal: 20));


    final finalEndpoint = endpoint.replace(queryParameters: {
      ...endpoint.queryParameters,
      "start": dateString(range.start),
      "end": dateString(range.end)
    });

    logger.d("Fetching items..., retries=$retries, retryAfter=$retryDelayS, timeout=$timeoutS");
    while (true) {
      try {
        final response = await http
          .get(finalEndpoint)
          .timeout(timeoutS);

        if (response.statusCode != 200) {
          throw Exception("Failed to load items with HTTP Code = ${response.statusCode}");
        }

        final messageCount = json.decode(response.body)["count"];

        return SyslogTableCache(range: range, messageCount: messageCount, messages: []);
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


