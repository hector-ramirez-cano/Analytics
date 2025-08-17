import 'dart:convert';
import 'package:http/http.dart' as http;
// ignore: unused_import
import 'package:logger/web.dart';
import 'package:network_analytics/models/topology.dart';

class TopologyService {
  final Uri endpoint;
  final int retries = 3; // TODO: Make config global variable
  final Duration delay = const Duration(seconds: 3);

  TopologyService({required this.endpoint});

  Future<Topology> fetchItems() async {
    int attempts = 0;
    Logger().d("Fetching items...");
    while (true) {
      try {
        final response = await http.get(endpoint);

        if (response.statusCode != 200) {
          throw Exception("Failed to load items with HTTP Code = ${response.statusCode}");
        }

        return Topology.fromJson(json.decode(response.body));
      } catch (e) {
        Logger().e("Failed to connect to endpoint, attempt $attempts, Error=${e.toString()}");
        attempts++;

        if (attempts >= retries) { 
          Logger().w("Returning Future with error for Exception handling!");
          return Future.error(e.toString());
        }

        await Future.delayed(delay);
      }
    }
  }
}


