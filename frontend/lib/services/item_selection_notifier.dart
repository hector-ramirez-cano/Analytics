
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'item_selection_notifier.g.dart';

class ItemSelection {
  final int? selected;
  final bool forced;

  const ItemSelection({
    required this.selected,
    required this.forced
  });
}

@riverpod
class ItemSelectionNotifier extends _$ItemSelectionNotifier {
  @override ItemSelection? build() => null;

  void setSelected(int? id, bool forced) => state = ItemSelection(selected: id, forced: forced);
}
