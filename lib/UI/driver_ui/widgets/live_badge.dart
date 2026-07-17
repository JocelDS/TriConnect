import 'package:flutter/material.dart';

/// Small pill badge showing how many ride requests are currently live.
class LiveBadge extends StatelessWidget {
  final int count;

  const LiveBadge({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Color(0xFF2F5BD3).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.circle, size: 8, color: Color(0xFF2F5BD3)),
          const SizedBox(width: 6),
          Text(
            count > 1 ? "Live · $count" : "Live",
            style: const TextStyle(
              color: Color(0xFF2F5BD3),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
