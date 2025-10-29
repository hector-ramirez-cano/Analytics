import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_analytics/extensions/circular_ring_buffer.dart';
import 'package:network_analytics/services/realtime/syslog_realtime_service.dart';

class LiveLogViewer extends ConsumerStatefulWidget {
  final ValueNotifier<double> height;

  const LiveLogViewer({
    required this.height,
    super.key
  });

  @override
  ConsumerState<LiveLogViewer> createState() => _LiveLogViewerState();
}

class _LiveLogViewerState extends ConsumerState<LiveLogViewer> {
  final ScrollController _verticalController = ScrollController();
  bool _autoScroll = true;
  
  @override
  void initState() {
    super.initState();

    _verticalController.addListener(() {
      // If user scrolls up, stop auto-scrolling
      if (_verticalController.offset <
          _verticalController.position.maxScrollExtent) {
        _autoScroll = false;
      } else {
        _autoScroll = true;
      }
    });
  }

  @override
  void dispose() {
    super.dispose();

    _verticalController.dispose();
  }

  Widget _makeContent(RingBuffer logs) {

    return ListView.builder(
      controller: _verticalController,
      itemCount: logs.length,
      physics: const ClampingScrollPhysics(),
      shrinkWrap: true,
      itemBuilder: (context, index) {
        return Text(
          logs[index],
          style: TextStyle(color: Colors.white, fontFamily: "consolas"),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final syslog = ref.watch(syslogRealtimeServiceProvider);
    final logs = syslog.queue;

    // Schedule a post-frame callback to scroll after build
    if (_autoScroll) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_verticalController.hasClients) {
          _verticalController.jumpTo(
            _verticalController.position.maxScrollExtent,
          );
        }
      });
    }

    return ValueListenableBuilder<double>(
      valueListenable: widget.height,
      builder: (context, size, _) {
        return SizedBox(
          height: size,
          child: Scrollbar(
            thumbVisibility: true,
            trackVisibility: true,
            controller: _verticalController,
            child: Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(16),
              color: const Color.fromRGBO(43, 43, 43, 1),
              child: _makeContent(logs)
            ),
          ),
        );
      },
    );
  }

}
