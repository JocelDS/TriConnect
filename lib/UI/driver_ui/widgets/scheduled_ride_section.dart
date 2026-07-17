import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'empty_state_card.dart';

/// Shows the next scheduled ride (status == 'scheduled'), or an honest
/// empty state if there isn't one yet.
class ScheduledRideSection extends StatelessWidget {
  const ScheduledRideSection({super.key});

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;

    return StreamBuilder<QuerySnapshot>(
      stream: db
          .collection('rides')
          .where('status', isEqualTo: 'scheduled')
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF1A2744)),
          );
        }
        if (docs.isEmpty) {
          return const EmptyStateCard(message: "No scheduled rides yet.");
        }

        final data = docs.first.data() as Map<String, dynamic>;
        final destination =
            (data['destinationAddress'] ?? data['destination'] ?? '-')
                as String;
        final fare = (data['fare'] as num?)?.toDouble() ?? 0.0;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F2F7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.schedule,
                  color: Color(0xFF1A2744),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Scheduled Ride",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A2744),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "To $destination",
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Text(
                "₱${fare.toStringAsFixed(2)}",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A2744),
                  fontSize: 15,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
