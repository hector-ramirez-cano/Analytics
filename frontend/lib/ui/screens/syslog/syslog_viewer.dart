import 'package:flutter/material.dart';
import 'package:flutter_resizable_container/flutter_resizable_container.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_analytics/providers/providers.dart';
import 'package:network_analytics/ui/components/retry_indicator.dart';
import 'package:network_analytics/ui/screens/syslog/live_log_view.dart';
import 'package:network_analytics/ui/screens/syslog/log_table.dart';

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

    final topology = ref.watch(topologyProvider);

    return topology.when(
      data   : (topology)  => LogTable(topology: topology),
      error  : (error, st) => _makeRetryIndicator(ref, context, error.toString(), st),
      loading: ()          => _makeRetryIndicator(ref, context, null, null)
    );
  }

    Widget _makeRetryIndicator(WidgetRef ref, BuildContext context, dynamic err, StackTrace? st) {
    void onRetry() async {
      final _ = ref.invalidate(syslogTableProvider);
    }

    return Center(
      child: RetryIndicator(onRetry: () async => onRetry(), isLoading: err != null, error: err,)
    );
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

    return ResizableContainer(
        direction: Axis.vertical,
        controller: syslogViewerController,
        children: _makeContainers(ref)
      );
  }
}