import 'package:network_analytics/extensions/circular_ring_buffer.dart';
import 'package:network_analytics/extensions/semaphore.dart';
import 'package:network_analytics/services/app_config.dart';
import 'package:network_analytics/services/syslog/syslog_db_service.dart';
import 'package:network_analytics/services/websocket_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

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


  Semaphore serviceReady = Semaphore();


  void _attachRxMessageListener() {
    ref.read(websocketServiceProvider.notifier).attachListener('syslog-rt', (json) {
      final decoded = extractBody('syslog-rt', json, (_) => {}); // TODO: Handle error

      state.queue.push(decoded);

      // force riverpod to update the widgets
      state = state.bump();

      SyslogDbService.logger.d("RX'd $decoded, length=${state.queue.length}");
    });
  }

  @override
  WsSyslogMessageQueue build() {
    
    final _ = ref.watch(websocketServiceProvider);
    serviceReady.reset();

    _attachRxMessageListener();

    return WsSyslogMessageQueue.empty();
  }

}