
import 'dart:async';

import 'package:aegis/extensions/semaphore.dart';
import 'package:aegis/models/facts/facts_polling_definition.dart';
import 'package:aegis/services/websocket_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'facts_service.g.dart';

@riverpod
class FactsService extends _$FactsService {
  late dynamic _data;
  final Semaphore _dataReady = Semaphore();
  final Semaphore _firstRun = Semaphore();
  Timer? _refreshTimer;

  String notifierKey = "";

  void handleUpdate(dynamic json) {
    if (json is! Map<String, dynamic>) { return; } 
    if (json["msg"] is! Map<String, dynamic> || (json["msg"]["facts"] == null)) { return; }
    

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
      state = AsyncValue.data(_data["data"][0]);
    }

    // set the timer
    _refreshTimer = Timer(definition.updateInterval, refresh);
  }

  void refresh() {
    final notifier = ref.read(websocketServiceProvider.notifier);
    // TODO: change subscription type to "metadata" when backend separates facts from metadata
    notifier.post(
      "facts",
      {
        "facts": List.from(definition.fields),
        "device-ids": definition.groupableId,
      });
  }

  @override
  Future<Map<String, dynamic>> build({required FactsPollingDefinition definition}) async {
    ref.watch(websocketServiceProvider);
    final notifier = ref.watch(websocketServiceProvider.notifier);

    _dataReady.reset();
    _firstRun.reset();

    notifierKey = "facts_${definition.fields.hashCode}_${definition.itemIds}_${definition.chartType}";

    notifier.attachListener("facts", notifierKey, handleUpdate);
    
    refresh();
    ref.onDispose(() {
      notifier.removeListener(notifierKey);
      _refreshTimer?.cancel();
    });

    await _dataReady.future;

    _firstRun.signal();

    return _data;
  }
}