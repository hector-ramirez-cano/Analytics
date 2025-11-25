import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphic/graphic.dart';
import 'package:aegis/models/charts/metadata_polling_definition.dart';
import 'package:aegis/services/charts/dashboard_metadata_service.dart';
import 'package:aegis/ui/components/retry_indicator.dart';

class MetadataPieChart extends StatelessWidget {
  final MetadataPollingDefinition definition;

  MetadataPieChart({
    super.key,
    required this.definition,
  });

  // TODO: Get swatches from db
  final int swatchIndex = 0;
  final List<Map<String, List<Color>>> swatches = [
    {
      "pieColors" : [
        Color(0xFF858ae3),
        Color(0xFF7364d2),
        Color(0xFF613dc1),
        Color(0xFF5829a7),
        Color(0xFF4e148c),
        Color(0xFF2c0735),
      ],
      "textColors":[
        Color(0xFF000000),
        Color(0xFF000000),
        Color(0xFF000000),
        Color(0xFFFFFFFF),
        Color(0xFFFFFFFF),
        Color(0xFFFFFFFF),
        Color(0xFFFFFFFF),
      ]
    },
    {
      "pieColors": [
        Color(0xffdcd6f7),
        Color(0xffa6b1e1),
        Color(0xffb4869f),
        Color(0xff985f6f),
        Color(0xff4e4c67),
      ],
      "textColors": [
        Color(0xFF000000),
        Color(0xFF000000),
        Color(0xFF000000),
        Color(0xFF000000),
        Color(0xFFFFFFFF),
      ]
    },
    {
      "pieColors": [
        Color(0xFF321325),
        Color(0xFF5f0f40),
        Color(0xFF9a031e),
        Color(0xFFcb793a),
        Color(0xFFfcdc4d),
      ],
      "textColors": [
        Color(0xFFFFFFFF),
        Color(0xFFFFFFFF),
        Color(0xFFFFFFFF),
        Color(0xFF000000),
        Color(0xFF000000),
      ]
    },
    {
      "pieColors": [
        Color(0xFFffdda1),
        Color(0xFFfcd16c),
        Color(0xFFedb230),
        Color(0xFFea952c),
        Color(0xFFe77728),
      ],
      "textColors": [
        Color(0xFF000000),
        Color(0xFF000000),
        Color(0xFF000000),
        Color(0xFF000000),
        Color(0xFF000000),
      ]
    }
  ];

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

    final values = count.entries.map((e) => {'value': e.key, 'count': e.value}).toList();
    
    if (values.isEmpty) {
      return Center(child: Text("No hay datos"));
    }

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
                transition: Transition(duration: const Duration(milliseconds: 1000), curve: Curves.linearToEaseOut),
                entrance: {MarkEntrance.x, MarkEntrance.y},
                position: Varset('percent') / Varset('value'),
                color: ColorEncode(
                  encoder: (tuple) {
                    final category = tuple['value'];
                    final pieColors = swatches[swatchIndex]["pieColors"];
                    final index = category.hashCode % pieColors!.length;
                    return pieColors[index];
                  },
                ),
                label: LabelEncode(
                  encoder: (tuple) {
                    final category = tuple['value'];
                    final textColors = swatches[swatchIndex]["textColors"];
                    final index = category.hashCode % textColors!.length;
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
