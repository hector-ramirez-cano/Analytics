import 'dart:async';

import 'package:aegis/extensions/debouncer.dart';
import 'package:aegis/extensions/semaphore.dart';
import 'package:aegis/models/alerts/alert_event.dart';
import 'package:aegis/services/alerts/alert_db_service.dart';
import 'package:aegis/services/websocket_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'alerts_realtime_service.g.dart';

class UnseenAlerts {
  final List<AlertEvent> unseenAlerts;

  const UnseenAlerts({
    required this.unseenAlerts,
  });

  factory UnseenAlerts.empty() {
    return UnseenAlerts(unseenAlerts: []);
  }

  UnseenAlerts copyWith({List<AlertEvent>? unseenAlerts}) {
    return UnseenAlerts(unseenAlerts: unseenAlerts ?? this.unseenAlerts);
  }
}

@riverpod
class AlertsRealtimeService extends _$AlertsRealtimeService {
  final List<AlertEvent> _unseenAlerts = [];
  final Debouncer _unseenDebouncer = Debouncer();

  Semaphore serviceReady = Semaphore();
  Timer? _pollerTimer;

  @override
  Future<UnseenAlerts> build() async {
    
    final wsState = ref.watch(websocketServiceProvider);
    serviceReady.reset();

    await wsState.connected.future;
    
    _attachRxMessageListener();
    _pollerTimer = _createPoller();

    ref.onDispose(() {
      _pollerTimer?.cancel();
    });

    serviceReady.signal();

    return UnseenAlerts.empty();
  }

  Timer _createPoller() {
    final notifier = ref.watch(websocketServiceProvider.notifier);
    notifier.post('backend-health-rt', "");

    return Timer.periodic(const Duration(seconds: 10), (_) => notifier.post('backend-health-rt', ""));
  }

  void _attachRxMessageListener() {
    alertServiceLogger.d('Attached Stream Subscription');
    ref.read(websocketServiceProvider.notifier).attachListener('alerts-rt', 'alerts-rt', (json) {
      final decoded = extractBody('alerts-rt', json, (_) => {}); // TODO:_Handle onError

      // if the message is not addressed to us
      if (decoded == null) {return;}
      if (decoded is Map && decoded.entries.isEmpty) { return; }

      final alert = AlertEvent.fromJson(decoded);
      _unseenAlerts.add(alert);

      _unseenDebouncer.run(() {
        state = AsyncValue.data(UnseenAlerts(unseenAlerts: _unseenAlerts));
      });
    });
  }

  void markAsSeen() {
    state = AsyncValue.data(UnseenAlerts.empty());
  }
}