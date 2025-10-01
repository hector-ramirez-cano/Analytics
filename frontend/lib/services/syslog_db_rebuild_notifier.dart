import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'syslog_db_rebuild_notifier.g.dart';

@riverpod
class SyslogDbRebuildNotifier extends _$SyslogDbRebuildNotifier {
  @override
  int build() => 0;

  void markDirty() => state++;
}
