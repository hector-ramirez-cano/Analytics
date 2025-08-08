import 'dart:convert';
import 'package:http/http.dart' as http;
// ignore: unused_import
import 'package:logger/web.dart';
import 'package:network_analytics/models/topology.dart';

class TopologyService {
  final Uri endpoint;

  TopologyService({required this.endpoint});

  Future<Topology> fetchItems() async {
    final response = await http.get(endpoint);

    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonList = json.decode(response.body);
      return Topology.fromJson(jsonList);
    } else {
      throw Exception('Failed to load items');
    }
  }
}


