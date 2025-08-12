import 'package:flutter_riverpod/flutter_riverpod.dart';

class ItemSelection {
  final int? selected;
  final bool forced;

  const ItemSelection({
    required this.selected,
    required this.forced
  });
}

class ItemSelectionNotifier extends StateNotifier<ItemSelection?> {
  ItemSelectionNotifier() : super(null);

  void setSelected(int? id, bool forced) => state = ItemSelection(selected: id, forced: forced);
}
