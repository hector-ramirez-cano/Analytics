import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_resizable_container/flutter_resizable_container.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aegis/ui/screens/syslog/live_log_view.dart';
import 'package:aegis/ui/screens/syslog/log_table.dart';

class SyslogViewer extends ConsumerStatefulWidget {

  const SyslogViewer({
    super.key,
  });

  @override
  ConsumerState<SyslogViewer> createState() => _SyslogViewerState();
}

class _SyslogViewerState extends ConsumerState<SyslogViewer> {
  final logViewerHeightNotifier = ValueNotifier(250.0);
  final syslogViewerController = ResizableController();

  @override void initState() {
    super.initState();

    syslogViewerController.addListener(() {
      logViewerHeightNotifier.value = syslogViewerController.pixels.first;
    },);
  }

  Widget _makeSyslogRealtimeViewer(WidgetRef ref) {
    return LiveLogViewer(height: logViewerHeightNotifier);
  }

  Widget _makeLogTable(WidgetRef ref) {
    return LogTable(key: Key("SyslogDbTable"));
  }

  List<ResizableChild> _makeContainers(BuildContext context, WidgetRef ref) {
    final height = MediaQuery.of(context).size.height;
    return [
      ResizableChild(
        size: ResizableSize.shrink(min: min(height*0.3, 250)),
        child: _makeSyslogRealtimeViewer(ref),
        divider: const ResizableDivider(
          thickness: 2,
          color: Color.fromRGBO(100, 100, 100, 0.5)
        )
      ),
      ResizableChild(
        size: ResizableSize.expand(min: min(height*0.3, 300)),
        child: _makeLogTable(ref)
      )
    ];
  }

  @override
  Widget build(BuildContext context) {

    return ResizableContainer(
        direction: Axis.vertical,
        controller: syslogViewerController,
        children: _makeContainers(context, ref)
      );
  }
}