
import 'dart:async';

import 'package:aegis/extensions/semaphore.dart';
import 'package:aegis/services/websocket_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'metadata_service.g.dart';

@riverpod
class MetadataService extends _$MetadataService {
  final Semaphore _dataReady = Semaphore();

  String notifierKey = "";
  dynamic _data;

  void handleUpdate(dynamic json) {
    if (json is! Map<String, dynamic>) { return; } 
    if (json["msg"] is! Map<String, dynamic> || (json["msg"]["metadata"] == null)) { return; }
    

    // extract dem datapoints and call for state change
    final msg = json["msg"];

    // if it's a null, perhaps this value was not meant for us
    if (msg == null) { 
      return; 
    }

    _data = msg;
    _dataReady.signal();
  }

  void refresh() {
    final notifier = ref.read(websocketServiceProvider.notifier);
    notifier.post(
      "metadata",
      {
        "metadata": metadata,
        "device-ids": deviceId,
      });
  }

  @override
  Future<dynamic> build({required String metadata, required int deviceId}) async {
    ref.watch(websocketServiceProvider);
    final notifier = ref.watch(websocketServiceProvider.notifier);

    _dataReady.reset();
    notifierKey = "metadata_${metadata}_$deviceId";

    notifier.attachListener("metadata", notifierKey, handleUpdate);
    
    refresh();
    ref.onDispose(() {
      notifier.removeListener(notifierKey);
    });

    await _dataReady.future;
    notifier.removeListener(notifierKey);

    return _data["msg"][0][metadata];
  }
}