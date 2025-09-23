import 'package:flutter/material.dart';
import 'package:flutter_resizable_container/flutter_resizable_container.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_analytics/ui/screens/syslog/live_log_view.dart';
import 'package:network_analytics/ui/screens/syslog/log_table.dart';

class SyslogViewer extends StatefulWidget {
  const SyslogViewer({super.key});

  @override
  State<SyslogViewer> createState() => _SyslogViewerState();
}

class _SyslogViewerState extends State<SyslogViewer> {
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
    return LogTable();
  }

  List<ResizableChild> _makeContainers(WidgetRef ref) {

    return [
      ResizableChild(
        size: ResizableSize.shrink(min: 250),
        child: _makeSyslogRealtimeViewer(ref)
      ),
      ResizableChild(
        size: ResizableSize.expand(min: 300),
        child: _makeLogTable(ref)
      )
    ];
  }

  @override
  Widget build(BuildContext context) {

    return Consumer(builder: (context, ref, child) => 
      ResizableContainer(
          direction: Axis.vertical,
          controller: syslogViewerController,
          children: _makeContainers(ref)
        )
    ,);
  }
}