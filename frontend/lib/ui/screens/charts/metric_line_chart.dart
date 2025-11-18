import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphic/graphic.dart';
import 'package:aegis/models/charts/metric_polling_definition.dart';
import 'package:aegis/services/charts/dashboard_metric_service.dart';
import 'package:aegis/ui/components/retry_indicator.dart';

class MetricLineChart extends StatelessWidget {
  final MetricPollingDefinition definition;

  const MetricLineChart({
    super.key,
    required this.definition,
  });

  Map<String, Variable> _makeVariableDefinition() {
    return {
      // TODO: Retrieve range from backend
      "time": Variable(
        accessor: (row) => row["time"] as DateTime,
        scale: TimeScale(
          formatter: (time) => "-${DateTime.now().add(Duration(seconds: 30)).difference(time).inMinutes} min",
          marginMin: 0.0,
          marginMax: 0.0,
        )
      ),
      "value": Variable(
        accessor: (row) => (row['value'] ?? 0.0) as num,
        scale: LinearScale(niceRange: true)
      )
    };
  }

  Widget _makeGraph(Map<String, dynamic> data) {
    final datapoints = data["data"] is List? data["data"] : [];

    final values = (datapoints)
        .map((datapoint) => {
          "time": DateTime.fromMillisecondsSinceEpoch((datapoint["time"] * 1000).toInt()),
          "value": datapoint["value"]
      }).toList();
      
    if (values.isEmpty) {
      return Center(child: Text("No hay datos"));
    }

    return Chart(
      data: values,
      variables: _makeVariableDefinition(),
      axes: [Defaults.horizontalAxis, Defaults.verticalAxis],
      marks: [
        LineMark(
          position: Varset('time') * Varset('value'),
          shape: ShapeEncode(value: BasicLineShape(smooth: false) ),
          color: ColorEncode(value: const Color.fromRGBO(35, 109, 119, 1))
        )
      ]
    );
  }

  void onRetry(WidgetRef ref) {
    ref.invalidate(dashboardMetricServiceProvider(definition: definition));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, ref, child) {
      final datapoints = ref.watch(dashboardMetricServiceProvider(definition: definition));
    
      return datapoints.when(
        data: (Map<String, dynamic> data)  => _makeGraph(data),
        error: (error, _) => RetryIndicator(onRetry: () async => onRetry(ref), isLoading: false, error: error,),
        loading: () => RetryIndicator(onRetry: () async => onRetry(ref), isLoading: true,),
      );
    });

  }
}
