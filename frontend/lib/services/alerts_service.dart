import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/web.dart';
import 'package:network_analytics/extensions/debouncer.dart';
import 'package:network_analytics/extensions/development_filter.dart';
import 'package:network_analytics/extensions/semaphore.dart';
import 'package:network_analytics/models/alert_event.dart';
import 'package:network_analytics/services/app_config.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

part 'alerts_service.g.dart';

final alertServiceLogger = Logger(filter: ConfigFilter.fromConfig("debug/enable_syslog_service_logging", false));

final alertWsProvider = Provider<(WebSocketChannel, Stream, Completer)> ((ref) {
    try {
      final endpoint = Uri.parse(AppConfig.getOrDefault('ws/alerts_rt_ws_endpoint'));
      final channel = WebSocketChannel.connect(endpoint);
      final stream = channel.stream.asBroadcastStream();
      final connected = Completer<void>();


      alertServiceLogger.i('Attempting to start websocket on endpoint=$endpoint');
      // TODO: Handle onError
      channel.ready.then((_) {
        alertServiceLogger.d('Websocket channel ready');
        connected.complete();
      },
        onError: (err, st) => {
          alertServiceLogger.e('Websocket failed to connect with error = $err')
        }
      );

      ref.onDispose(() {
        channel.sink.close();
      });
      return (channel, stream, connected);
    } catch (e) {
      alertServiceLogger.e(e.toString());
      rethrow;
    }
});

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
class AlertsService extends _$AlertsService {
  late Stream _stream;
  late Completer _wsCompleter;
  late StreamSubscription _streamSubscription;

  final List<AlertEvent> _unseenAlerts = [];
  final Debouncer _unseenDebouncer = Debouncer();

  Semaphore serviceReady = Semaphore();

  @override
  Future<UnseenAlerts> build() async {
    alertServiceLogger.d("Recreating AlertsServiceNotifier!");
    
    final ws = ref.watch(alertWsProvider);
    serviceReady.reset();

    _stream = ws.$2;
    _wsCompleter = ws.$3;

    await _wsCompleter.future;

    _attachRxMessageListener(_stream);

    ref.onDispose(() {
      _streamSubscription.cancel();
    });

    return UnseenAlerts.empty();
  }

  void _attachRxMessageListener(Stream stream) {
    alertServiceLogger.d('Attached Stream Subscription');
    _streamSubscription = stream.listen((message) {
      if (message is String && message.isEmpty) { return; }

      final decoded = jsonDecode(message);
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