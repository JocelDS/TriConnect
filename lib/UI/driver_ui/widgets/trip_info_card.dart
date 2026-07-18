import 'package:flutter/material.dart';
import 'package:triconnect/services/auth_service.dart';

/// Rider info, pickup/destination/fare, and the Cancel / Complete Trip
/// actions shown on the active trip screen.
class TripInfoCard extends StatelessWidget {
  final String? riderId;
  final String pickup;
  final String destination;
  final double fare;
  final bool busy;
  final void Function(String? phone) onCall;
  final void Function(String riderName) onChat;
  final VoidCallback onNavigate;
  final VoidCallback onCancel;
  final VoidCallback onComplete;

  const TripInfoCard({
    super.key,
    required this.riderId,
    required this.pickup,
    required this.destination,
    required this.fare,
    required this.busy,
    required this.onCall,
    required this.onChat,
    required this.onNavigate,
    required this.onCancel,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 10),
        ],
      ),
      child: FutureBuilder<Map<String, dynamic>?>(
        future: riderId == null ? null : AuthService().getUserProfile(riderId!),
        builder: (context, riderSnapshot) {
          final name = riderSnapshot.data?['fullName'] as String? ?? 'Rider';
          final phone = riderSnapshot.data?['phone'] as String?;
          final rating = (riderSnapshot.data?['rating'] as num?)?.toDouble() ?? 5.0;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    radius: 26,
                    backgroundColor: Color(0xFFE5EAF5),
                    child: Icon(Icons.person, color: Color(0xFF2F5BD3)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.star, size: 14, color: Colors.amber.shade700),
                            const SizedBox(width: 6),
                            Text('${rating.toStringAsFixed(1)} •', style: const TextStyle(color: Colors.grey)),
                            const SizedBox(width: 6),
                            Expanded(child: Text(pickup, style: const TextStyle(color: Colors.grey), overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.call, color: Color(0xFF2F5BD3)), onPressed: () => onCall(phone)),
                  IconButton(icon: const Icon(Icons.chat_bubble_outline, color: Color(0xFF2F5BD3)), onPressed: () => onChat(name)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on_outlined, color: Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('PICKUP', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)), const SizedBox(height: 4), Text(pickup, style: TextStyle(fontSize: 13))])),
                          const SizedBox(width: 8),
                          Container(padding: const EdgeInsets.symmetric(horizontal:8, vertical:4), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)), child: const Text('3 min', style: TextStyle(fontSize: 12))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.flag_outlined, color: Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('DROP-OFF', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)), const SizedBox(height: 4), Text(destination, style: TextStyle(fontSize: 13))])),
                          const SizedBox(width: 8),
                          Container(padding: const EdgeInsets.symmetric(horizontal:8, vertical:4), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)), child: const Text('—', style: TextStyle(fontSize: 12))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: busy ? null : onComplete,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A2744),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Arrived', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
