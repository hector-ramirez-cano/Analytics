import 'package:flutter/material.dart';
import 'package:network_analytics/ui/components/badge_icon.dart';
import '../../theme/app_colors.dart';

class TitleBar extends StatelessWidget {
  const TitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      color: AppColors.appBarColor,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const FlutterLogo(size: 36),
          const SizedBox(width: 12),
          _buildTitle(),
          const SizedBox(width: 24),
          _buildSearchBar()
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return const Text(
      'Analytics',
      style: TextStyle(fontSize: 20, color: Colors.white),
    );
  }

  Widget _buildSearchBar() {
    String? badgeContent = "1";

    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          BadgeIcon(icon: Icon(Icons.notifications, size: 32, color: Colors.white,), badgeContent: badgeContent, tooltip: "Notificaciones",)
        ],),
    );
  }
}
