import 'dart:collection';
import 'dart:math';

import 'package:aegis/models/charts/style_definition.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphic/graphic.dart';
import 'package:aegis/models/charts/metric_polling_definition.dart';
import 'package:aegis/services/charts/dashboard_metric_service.dart';
import 'package:aegis/ui/components/retry_indicator.dart';

/// Returns [prevIndex, nextIndex] where:
///  - prevIndex is index of largest item < target (or null if none)
///  - nextIndex is index of smallest item > target (or null if none)
List<int?> _neighborIndices(List<DateTime> sorted, DateTime target) {
  if (sorted.isEmpty) return [null, null];
  int low = 0;
  int high = sorted.length - 1;

  while (low <= high) {
    final mid = (low + high) >> 1;
    final m = sorted[mid];
    if (m.isAtSameMomentAs(target)) {
      final prev = mid > 0 ? mid - 1 : null;
      final next = mid < sorted.length - 1 ? mid + 1 : null;
      return [prev, next];
    }
    if (m.isBefore(target)) {
      low = mid + 1;
    } else {
      high = mid - 1;
    }
  }

  // high = index of largest < target (or -1)
  // low  = index of smallest > target (or sorted.length)
  final prevIndex = high >= 0 ? high : null;
  final nextIndex = low < sorted.length ? low : null;
  return [prevIndex, nextIndex];
}

/// Mutates [values] in-place, interpolating missing metrics.
/// - `values` is assumed to be a LinkedHashMap \<DateTime, Map\<String, dynamic>>
///   where each inner Map may or may not contain all metric keys.
/// - `pointPresence` maps metric -> sorted List\<DateTime> that contain that metric.
/// - `fields` is the list of metric keys to ensure exist (interpolated if missing).
/// - If [extrapolateIfNoBracket] is true, single-sided fills use nearest neighbor (forward/backward fill).
void interpolateMissingPoints(
  LinkedHashMap<DateTime, Map<String, dynamic>> values,
  Map<String, List<DateTime>> pointPresence,
  List<String> fields, {
  bool extrapolateIfNoBracket = false,
}) {
  // Ensure presence lists are sorted ascending (do once)
  for (final k in pointPresence.keys) {
    pointPresence[k]!.sort();
  }

  // Iterate rows in chronological order (LinkedHashMap preserves insertion order)
  for (final rowEntry in values.entries) {
    final currentT = rowEntry.key;
    final rowMap = rowEntry.value;

    for (final metric in fields) {
      // Already present and non-null -> skip
      if (rowMap.containsKey(metric) && rowMap[metric] != null) continue;

      final pts = pointPresence[metric];
      if (pts == null || pts.isEmpty) continue; // no info for this metric

      final neighbors = _neighborIndices(pts, currentT);
      final prevIdx = neighbors[0];
      final nextIdx = neighbors[1];

      // Both sides exist -> linear interpolation
      if (prevIdx != null && nextIdx != null) {
        final x1 = pts[prevIdx];
        final x2 = pts[nextIdx];

        final y1 = values[x1]?[metric] as num?;
        final y2 = values[x2]?[metric] as num?;

        if (y1 == null || y2 == null) {
          // boundary values are missing in values map (shouldn't happen if pointPresence built correctly)
          continue;
        }

        final den = x2.microsecondsSinceEpoch - x1.microsecondsSinceEpoch;
        if (den == 0) {
          // same timestamp on both sides (degenerate) -> fallback to y1
          rowMap[metric] = y1;
          continue;
        }

        final left = currentT.microsecondsSinceEpoch - x1.microsecondsSinceEpoch;
        final frac = left / den;
        final interp = (y1 + frac * (y2 - y1)).toDouble();
        rowMap[metric] = interp;
        continue;
      }

      // Only one side exists
      if (extrapolateIfNoBracket) {
        if (prevIdx != null) {
          final x1 = pts[prevIdx];
          final y1 = values[x1]?[metric] as num?;
          if (y1 != null) {
            // backward-fill / hold-last
            rowMap[metric] = y1;
          }
        } else if (nextIdx != null) {
          final x2 = pts[nextIdx];
          final y2 = values[x2]?[metric] as num?;
          if (y2 != null) {
            // forward-fill / use next known
            rowMap[metric] = y2;
          }
        }
      } else {
        // Do not extrapolate: leave missing
        continue;
      }
    }
  }
}

class MetricLineChart extends StatelessWidget {
  final MetricPollingDefinition definition;
  final StyleDefinition styleDefinition;

  const MetricLineChart({
    super.key,
    required this.definition,
    required this.styleDefinition,
  });

  Map<String, Variable> _makeVariableDefinition(double min, double max) {
    return {
      "time": Variable(
        accessor: (row) => row["time"] as DateTime,
        scale: TimeScale(
          formatter: (time) => "-${DateTime.now().add(Duration(seconds: 30)).difference(time).inMinutes} min",
          marginMin: 0.0,
          marginMax: 0.0,
        )
      ),
      for (final k in definition.fields)
      k: Variable(
        accessor: (row) => (row[k] ?? 0.0) as num,
        scale: LinearScale(niceRange: true, min: min, max: max),
      )
    };
  }

  Widget _makeGraph(Map<String, Map<String, dynamic>> data) {

    // Values for each datapoint
    final values = <DateTime, Map<String, dynamic>>{} as LinkedHashMap<DateTime, Map<String, dynamic>>;
    final pointPresence = <String, List<DateTime>>{};

    double minX = double.infinity, maxX = double.negativeInfinity;

    // Converts the entries into values into
    // {
    //    "time": DateTime
    //    "metric1": 5.4153,
    //    "metric2": 531.6541,
    //    ...
    // }
    for (var entry in data.entries) {
      for (var datapoint in entry.value["data"]) {
        final time = DateTime.fromMillisecondsSinceEpoch((datapoint["time"] * 1000).toInt());
        final value = datapoint["value"];

        values.putIfAbsent(time, () => <String, dynamic>{"time": time});
        values[time]!.putIfAbsent(entry.key, () => value);

        pointPresence.putIfAbsent(entry.key, () => []);
        pointPresence[entry.key]!.add(time);

        minX = min(minX, value);
        maxX = max(maxX, value);
      }
    }

    if (values.isEmpty) {
      // No values, let's ditch 'em boys!
      return Center(child: Text("No hay datos"));
    }

    // In case sampling rates are different, interpolate the variable not sampled at this datapoint
    interpolateMissingPoints(values, pointPresence, definition.fields, extrapolateIfNoBracket: true);

    final valueList = values.entries.map((datapoints) => datapoints.value).toList();

    // Sort values, in case they're not in order. The graph expects everything to be ordered
    valueList.sort((a, b) => a["time"].compareTo(b["time"]));

    // Create one LineMark for each metric "k"
    final marks = definition.fields.map((k) {
      return LineMark(
        position: Varset('time') * Varset(k),
        color: ColorEncode(value: styleDefinition.lineColors[k.hashCode % styleDefinition.lineColors.length]),
        shape: ShapeEncode(value: BasicLineShape(smooth: false) ),
        label: LabelEncode(encoder: (values) {
          final time = (values["time"] as DateTime);
          // final point = valueList.length > 4 ? valueList[5]["time"] : valueList.first["time"];
          final point = valueList.last["time"];

          if (time.isAtSameMomentAs(point)) {
            return Label(k, LabelStyle(
              offset: Offset(-80, 0),
              textStyle: TextStyle(
                color: styleDefinition.lineColors[k.hashCode % styleDefinition.lineColors.length],

              ))
            );
          }
          else {
            return Label("");
          }
        })
      );
    }).toList();

    return Chart(
      key: ValueKey("Widget_MetricLineChart_Chart_${definition.groupableId}_${definition.fields}"),
      data: valueList,
      crosshair: CrosshairGuide(
        showLabel: [true, true],
        labelPaddings: [10.0, 10.0],
        followPointer: [false, false],
        styles: [PaintStyle(strokeColor: const Color.fromARGB(50, 0, 0, 0)), PaintStyle(strokeColor: const Color.fromARGB(50, 0, 0, 0))],
        formatter: [(d) => d.toString(), (d) => d.toString()]
      ),
      selections: {
        'touchMove': PointSelection(
          on: {
            GestureType.scaleUpdate,
            GestureType.tapDown,
            GestureType.longPressMoveUpdate
          },
          dim: Dim.x,
        )
      },
      variables: _makeVariableDefinition(minX, maxX),
      axes: [Defaults.horizontalAxis, Defaults.verticalAxis],
      marks: marks
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
        data: (Map<String, Map<String, dynamic>> data)  => _makeGraph(data),
        error: (error, _) => RetryIndicator(onRetry: () async => onRetry(ref), isLoading: false, error: error,),
        loading: () => RetryIndicator(onRetry: () async => onRetry(ref), isLoading: true,),
      );
    });

  }
}
