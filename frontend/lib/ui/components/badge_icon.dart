import 'package:flutter/material.dart';
import 'package:aegis/ui/components/universal_detector.dart';
import 'package:flutter/services.dart';

class BadgeIcon extends StatelessWidget{
  final Icon icon;
  final EdgeInsets iconPadding;
  final EdgeInsets badgePadding;
  final Color badgeColor;
  final BoxShape badgeShape;
  final BoxConstraints constrains;
  final String? badgeContent;
  final TextStyle badgeStyle;
  final String? tooltip;
  final SystemMouseCursor Function()? cursor;
  const BadgeIcon({
    super.key,
    required this.icon,
    required this.badgeContent,
    this.tooltip,
    this.cursor,
    this.iconPadding = const EdgeInsets.all(8),
    this.badgePadding = const EdgeInsets.all(4),
    this.badgeColor = Colors.red,
    this.badgeShape = BoxShape.circle,
    this.constrains = const BoxConstraints(minWidth: 16, maxWidth: 16),
    this.badgeStyle = const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
  });

  Widget _makeBadge() {
    if (badgeContent == null) {
      return SizedBox.shrink();
    }

    return Positioned(
        right: -2, top: -2,
        child: Container(
          padding: badgePadding,
          decoration : BoxDecoration( color: badgeColor, shape: BoxShape.circle, ),
          constraints: BoxConstraints( minWidth: 16, minHeight: 16, ),
          child: Text( badgeContent!, textAlign: TextAlign.center,
            style: TextStyle( color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, ),
          ),
        ),
      );
  }

  Widget _makeBadgeIcon() {
    return UniversalDetector(
      setCursor: cursor,
      child:  Stack(
        clipBehavior: Clip.none, // allow badge to overflow
        children: [ icon, _makeBadge() ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    if (tooltip == null) {
      return _makeBadgeIcon();
    }

    return Padding(
      padding: iconPadding,
      child: Tooltip(
        message: tooltip!,
        waitDuration: Duration(milliseconds: 800),
        child: _makeBadgeIcon(),
      ),
    );

  }
}
