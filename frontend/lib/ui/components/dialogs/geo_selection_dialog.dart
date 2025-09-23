import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:free_map/free_map.dart';
import 'package:network_analytics/services/dialog_change_notifier.dart';
import 'package:network_analytics/ui/components/geo_selector.dart';

class GeoSelectionDialog {
  LatLng initialPosition;
  Function() onClose;
  Function(LatLng) onGeoPositionChanged;


  GeoSelectionDialog({
    required this.initialPosition,
    required this.onClose,
    required this.onGeoPositionChanged,
  });

  Future show(BuildContext context) {
    final dialog = Consumer(
      builder: (context, ref, child) {
        ref.watch(dialogRebuildProvider);

        onCloseWrapper() {
          if(context.mounted && Navigator.canPop(context)) {
            Navigator.pop(context);
            onClose();
          }
        }

        return Dialog(
          child: GeoSelector(
            onClose: onCloseWrapper,
            initialPosition: initialPosition,
            onSelect: onGeoPositionChanged,
          ),
        );
      },
    );

    return showDialog(context: context, builder: (context) {
      return dialog;
    });
  }
}