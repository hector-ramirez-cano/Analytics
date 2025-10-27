import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphic/graphic.dart';
import 'package:network_analytics/models/charts/metadata_polling_definition.dart';
import 'package:network_analytics/services/charts/dashboard_metadata_service.dart';
import 'package:network_analytics/ui/components/retry_indicator.dart';

class MetadataPieChart extends StatelessWidget {
  final MetadataPollingDefinition definition;

  MetadataPieChart({
    super.key,
    required this.definition,
  });

  final ColorScheme scheme = ColorScheme.fromSeed(
    seedColor: const Color.fromARGB(255, 184, 242, 250),
  );

  late final List<Color> pieColors = [
    scheme.primary,
    scheme.secondary,
    scheme.tertiary,
    scheme.surface,
  ];

  late final Color textColor = scheme.onSurface;

  Map<String, Variable> _makeVariableDefinition() {
    return {
      'value': Variable(
        accessor: (row) => (row['value'] ?? "") as String,
        scale: OrdinalScale(), 
      ),
      'count': Variable(
        accessor: (row) => (row['count'] ?? 0.0) as num,
      ),
    };
  }

  Widget _makeGraph(Map<String, dynamic> data) {
    final datapoints = data["data"] is List? data["data"] : [];
    final Map<String, int> count = {};
    datapoints
      .forEach((metadata) {
        final metadataStr = metadata[definition.metadata].toString();
        count[metadataStr] = (count[metadataStr] ?? 0) + 1;
      });

    final values = count.entries.map((e) => {'value': e.key, 'count': e.value}).toList();

    return Chart (
            data: values,
            variables: _makeVariableDefinition(),
            transforms: [
              Proportion(
                variable: 'count',
                as: 'percent',
              )
            ],
            marks: [
              IntervalMark(
                position: Varset('percent') / Varset('value'),
                color: ColorEncode(
                  encoder: (tuple) {
                    final category = tuple['value'];
                    final index = category.hashCode % pieColors.length;
                    return pieColors[index];
                  },
                ),
                label: LabelEncode(
                  
                  encoder: (tuple) => Label(
                    tuple['value'].toString(),
                )),
                modifiers: [StackModifier()],
              ),
            ],
            coord: PolarCoord(transposed: true, dimCount: 1),
            
          );
  }

  void onRetry(WidgetRef ref) {
    ref.invalidate(dashboardMetadataServiceProvider(definition: definition));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, ref, child) {
      final datapoints = ref.watch(dashboardMetadataServiceProvider(definition: definition));
    
      return datapoints.when(
        data: (Map<String, dynamic> data)  => _makeGraph(data),
        error: (error, _) => RetryIndicator(onRetry: () async => onRetry(ref), isLoading: false, error: error,),
        loading: () => RetryIndicator(onRetry: () async => onRetry(ref), isLoading: true,),
      );
    });

  }
}
