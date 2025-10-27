
import 'dart:async';

import 'package:network_analytics/extensions/semaphore.dart';
import 'package:network_analytics/models/charts/metric_polling_definition.dart';
import 'package:network_analytics/services/websocket_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'dashboard_metric_service.g.dart';

@riverpod
class DashboardMetricService extends _$DashboardMetricService {
  late Map<String, dynamic> _data;
  final Semaphore _dataReady = Semaphore();
  final Semaphore _firstRun = Semaphore();
  Timer? _refreshTimer;

  void handleUpdate(dynamic json) {
    if (json is! Map<String, dynamic> || json["metric"] != definition.metric) { return; }

    // extract dem datapoints and call for state change
    final msg = json["msg"];

    // if it's a null, perhaps this value was not meant for us
    if (msg == null) { 
      return; 
    }

    _data = msg;
    _dataReady.signal();
    if (_firstRun.isComplete) {
      // first run is over, we need to manually set the state
      state = AsyncValue.data(_data);
    }

    // set the timer
    _refreshTimer = Timer(definition.updateInterval, refresh);
  }

  void refresh() {
    final notifier = ref.read(websocketServiceProvider.notifier);
    notifier.post(
      "metrics",
      {
        "start": definition.start,
        "metric": definition.metric,
        "device-id": definition.groupableId,
        "aggregate-interval": "${definition.aggregateInterval.inSeconds}s",
      });
  }

  @override
  Future<Map<String, dynamic>> build({required MetricPollingDefinition definition}) async {
    ref.watch(websocketServiceProvider);
    final notifier = ref.watch(websocketServiceProvider.notifier);

    _dataReady.reset();
    _firstRun.reset();

    notifier.attachListener("metrics", "metrics_${definition.metric}", handleUpdate);
    
    refresh();
    ref.onDispose(() {
      notifier.removeListener("metrics_${definition.metric}");
      _refreshTimer?.cancel();
    });

    await _dataReady.future;

    _firstRun.signal();

    return _data;
  }
}