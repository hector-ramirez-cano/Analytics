import 'dart:async';
import 'package:logger/web.dart';
import 'package:network_analytics/extensions/circular_ring_buffer.dart';
import 'package:network_analytics/services/app_config.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

part 'syslog_realtime_service.g.dart';

class WsSyslogMessage {
  final RingBuffer<String> queue;
  final int version;

  WsSyslogMessage({
    required this.queue,
    required this.version,
  }); 


  factory WsSyslogMessage.empty() =>
      WsSyslogMessage(queue: RingBuffer<String>(AppConfig.getOrDefault("syslog/max_buffer_lines")), version: 0);

  // immutable "copy" with bumped version
  WsSyslogMessage bump() => WsSyslogMessage(queue: queue, version: version + 1);

  @override
  String toString() {
    return queue.toString();
  }
}

@riverpod
class SyslogRealtimeService extends _$SyslogRealtimeService {
  WebSocketChannel? _channel;
  StreamSubscription? _sub;

  @override
  WsSyslogMessage build() {
    _connect();
    ref.onDispose(_dispose);
    return WsSyslogMessage.empty();
  }

  void _connect() {
    _channel = WebSocketChannel.connect(
      Uri.parse(AppConfig.getOrDefault("ws/syslog_ws_endpoint"))
    );

    _sub = _channel!.stream.listen((data) {
      final parsed = _parseMessage(data);
      
      state.queue.push(parsed);

      // force riverpod to update the widgets
      state = state.bump();


      Logger().d("RX'd $parsed, length=${state.queue.length}");
    });
  }

  String _parseMessage(dynamic data) {
    return data.toString();
  }

  void send(String msg) {
    _channel?.sink.add(msg);
  }

  void _dispose() {
    _sub?.cancel();
    _channel?.sink.close(status.normalClosure);
  }
}
