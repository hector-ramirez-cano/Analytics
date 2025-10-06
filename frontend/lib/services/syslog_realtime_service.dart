import 'dart:async';
import 'package:network_analytics/extensions/circular_ring_buffer.dart';
import 'package:network_analytics/services/app_config.dart';
import 'package:network_analytics/services/syslog_db_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

part 'syslog_realtime_service.g.dart';

class WsSyslogMessageQueue {
  WsSyslogMessageQueue({
    required this.queue,
    required this.version,
  }); 

  factory WsSyslogMessageQueue.empty() =>
      WsSyslogMessageQueue(queue: RingBuffer<String>(AppConfig.getOrDefault("syslog/max_buffer_lines")), version: 0);

  final RingBuffer<String> queue;
  final int version;

  @override
  String toString() {
    return queue.toString();
  }

  // immutable "copy" with bumped version, shallow copies the queue, and increases the version to notify a change
  WsSyslogMessageQueue bump() => WsSyslogMessageQueue(queue: queue, version: version + 1);
}

@riverpod
class SyslogRealtimeService extends _$SyslogRealtimeService {
  WebSocketChannel? _channel;
  StreamSubscription? _sub;

  void send(String msg) {
    _channel?.sink.add(msg);
  }

  void _connect() {
    _channel = WebSocketChannel.connect(
      Uri.parse(AppConfig.getOrDefault("ws/syslog_rt_ws_endpoint"))
    );

    // TODO: Add on cancel handling
    _sub = _channel!.stream.listen((data) {
        final parsed = _parseMessage(data);
        
        state.queue.push(parsed);

        // force riverpod to update the widgets
        state = state.bump();

        SyslogDbService.logger.d("RX'd $parsed, length=${state.queue.length}");
      },
      onDone: _handleDone,
      onError: _handleError
    );
  }

  String _parseMessage(dynamic data) {
    return data.toString();
  }

  void _dispose() {
    _sub?.cancel();
    _channel?.sink.close(status.normalClosure);
  }

  void _handleError(dynamic error) {
    SyslogDbService.logger.e('WebSocket error: $error');
  }

  void _handleDone() {
    SyslogDbService.logger.w('WebSocket connection closed');
    // Optionally update state or trigger reconnection
  }

  @override
  WsSyslogMessageQueue build() {
    _connect();
    ref.onDispose(_dispose);
    return WsSyslogMessageQueue.empty();
  }
}
