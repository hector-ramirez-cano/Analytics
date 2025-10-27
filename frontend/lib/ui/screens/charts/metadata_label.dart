import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_analytics/models/charts/metadata_polling_definition.dart';
import 'package:network_analytics/services/charts/dashboard_metadata_service.dart';

class MetadataLabel extends StatelessWidget {
  final MetadataPollingDefinition definition;

  const MetadataLabel({
    super.key,
    required this.definition,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Consumer(builder:(context, ref, child) {
      
        final value = ref.watch(dashboardMetadataServiceProvider(definition: definition));
      
        return value.when(
          error: (Object error, StackTrace stackTrace) => Text("Error en cargar datos"),
          loading: () => Text("Cargando..."),
          data: (Map<String, dynamic> data) {
            final value = data['data']?[0]?[definition.metadata];
            if (value != null) {
              return Text("${definition.metadata}:\n${value.toString()}");
            }
            return Text("No hay datos");
          },
        );
      }),
    );
  }

}