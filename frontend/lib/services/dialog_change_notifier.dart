import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'dialog_change_notifier.g.dart';

@riverpod
class DialogRebuildNotifier extends _$DialogRebuildNotifier {
  @override
  int build() => 0;

  void markDirty() => state++;
}
