import 'package:network_analytics/ui/components/enums/workplace_screen.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'drawer_state_notifier.g.dart';

class _DrawerState {
  final bool isOpen;
  final WorkplaceScreen screen;

  _DrawerState({
    required this.isOpen,
    required this.screen,
  });
}

@riverpod
class DrawerState extends _$DrawerState {

  @override _DrawerState build() =>  _DrawerState(isOpen: true, screen: WorkplaceScreen.canvas);

  void setOpen() {
    state = _DrawerState(isOpen: true, screen: state.screen);
  }

  void setClosed() {
    state = _DrawerState(isOpen: false, screen: state.screen);
  }

  void setState(bool isOpen) {
    state = _DrawerState(isOpen: isOpen, screen: state.screen);
  }

  void toggleState() {
    state = _DrawerState(isOpen: !state.isOpen, screen: state.screen);
  }

  

}
