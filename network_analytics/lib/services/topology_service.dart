import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:network_analytics/models/topology.dart';

class TopologyService {
  final String baseUrl;

  TopologyService({required this.baseUrl});

  Future<Topology> fetchItems() async {
    final response = await http.get(Uri.parse('$baseUrl/topology'));

    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonList = json.decode(response.body);
      return Topology.fromJson(jsonList);
    } else {
      throw Exception('Failed to load items');
    }
  }
}
