import 'package:network_analytics/extensions/semaphore.dart';
import 'package:network_analytics/services/websocket_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'device_health_realtime_service.g.dart';

@riverpod
class DeviceHealthRealtimeService extends _$DeviceHealthRealtimeService {
  Semaphore serviceReady = Semaphore();

  void _attachRxMessageListener() {
    ref.read(websocketServiceProvider.notifier).attachListener('link', 'link', (json) {
      final decoded = extractBody('link', json, (_) => {}); // TODO: Handle error
      
      

    });
  }

  @override
  void build() {
    
    final _ = ref.watch(websocketServiceProvider);
    serviceReady.reset();

    _attachRxMessageListener();

    return;
  }

}