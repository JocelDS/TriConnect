import 'package:flutter/material.dart';

/// Navy header card on the driver profile: avatar, name, vehicle badge,
/// and availability status.
class ProfileHeaderCard extends StatelessWidget {
  final String name;
  final String vehicleLabel;
  final String status;

  const ProfileHeaderCard({
    super.key,
    required this.name,
    required this.vehicleLabel,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final isAvailable = status.toLowerCase() == 'available';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2744),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const CircleAvatar(
            radius: 36,
            backgroundColor: Color(0xFFE5EAF5),
            child: Icon(Icons.person, size: 36, color: Color(0xFF2F5BD3)),
          ),
          const SizedBox(height: 12),
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Text(
            "TriConnect Partner",
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.directions_car, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Text(vehicleLabel, style: const TextStyle(color: Colors.white)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isAvailable
                  ? Colors.greenAccent.withOpacity(0.2)
                  : Colors.orangeAccent.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: isAvailable ? Colors.greenAccent : Colors.orangeAccent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
