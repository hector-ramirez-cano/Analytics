import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aegis/models/charts/metadata_polling_definition.dart';
import 'package:aegis/services/charts/dashboard_metadata_service.dart';

class MetadataLabel extends StatelessWidget {
  final MetadataPollingDefinition definition;

  const MetadataLabel({
    super.key,
    required this.definition,
  });

  Widget _makeNoValueWidget() {
    return Text("No hay datos");
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Consumer(builder:(context, ref, child) {
      
        final value = ref.watch(dashboardMetadataServiceProvider(definition: definition));
      
        return value.when(
          error: (Object error, StackTrace stackTrace) => Text("Error en cargar datos"),
          loading: () => Text("Cargando..."),
          data: (Map<String, dynamic> data) {
            final msg = data['msg'];
            if (msg == null) { return _makeNoValueWidget();}
            if (msg is! List || (msg).isEmpty) { return _makeNoValueWidget(); }
            if (msg[0] is! Map || !msg[0].containsKey(definition.metadata)) { return _makeNoValueWidget(); }

            final value = data['msg']?[0]?[definition.metadata];
            if (value != null) {
              return Text("${definition.metadata}:\n${value.toString()}");
            }
            
            return _makeNoValueWidget();
          },
        );
      }),
    );
  }

}