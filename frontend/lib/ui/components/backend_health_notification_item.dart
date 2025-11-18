import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final Map<bool, String> emojiMapping = {
  true : "✅",
  false: "❌",
};



class BackendHealthNotificationItem extends ConsumerStatefulWidget {
  final bool up;
  final String message;
  final String which;

  const BackendHealthNotificationItem({
    required super.key,
    required this.up,
    required this.message,
    required this.which,
  });

  @override
  ConsumerState<BackendHealthNotificationItem> createState() => _AlertNotificationItemState();
}

class _AlertNotificationItemState extends ConsumerState<BackendHealthNotificationItem> with AutomaticKeepAliveClientMixin {

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Row(
      key: ValueKey("BackendHealth_Notification_${widget.which}"),
      children: [
        
        Expanded(
          key: ValueKey("BackendHealth_Notification_Expanded_${widget.which}"),
          child: Container(
            margin: EdgeInsets.fromLTRB(0, 4, 4, 4),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 4,
                  offset: const Offset(0, 0),
                ),
              ],
            ),
            child: _makeContents(),
          ),
        )
      ],
    );
  }

  Widget _makeContents() {
      return ExpansionTile(
      key: ValueKey("Alert_Overlay_ExpansionTile_${widget.which}"),
      dense: true,
      maintainState: true,
      leading: Text(
        widget.up ? "✅" : "❌",
        style: TextStyle(
          fontSize: 20,
          color: widget.up ? Colors.green : Colors.red,
        ),
      ),
      title: Text(
        widget.which,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        widget.up ? "UP" : "DOWN",
        style: const TextStyle(fontSize: 12, color: Colors.black54),
      ),
      childrenPadding: const EdgeInsets.fromLTRB(4, 2, 4, 4),
      children: [
        Align(
          alignment: AlignmentGeometry.centerLeft,
          child: Text(
            widget.message,
            style: const TextStyle(fontSize: 12, color: Colors.black87),
          ),
        ),
      ],
    );
  }
}