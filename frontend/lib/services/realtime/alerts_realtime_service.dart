import 'dart:async';

import 'package:aegis/extensions/circular_ring_buffer.dart';
import 'package:aegis/extensions/debouncer.dart';
import 'package:aegis/extensions/semaphore.dart';
import 'package:aegis/models/alerts/alert_event.dart';
import 'package:aegis/services/alerts/alert_db_service.dart';
import 'package:aegis/services/websocket_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'alerts_realtime_service.g.dart';

class AlertOverlayDetails {
  final AlertEvent event;
  final bool seen;
  final bool expanded;

  AlertOverlayDetails({required this.event, required this.seen, required this.expanded});
}

class ShownAlerts {
  final RingBuffer<AlertOverlayDetails> alerts;

  const ShownAlerts({
    required this.alerts,
  });

  factory ShownAlerts.empty() {
    return ShownAlerts(alerts: RingBuffer(100));
  }

  ShownAlerts copyWith({RingBuffer<AlertOverlayDetails>? alerts}) {
    return ShownAlerts(alerts: alerts ?? this.alerts);
  }

  ShownAlerts markAsSeen() {
    alerts.mapInPlace((r) => AlertOverlayDetails(event: r.event, seen: true, expanded: r.expanded));
    return ShownAlerts(alerts: alerts);
  }

  ShownAlerts setExpanded(int alertId, bool value) {
    alerts.mapInPlace((r) {
      if (r.event.id == alertId) {
        return AlertOverlayDetails(event: r.event, seen: r.seen, expanded: value);
      }
      return r;
    });

    return ShownAlerts(alerts: alerts);
  }

  int get unseenCount => alerts.items.where((r) => !r.seen).length;
}

@riverpod
class AlertsRealtimeService extends _$AlertsRealtimeService {
  ShownAlerts _unseenAlerts = ShownAlerts.empty();
  final Debouncer _unseenDebouncer = Debouncer();

  Semaphore serviceReady = Semaphore();
  Timer? _pollerTimer;

  @override
  Future<ShownAlerts> build() async {
    
    final wsState = ref.watch(websocketServiceProvider);
    serviceReady.reset();

    await wsState.connected.future;
    
    _attachRxMessageListener();
    _pollerTimer = _createPoller();

    ref.onDispose(() {
      _pollerTimer?.cancel();
    });

    serviceReady.signal();

    return ShownAlerts.empty();
  }

  // TODO: Why is this here?
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
      _unseenAlerts.alerts.push(AlertOverlayDetails(event: alert, seen: false, expanded: false));

      _unseenDebouncer.run(() {
        state = AsyncValue.data(ShownAlerts(alerts: _unseenAlerts.alerts));
      });
    });
  }

  void markAsSeen() {
    _unseenAlerts = state.value!.markAsSeen();
    state = AsyncValue.data(_unseenAlerts);
  }

  void setExpanded(int alertId, bool value) {
    _unseenAlerts = state.value!.setExpanded(alertId, value);
  }
}