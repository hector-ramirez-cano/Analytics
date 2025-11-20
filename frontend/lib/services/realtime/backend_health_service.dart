
import 'dart:async';

import 'package:aegis/extensions/semaphore.dart';
import 'package:aegis/services/websocket_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'backend_health_service.g.dart';

class BackendStatus{
  final bool postgresStatus;
  final String postgresMsg;
  final bool influxStatus;
  final String influxMsg;

  BackendStatus({
    required this.postgresStatus,
    required this.postgresMsg,
    required this.influxStatus,
    required this.influxMsg,
  });

  static BackendStatus fromJson(Map<String, dynamic> json) {
    return BackendStatus(
      postgresStatus: json["postgres"]?["up"] ?? false,
      postgresMsg: json["postgres"]?["msg"] ?? "",
      influxStatus: json["influx"]["up"] ?? false,
      influxMsg: json["influx"]["msg"] ?? "",
    );
  }
}

@riverpod
class BackendHealthService extends _$BackendHealthService {

  final Semaphore _firstRun = Semaphore();
  BackendStatus? _status;
  Timer? _pollerTimer;

  @override
  Future<BackendStatus> build() async {
    final wsState = ref.watch(websocketServiceProvider);
    _firstRun.reset();

    await wsState.connected.future;
    _attachRxMessageListener();
    _pollerTimer = _createPoller();

    ref.onDispose(() {
      _pollerTimer?.cancel();
    });

    await _firstRun.future;
    return _status!;
  }

  Timer _createPoller() {
    final notifier = ref.watch(websocketServiceProvider.notifier);
    notifier.post('backend-health-rt', "");

    return Timer.periodic(const Duration(seconds: 10), (_) => notifier.post('backend-health-rt', ""));
  }

  void _attachRxMessageListener() {
    ref.read(websocketServiceProvider.notifier).attachListener('backend-health-rt', 'backend-health-rt', (json) {
      final decoded = extractBody('backend-health-rt', json, (_) => {}); // TODO:_Handle onError

      // if the message is not addressed to us
      if (decoded == null) {return;}
      if (decoded is Map && decoded.entries.isEmpty) { return; }
      if (decoded["status"] == null) { return; }

      _status = BackendStatus.fromJson(decoded["status"]);

      if (_firstRun.isComplete) {
        state = AsyncValue.data(_status!);
      }
      _firstRun.signal();
    });
  }
}