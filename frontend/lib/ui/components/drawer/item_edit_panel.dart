import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_analytics/models/topology.dart';

class ItemEditPanel extends StatelessWidget {
  final Topology topology;

  const ItemEditPanel({
    super.key,
    required this.topology,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer (builder: 
      (context, ref, child) {
        return Text("AS");
      },
    );
  }
}