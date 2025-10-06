import 'package:flutter/material.dart';
import 'package:flutter_resizable_container/flutter_resizable_container.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_analytics/services/drawer_state_notifier.dart';
import 'package:network_analytics/ui/components/drawer/drawer.dart';
import 'package:network_analytics/ui/components/side_nav.dart';
import 'package:network_analytics/ui/screens/content_area.dart';

class ContentBody extends StatelessWidget {
  const ContentBody({super.key});

  static const _sideNav = SideNav();
  static const _sideDrawer = SideDrawer();
  static const _contentArea =  ContentArea();


  @override
  Widget build(BuildContext context) {
    return Consumer (builder: (context, ref, child) {
      final isOpen = ref.watch(drawerStateProvider).isOpen;
      final children = [
        ResizableChild(
          child: _sideNav,
          size: ResizableSize.shrink(),
          divider: ResizableDivider(thickness: 0.1, cursor: SystemMouseCursors.basic)
        ),
        ResizableChild(
          size: ResizableSize.ratio(isOpen ? 0.2 : 0, min: isOpen ? 300 : 0, max: 600),
          child: _sideDrawer,
          divider: ResizableDivider(thickness: 1.5)
        ),
        ResizableChild(
          size: ResizableSize.expand(),
          child: _contentArea
        ),
      ];

      return ResizableContainer(
        direction: Axis.horizontal,
        children: children
      );
    },);
    
  }
}
