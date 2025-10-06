import 'package:network_analytics/ui/components/enums/workplace_screen.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'drawer_state_notifier.g.dart';

class DrawerState {
  final bool isOpen;
  final WorkplaceScreen screen;

  DrawerState({
    required this.isOpen,
    required this.screen,
  });
}

@riverpod
class DrawerStateNotifier extends _$DrawerStateNotifier {

  @override DrawerState build() =>  DrawerState(isOpen: true, screen: WorkplaceScreen.canvas);

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
