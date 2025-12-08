import 'package:aegis/models/alerts/alert_event.dart';
import 'package:aegis/models/alerts/alert_severity.dart';
import 'package:aegis/models/device.dart';
import 'package:aegis/models/topology.dart';
import 'package:aegis/services/realtime/alerts_realtime_service.dart';
import 'package:aegis/services/topology/topology_provider.dart';
import 'package:aegis/theme/app_colors.dart';
import 'package:aegis/ui/components/overlays/alert_listing_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:timezone/timezone.dart' as tz;

final Map<AlertSeverity, String> emojiMapping = {
  AlertSeverity.emergency : "🆘",
  AlertSeverity.alert     : "🚨",
  AlertSeverity.critical  : "🚨",
  AlertSeverity.error     : "🚩",
  AlertSeverity.warning   : "⚠️",
  AlertSeverity.info      : "ℹ️",
  AlertSeverity.notice    : "ℹ️",
  AlertSeverity.debug     : "🕸️",
  AlertSeverity.unknown   : "❔",
};


class AlertNotificationItem extends ConsumerStatefulWidget {
  final AlertEvent event;
  final bool seen;
  final bool initialExpanded;

  const AlertNotificationItem({
    required super.key,
    required this.event,
    required this.seen,
    required this.initialExpanded,
  });

  @override
  ConsumerState<AlertNotificationItem> createState() => _AlertNotificationItemState();
}

class _AlertNotificationItemState extends ConsumerState<AlertNotificationItem> with AutomaticKeepAliveClientMixin {
  bool _expanded = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    _expanded = widget.initialExpanded;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Row(
      key: ValueKey("AlertEntry_Notification_${widget.event.id}"),
      children: [
        TweenAnimationBuilder<Color?>(
          key: ValueKey("AlertEntry_Notification_${widget.event.id}_ColorTween"),
          tween: ColorTween(begin: AppColors.alertRtColorEntry, end: AppColors.alertRtColorExit),
          duration: widget.seen ? const Duration(seconds: 0) : seenDuration,
          curve: Curves.easeInExpo,
          builder: (context, color, child) {
            return Text("•", style: TextStyle(fontSize: 32, color: color),);
          }
        ),
        Expanded(
          key: ValueKey("AlertEntry_Notification_Expanded_${widget.event.id}"),
          child: Container(
            margin: EdgeInsets.fromLTRB(0, 4, 4, 4),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.overlayBackgroundColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.overlayRtOverlayShadowColor,
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
    final String details;
    final String hostname = ref.watch(topologyServiceProvider).when(
      data: (Topology topology) {
        final Device? device = topology.items[widget.event.targetId];
        return device?.mgmtHostname ?? "Dispositivo sin hostname";
      },
      error: (_, _) => "Error al cargar", loading: () => "Cargando..."
    );
    final String name = ref.watch(topologyServiceProvider).when(
      data: (Topology topology) {
        final Device? device = topology.items[widget.event.targetId];
        return device?.name ?? "Dispositivo sin nombre";
      },
      error: (_, _) => "Error al cargar", loading: () => "Cargando..."
    );
    if (widget.event.message.isNotEmpty) {
      details = "${widget.event.message}\n\nRequiere Ack:${widget.event.requiresAck}\nValor evaluado: ${widget.event.value}\n";
    } else { details = 'Sin detalles adicionales.'; }

    final loc = tz.getLocation("America/Mexico_City");
    final String localAlertTime = tz.TZDateTime.from(widget.event.alertTime, loc).toIso8601String();

    return ExpansionTile(
      key: ValueKey("Alert_Overlay_ExpansionTile_${widget.event.id}"),
      dense: true,
      maintainState: true,
      initiallyExpanded: _expanded,
      onExpansionChanged:(value) {
        _expanded = value;
        if (mounted) {
          ref.read(alertsRealtimeServiceProvider.notifier).setExpanded(widget.event.id, value);
        }

      },
      leading: Text(
        emojiMapping[widget.event.severity] ?? '',
        style: const TextStyle(fontSize: 20),
      ),
      title: Text(
        widget.event.message,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        localAlertTime,
        style: const TextStyle(fontSize: 12, color: AppColors.overlayRtOverlaySubtitleColor),
      ),
      childrenPadding: const EdgeInsets.fromLTRB(4, 2, 4, 4),
      children: [
        Text(
          details,
          style: const TextStyle(fontSize: 12, color: AppColors.overlayRtOverlayDetailsColor),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            "Origen: $name@$hostname",
            style: const TextStyle(fontSize: 12, color: AppColors.overlayRtOverlaySubtitleColor),
          ),
        ),
      ],
    );
  }
}