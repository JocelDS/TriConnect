import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:triconnect/services/auth_service.dart';

const List<String> _placeholderAddresses = [
  'tap on the map or search a place',
  'locating address...',
  'tap to pin on map',
];

String _cleanAddress(dynamic raw, {String fallback = "Not specified"}) {
  final text = (raw as String?)?.trim() ?? '';
  if (text.isEmpty || _placeholderAddresses.contains(text.toLowerCase())) {
    return fallback;
  }
  return text;
}

double _deg2rad(double deg) => deg * (math.pi / 180);

double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0;
  final dLat = _deg2rad(lat2 - lat1);
  final dLon = _deg2rad(lon2 - lon1);
  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_deg2rad(lat1)) *
          math.cos(_deg2rad(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return r * c;
}

/// Card for a single pending ride request on the driver dashboard, with
/// Accept / Decline actions wired to Firestore via the callbacks below.
class RideRequestCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final LatLng driverPosition;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const RideRequestCard({
    super.key,
    required this.doc,
    required this.driverPosition,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final riderId = data['userId'] as String?;
    final pickup = _cleanAddress(data['pickupAddress'] ?? data['pickup']);
    final destination = _cleanAddress(
      data['destinationAddress'] ?? data['destination'],
    );
    final fare = (data['fare'] as num?)?.toDouble() ?? 0.0;

    String distanceLabel = "Distance unavailable";
    final pickupLat = (data['pickupLat'] as num?)?.toDouble();
    final pickupLng = (data['pickupLng'] as num?)?.toDouble();
    if (pickupLat != null && pickupLng != null) {
      final km = _distanceKm(
        driverPosition.latitude,
        driverPosition.longitude,
        pickupLat,
        pickupLng,
      );
      distanceLabel = "${km.toStringAsFixed(1)} km away";
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(
                radius: 18,
                backgroundColor: Color(0xFFE5EAF5),
                child: Icon(Icons.person, color: Color(0xFF2F5BD3)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FutureBuilder<Map<String, dynamic>?>(
                      future: riderId == null
                          ? null
                          : AuthService().getUserProfile(riderId),
                      builder: (context, snapshot) {
                        final name =
                            snapshot.data?['fullName'] as String? ?? "Rider";
                        return Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A2744),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 2),
                    Text(
                      distanceLabel,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "₱${fare.toStringAsFixed(2)}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2F5BD3),
                      fontSize: 16,
                    ),
                  ),
                  const Text(
                    "Estimated Fare",
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF2F5BD3),
                        width: 2,
                      ),
                    ),
                  ),
                  Container(width: 2, height: 26, color: Colors.grey.shade300),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Color(0xFF1A2744),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "PICKUP",
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      pickup,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF1A2744),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      "DESTINATION",
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      destination,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF1A2744),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : onDecline,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1A2744),
                    side: const BorderSide(color: Color(0xFFD8DEEA)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text("Decline"),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: busy ? null : onAccept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A2744),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: busy
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          "Accept Ride",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
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
