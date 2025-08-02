import 'package:flutter/material.dart';

class ContentArea extends StatelessWidget {
  const ContentArea({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Main Content Area',
        style: TextStyle(fontSize: 24, color: Colors.black87),
      ),
    );
  }
}
