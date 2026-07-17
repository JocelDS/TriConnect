import 'package:flutter/material.dart';

/// Generic "nothing here yet" white card used across the driver dashboard.
class EmptyStateCard extends StatelessWidget {
  final String message;

  const EmptyStateCard({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8),
        ],
      ),
      alignment: Alignment.center,
      child: Text(message, style: const TextStyle(color: Colors.grey)),
    );
  }
}
