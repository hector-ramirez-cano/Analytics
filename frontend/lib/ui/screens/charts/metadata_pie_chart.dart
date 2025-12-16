import 'package:aegis/models/charts/style_definition.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphic/graphic.dart';
import 'package:aegis/models/charts/metadata_polling_definition.dart';
import 'package:aegis/services/charts/dashboard_metadata_service.dart';
import 'package:aegis/ui/components/retry_indicator.dart';

class MetadataPieChart extends StatelessWidget {
  final MetadataPollingDefinition definition;
  final StyleDefinition styleDefinition;
  
  const MetadataPieChart({
    super.key,
    required this.definition,
    required this.styleDefinition,
  });

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
    final datapoints = data["msg"] is List? data["msg"] : [];
    final Map<String, int> count = {};
    datapoints
      .forEach((metadata) {
        final metadataStr = metadata[definition.metadata].toString();
        count[metadataStr] = (count[metadataStr] ?? 0) + 1;
      });

    final values = count.entries
      .map((e) => {'value': e.key, 'count': e.value})
      .toList()
    ..sort((a, b) {
      final String ax = a['value']! as String;
      final String bx = b['value']! as String;
      return ax.compareTo(bx); // sorts by string naturally
    });
    
    if (values.isEmpty) {
      return Center(child: Text("No hay datos"));
    }

    return Chart (
      key: ValueKey("Charts_Metadata_${definition.fields}_${definition.itemIds}_${definition.chartType}"),
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
          transition: Transition(duration: const Duration(milliseconds: 1000), curve: Curves.linearToEaseOut),
          entrance: {MarkEntrance.x, MarkEntrance.y},
          position: Varset('percent') / Varset('value'),
          color: ColorEncode(
            encoder: (tuple) {
              final category = tuple['value'];
              final pieColors = styleDefinition.pieColors;
              final index = category.hashCode % pieColors.length;
              return pieColors[index];
            },
          ),
          label: LabelEncode(
            encoder: (tuple) {
              final category = tuple['value'];
              final textColors = styleDefinition.textColors;
              final index = category.hashCode % textColors.length;
              final style = LabelStyle(textStyle: TextStyle(color: textColors[index], fontSize: 10));
              return Label(tuple['value'].toString(), style);
            }
          ),
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
