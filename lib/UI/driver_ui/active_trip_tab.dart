import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:triconnect/UI/driver_ui/widgets/trip_chat_screen.dart';
import 'package:triconnect/UI/driver_ui/widgets/trip_info_card.dart';
import 'package:triconnect/UI/driver_ui/widgets/trip_map.dart';
import 'package:triconnect/services/auth_service.dart';
import 'package:triconnect/services/firestore_service.dart';
import 'package:triconnect/services/notification_service.dart';

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

class ActiveTripTab extends StatefulWidget {
  final String? rideId;

  const ActiveTripTab({super.key, this.rideId});

  @override
  State<ActiveTripTab> createState() => _ActiveTripTabState();
}

class _ActiveTripTabState extends State<ActiveTripTab> {
  static const _navy = Color(0xFF1A2744);

  final AuthService _authService = AuthService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirestoreService _firestoreService = FirestoreService();

  bool _completing = false;

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _callRider(String? phone) async {
    final number = phone?.trim() ?? '';
    if (number.isEmpty) {
      _showSnack("This rider hasn't added a phone number yet.");
      return;
    }
    final uri = Uri(scheme: 'tel', path: number);
    try {
      final launched = await launchUrl(uri);
      if (!launched) _showSnack("Couldn't open the dialer.");
    } catch (e) {
      _showSnack("Couldn't open the dialer: $e");
    }
  }

  void _openChat(String rideId, String riderName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            TripChatScreen(rideId: rideId, otherPartyName: riderName),
      ),
    );
  }

  Future<void> _completeTrip(DocumentSnapshot rideDoc) async {
    final data = rideDoc.data() as Map<String, dynamic>;
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;

    setState(() => _completing = true);
    try {
      final pickup = _cleanAddress(data['pickupAddress'] ?? data['pickup']);
      final destination = _cleanAddress(
        data['destinationAddress'] ?? data['destination'],
      );
      final fare = (data['fare'] as num?)?.toDouble() ?? 0.0;
      final riderId = data['userId'] as String?;

      await rideDoc.reference.update({
        'status': 'completed',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _firestoreService.saveRideHistory(
        rideId: rideDoc.id,
        customerId: riderId ?? '',
        driverId: uid,
        pickupAddress: pickup,
        destinationAddress: destination,
        fare: fare,
      );

      if (riderId != null && riderId.isNotEmpty) {
        await _db.collection('notifications').add({
          'uid': riderId,
          'title': 'Trip completed',
          'body':
              'Your trip to $destination has been completed. Thanks for riding with TriConnect!',
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      NotificationService().showNotification(
        id: 11,
        title: 'Trip completed',
        body: 'You completed the trip to $destination.',
      );

      if (mounted) {
        _showSnack(
          "Trip completed! ₱${fare.toStringAsFixed(2)} added to your earnings.",
        );
        Navigator.pop(context);
      }
    } catch (e) {
      _showSnack("Couldn't complete the trip: $e");
    } finally {
      if (mounted) setState(() => _completing = false);
    }
  }

  Future<void> _cancelTrip(DocumentSnapshot rideDoc) async {
    final data = rideDoc.data() as Map<String, dynamic>;
    try {
      await rideDoc.reference.update({
        'status': 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      final riderId = data['userId'] as String?;
      if (riderId != null && riderId.isNotEmpty) {
        await _db.collection('notifications').add({
          'uid': riderId,
          'title': 'Ride cancelled',
          'body':
              'Your driver cancelled the trip. Please request another ride.',
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      if (mounted) {
        _showSnack("Trip cancelled.");
        Navigator.pop(context);
      }
    } catch (e) {
      _showSnack("Couldn't cancel the trip: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final rideId = widget.rideId;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text("Active Trip"),
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: rideId == null
          ? const Center(child: Text("No active trip selected."))
          : StreamBuilder<DocumentSnapshot>(
              stream: _db.collection('rides').doc(rideId).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                }
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: _navy),
                  );
                }
                if (!snapshot.data!.exists) {
                  return const Center(
                    child: Text("This ride no longer exists."),
                  );
                }

                final rideDoc = snapshot.data!;
                final data = rideDoc.data() as Map<String, dynamic>;
                final status = (data['status'] ?? 'accepted') as String;
                final pickup = _cleanAddress(
                  data['pickupAddress'] ?? data['pickup'],
                );
                final destination = _cleanAddress(
                  data['destinationAddress'] ?? data['destination'],
                );
                final fare = (data['fare'] as num?)?.toDouble() ?? 0.0;
                final riderId = data['userId'] as String?;
                final pickupLat = (data['pickupLat'] as num?)?.toDouble();
                final pickupLng = (data['pickupLng'] as num?)?.toDouble();
                final destLat = (data['destinationLat'] as num?)?.toDouble();
                final destLng = (data['destinationLng'] as num?)?.toDouble();

                if (status == 'completed' || status == 'cancelled') {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        status == 'completed'
                            ? "This trip has already been completed."
                            : "This trip was cancelled.",
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                  );
                }

                return Column(
                  children: [
                    Stack(
                      children: [
                        TripMap(
                          pickupLat: pickupLat,
                          pickupLng: pickupLng,
                          destLat: destLat,
                          destLng: destLng,
                        ),
                        Positioned(
                          top: 12,
                          left: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: _navy,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.navigation_outlined,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    "Heading to: $destination",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: TripInfoCard(
                          riderId: riderId,
                          pickup: pickup,
                          destination: destination,
                          fare: fare,
                          busy: _completing,
                          onCall: _callRider,
                          onChat: (riderName) =>
                              _openChat(rideDoc.id, riderName),
                          onCancel: () => _cancelTrip(rideDoc),
                          onComplete: () => _completeTrip(rideDoc),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
