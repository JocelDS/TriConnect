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
    required this.onCancel,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FutureBuilder<Map<String, dynamic>?>(
            future: riderId == null
                ? null
                : AuthService().getUserProfile(riderId!),
            builder: (context, riderSnapshot) {
              final name =
                  riderSnapshot.data?['fullName'] as String? ?? "Rider";
              final phone = riderSnapshot.data?['phone'] as String?;
              return Row(
                children: [
                  const CircleAvatar(
                    radius: 22,
                    backgroundColor: Color(0xFFE5EAF5),
                    child: Icon(Icons.person, color: Color(0xFF2F5BD3)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          pickup,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.call, color: Color(0xFF2F5BD3)),
                    onPressed: () => onCall(phone),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.chat_bubble_outline,
                      color: Color(0xFF2F5BD3),
                    ),
                    onPressed: () => onChat(name),
                  ),
                ],
              );
            },
          ),
          const Divider(height: 28),
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 16,
                color: Colors.grey,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  "Pickup: $pickup",
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.flag_outlined, size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  "Destination: $destination",
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                "₱",
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                fare.toStringAsFixed(2),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2F5BD3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onCancel,
                  icon: const Icon(Icons.close),
                  label: const Text("Cancel Trip"),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: busy ? null : onComplete,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2F5BD3),
                  ),
                  icon: busy
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.check_circle_outline,
                          color: Colors.white,
                        ),
                  label: const Text(
                    "Complete Trip",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
