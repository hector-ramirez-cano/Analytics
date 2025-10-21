import 'package:network_analytics/models/device.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'syslog_device_filter_notifier.g.dart';

@riverpod
class SyslogDeviceFilterNotifier extends _$SyslogDeviceFilterNotifier {
  @override
  Set<Device> build() => {};

  void setFilter(Set<Device> devices) => state = devices;

  void add(Device d) {
    state = Set.from(state)..add(d);
  }

  void remove(Device d) {
    state = Set.from(state)..remove(d);
  }
}
