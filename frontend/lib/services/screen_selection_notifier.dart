import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_analytics/ui/components/enums/workplace_screen.dart';

class ScreenSelection {
  final WorkplaceScreen? selected;

  const ScreenSelection({
    required this.selected,
  });
}

class ScreenSelectionNotifier extends StateNotifier<ScreenSelection> {
  ScreenSelectionNotifier() : super(ScreenSelection(selected: WorkplaceScreen.canvas));

  void setSelected(WorkplaceScreen? selection) => state = ScreenSelection(selected: selection);
}
