import 'dart:async';

import 'package:network_analytics/extensions/debouncer.dart';
import 'package:network_analytics/extensions/semaphore.dart';
import 'package:network_analytics/models/alerts/alert_event.dart';
import 'package:network_analytics/services/alert_db_service.dart';
import 'package:network_analytics/services/websocket_service.dart';
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

  @override
  Future<UnseenAlerts> build() async {
    
    final _ = ref.watch(websocketServiceProvider);
    serviceReady.reset();

    _attachRxMessageListener();

    ref.onDispose(() {
    });

    return UnseenAlerts.empty();
  }

  void _attachRxMessageListener() {
    alertServiceLogger.d('Attached Stream Subscription');
    ref.read(websocketServiceProvider.notifier).attachListener('alerts-rt', (json) {
      final decoded = extractBody('alerts-rt', json, (_) => {}); // TODO:_Handle onError

      // if the message is not addressed to us
      if (decoded == null) {return;}

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