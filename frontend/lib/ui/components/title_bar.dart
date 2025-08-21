import 'package:flutter/material.dart';
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
      'Flutter IDE UI',
      style: TextStyle(fontSize: 20, color: Colors.white),
    );
  }

  Widget _buildSearchBar() {
    return Expanded(
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search...',
          hintStyle: const TextStyle(color: Colors.white70),
          filled: true,
          fillColor: Colors.grey.shade700,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          suffixIcon: const Icon(Icons.search, color: Colors.white),
        ),
        style: const TextStyle(color: Colors.white),
      ),
    );
  }
}
