import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aegis/services/canvas/canvas_tabs_notifier.dart';
import 'package:aegis/ui/components/chip_tab.dart';
import 'package:aegis/ui/components/closable_chip.dart';
import 'package:reorderables/reorderables.dart';
class ChipTabBar extends StatelessWidget {

  const ChipTabBar({super.key});

  List<Widget> _makeChipTabs(CanvasTabsNotifier notifier, UniqueKey? selected) {

    closeTab(id) => notifier.removeTab(id);
    selectTab(id) => notifier.setSelectedTab(id);

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

  Widget _makeTabBar(CanvasTabsNotifier notifier, List<Widget> children) {
    openTab() => {};
    onReorder(oldIndex, newIndex) => notifier.reoderTabs(oldIndex, newIndex);
    bool hasTopology = notifier.hasTopology;
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

              // Fixed at the end
              // ChipTab(key: UniqueKey(), label: "+", selected: false, onClick: hasTopology ? openTab : null)
            ],
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return 
      Consumer(builder: 
        (context, ref, child) {
          final selected = ref.watch(canvasTabsProvider).selected;
          final notifier = ref.watch(canvasTabsProvider.notifier);
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