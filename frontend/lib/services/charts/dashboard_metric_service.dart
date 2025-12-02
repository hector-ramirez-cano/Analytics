
import 'dart:async';

import 'package:aegis/extensions/semaphore.dart';
import 'package:aegis/models/charts/metric_polling_definition.dart';
import 'package:aegis/services/websocket_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'dashboard_metric_service.g.dart';

@riverpod
class DashboardMetricService extends _$DashboardMetricService {
  final Map<String, Map<String, dynamic>> _data = {};
  final Semaphore _dataReady = Semaphore();
  final Semaphore _firstRun = Semaphore();
  Timer? _refreshTimer;

  void handleUpdate(dynamic json) {
    if (json is! Map<String, dynamic> || !definition.fields.contains(json["metrics"])) { return; }

    // extract dem datapoints and call for state change
    final msg = json["msg"];

    // if it's a null, perhaps this value was not meant for us
    if (msg == null) { 
      return; 
    }

    _data[json["metrics"]] = msg;

    if (_data.length == definition.fields.length) {
      _dataReady.signal();
      if (_firstRun.isComplete) {
        // first run is over, we need to manually set the state
        state = AsyncValue.data(_data);
      }
    }

    // set the timer
    _refreshTimer = Timer(definition.updateInterval, refresh);
  }

  void refresh() {
    if (!ref.mounted) return;

    final notifier = ref.read(websocketServiceProvider.notifier);
    _data.clear();
    for (final metric in definition.fields) {
      notifier.post(
      "metrics",
      {
        "start": definition.start,
        "metric": metric,
        "device-id": definition.groupableId,
        "aggregate-interval": "${definition.aggregateInterval.inSeconds}s",
      });
    }
  }

  @override
  Future<Map<String, Map<String, dynamic>>> build({required MetricPollingDefinition definition}) async {
    ref.watch(websocketServiceProvider);
    final notifier = ref.watch(websocketServiceProvider.notifier);

    _dataReady.reset();
    _firstRun.reset();

    // Delay to allow parallel proceses to catch up
    await Future.delayed(Duration(milliseconds: 200));

    notifier.attachListener("metrics", "metrics_${definition.fields}_${definition.groupableId}", handleUpdate);
    
    refresh();
    ref.onDispose(() {
      notifier.removeListener("metrics_${definition.fields}_${definition.groupableId}");
      _refreshTimer?.cancel();
    });

    await _dataReady.future;

    _firstRun.signal();

    return _data;
  }
}