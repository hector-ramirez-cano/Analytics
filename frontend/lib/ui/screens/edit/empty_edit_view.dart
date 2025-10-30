import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aegis/models/topology.dart';
import 'package:aegis/services/item_edit_selection_notifier.dart';
import 'package:aegis/ui/screens/edit/commons/edit_commons.dart';

class EmptyEditView extends StatelessWidget {
  final Topology topology;

  const EmptyEditView({
    super.key,
    required this.topology,
  });

  Widget _makeFooter() {
    return Consumer(builder:(context, ref, child) {
      final notifier = ref.watch(itemEditSelectionProvider.notifier);

      if (notifier.hasChanges) {
        return makeFooter(ref, topology);
      } 

      return SizedBox.shrink();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min, // keeps the column as small as possible
          children: [
            Spacer(),
            Icon(Icons.category_outlined, size: 128, color: Colors.blueGrey,),
            SizedBox(height: 12), // spacing between icon and text
            Text("Selecciona un dispositivo, enlace o grupo para editarlo"),
            Spacer(),
            _makeFooter(),
          ],
        ),
      ),
    );
  }
}