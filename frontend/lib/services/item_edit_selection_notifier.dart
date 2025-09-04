import 'package:flutter_riverpod/flutter_riverpod.dart';

class ItemEditSelection {
  final dynamic selected;

  const ItemEditSelection({
    required this.selected,
  });
}

class ItemEditSelectionNotifier extends StateNotifier<ItemEditSelection> {
  ItemEditSelectionNotifier() : super(ItemEditSelection(selected: null));

  void setSelected(dynamic selected) => state = ItemEditSelection(selected: selected);
}
