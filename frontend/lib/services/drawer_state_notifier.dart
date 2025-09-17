import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_analytics/ui/components/enums/workplace_screen.dart';

class DrawerState {
  final bool isOpen;
  final WorkplaceScreen screen;

  DrawerState({
    required this.isOpen,
    required this.screen,
  });

}

class DrawerStateNotifier extends StateNotifier<DrawerState>{
  DrawerStateNotifier() : super(DrawerState(isOpen: true, screen: WorkplaceScreen.canvas));

  void setOpen() {
    state = DrawerState(isOpen: true, screen: state.screen);
  }

  void setClosed() {
    state = DrawerState(isOpen: false, screen: state.screen);
  }

  void setState(bool isOpen) {
    state = DrawerState(isOpen: isOpen, screen: state.screen);
  }

  void toggleState() {
    state = DrawerState(isOpen: !state.isOpen, screen: state.screen);
  }


  

}
