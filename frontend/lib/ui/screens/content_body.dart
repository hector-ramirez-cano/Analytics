import 'package:flutter/material.dart';
import 'package:flutter_resizable_container/flutter_resizable_container.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aegis/services/drawer_state_notifier.dart';
import 'package:aegis/ui/components/drawer/drawer.dart';
import 'package:aegis/ui/components/side_nav.dart';
import 'package:aegis/ui/screens/content_area.dart';

class _ContentBodyConsumer extends StatelessWidget {
  final ResizableChild sideNav;
  final ResizableChild contentArea;
  final Widget sideDrawer;
  
  const _ContentBodyConsumer({
    required super.key,
    required this.sideNav,
    required this.contentArea,
    required this.sideDrawer
  });
  
  @override
  Widget build(BuildContext context) {
      return Consumer (
        key: ValueKey("Consumer_content_body"),
        builder: (context, ref, child) {
        final isOpen = ref.watch(drawerStateProvider).isOpen;
        final children = [
          sideNav,
          ResizableChild(
            key: ValueKey("Widget_ContentBody_Consumer_ResizableChild_sideDrawer"),
            size: ResizableSize.ratio(isOpen ? 0.2 : 0, min: isOpen ? 300 : 0, max: 600),
            child: sideDrawer,
            divider: ResizableDivider(thickness: 1.5)
          ),
          contentArea,
        ];

        return ResizableContainer(
          key: ValueKey("Widget_ContentBody_Consumer_ResizableContainer"),
          direction: Axis.horizontal,
          children: children
        );
      },);  
  }
}

class ContentBody extends StatelessWidget {
  const ContentBody({super.key});

  static const _sideNav = ResizableChild(
    child: SideNav(),
    size: ResizableSize.shrink(),
    divider: ResizableDivider(thickness: 0.1, cursor: SystemMouseCursors.basic)
  );

  static const _sideDrawer = SideDrawer();

  static const _contentArea = ResizableChild(
    size: ResizableSize.expand(),
    child: ContentArea()
  );

  static const _consumer = _ContentBodyConsumer(key: ValueKey("Widget_ContentBody_Consumer_container"), sideNav: _sideNav, sideDrawer: _sideDrawer, contentArea: _contentArea);
  
  @override
  Widget build(BuildContext context) {
    return _consumer;
  }
}
