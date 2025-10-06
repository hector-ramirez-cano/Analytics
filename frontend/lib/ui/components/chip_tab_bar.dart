import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_analytics/services/canvas_tab_notifier.dart';
import 'package:network_analytics/ui/components/chip_tab.dart';
import 'package:network_analytics/ui/components/closable_chip.dart';
import 'package:reorderables/reorderables.dart';
class ChipTabBar extends StatelessWidget {

  const ChipTabBar({super.key});

  List<Widget> _makeChipTabs(CanvasTabNotifier notifier, UniqueKey? selected) {

    closeTab(id) => notifier.remove(id);
    selectTab(id) => notifier.setSelected(id);

    return notifier.getTabsByOrder()
      .map(
        (element) => ClosableChipTab(
            label: element.$2,
            onClose: () => closeTab(element.$1),
            onClick: () => selectTab(element.$1),
            selected: selected == element.$1,
            key: element.$1,
          )
      ).toList();
  }

  Widget _makeTabBar(CanvasTabNotifier notifier, List<Widget> children) {
    openTab() => notifier.append("Nueva Vista");
    onReorder(oldIndex, newIndex) => notifier.reoder(oldIndex, newIndex);

    return SizedBox(

        height: 32,
        child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ReorderableWrap(
                spacing: 0,
                runSpacing: 0,
                direction: Axis.horizontal,
                needsLongPressDraggable: false,
                onReorder: onReorder,
                children: children,
              ),

              // Fixed
              ChipTab(key: UniqueKey(), label: "+", selected: false, onClick: openTab)
            ],
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return 
      Consumer(builder: 
        (context, ref, child) {
          var _ = ref.watch(canvasTabProvider).tabs;
          var selected = ref.watch(canvasTabProvider).selected;
          var notifier = ref.watch(canvasTabProvider.notifier);
          var children = _makeChipTabs(notifier, selected);

          return Scrollbar(
            thumbVisibility: false,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: _makeTabBar(notifier, children),
            )
          );
          
        }
      );
  }
}