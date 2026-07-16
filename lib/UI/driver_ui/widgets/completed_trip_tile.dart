import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:triconnect/services/auth_service.dart';

/// One row in the Earnings screen's completed-trips list.
class CompletedTripTile extends StatelessWidget {
  final QueryDocumentSnapshot doc;

  const CompletedTripTile({super.key, required this.doc});

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final timeText = "$hour:$minute $period";

    if (day == today) return "Today, $timeText";
    if (day == today.subtract(const Duration(days: 1)))
      return "Yesterday, $timeText";
    return "${dt.month}/${dt.day}, $timeText";
  }

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final riderId = data['customerId'] as String?;
    final fare = (data['fare'] as num?)?.toDouble() ?? 0.0;
    final destination = (data['destinationAddress'] ?? '-') as String;
    final ts = data['completedAt'];
    final timeLabel = ts is Timestamp ? _formatTimestamp(ts.toDate()) : '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6),
        ],
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 16,
            backgroundColor: Color(0xFFE5EAF5),
            child: Icon(Icons.person, size: 18, color: Color(0xFF2F5BD3)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FutureBuilder<Map<String, dynamic>?>(
                  future: riderId == null || riderId.isEmpty
                      ? null
                      : AuthService().getUserProfile(riderId),
                  builder: (context, snapshot) {
                    final name =
                        snapshot.data?['fullName'] as String? ?? "Rider";
                    return Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    );
                  },
                ),
                Text(
                  "$timeLabel · To $destination",
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            "₱${fare.toStringAsFixed(2)}",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF2F5BD3),
            ),
          ),
        ],
      ),
    );
  }
}
