import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
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

  StreamSubscription<Position>? _positionSub;
  double? _driverLat;
  double? _driverLng;

  @override
  void initState() {
    super.initState();
    _startLiveLocationTracking();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

  /// Streams the driver's GPS while the trip is active, updates the local
  /// map, and pushes the position to Firestore so the rider's app can
  /// track the driver moving toward the destination in real time.
  Future<void> _startLiveLocationTracking() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      _positionSub =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 10, // meters between updates
            ),
          ).listen((position) {
            if (!mounted) return;
            setState(() {
              _driverLat = position.latitude;
              _driverLng = position.longitude;
            });

            final rideId = widget.rideId;
            if (rideId != null) {
              _firestoreService
                  .updateDriverLiveLocation(
                    rideId: rideId,
                    lat: position.latitude,
                    lng: position.longitude,
                  )
                  .catchError((_) {
                    // Non-fatal — the map still works locally even if a
                    // single Firestore write fails.
                  });
            }
          });
    } catch (_) {
      // Trip still works without live tracking if the stream can't start.
    }
  }

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

  Future<void> _launchNavigation(double toLat, double toLng) async {
    final origin = _driverLat != null && _driverLng != null
        ? '${_driverLat!},${_driverLng!}'
        : null;
    final destination = '$toLat,$toLng';
    final uri = Uri.parse(origin == null
        ? 'https://www.google.com/maps/dir/?api=1&destination=$destination&travelmode=driving'
        : 'https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$destination&travelmode=driving');

    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        _showSnack('Could not open navigation app.');
      }
    } catch (e) {
      _showSnack('Navigation failed: $e');
    }
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

                return Stack(
                  children: [
                    Column(
                      children: [
                        Expanded(
                          child: TripMap(
                            pickupLat: pickupLat,
                            pickupLng: pickupLng,
                            destLat: destLat,
                            destLng: destLng,
                            driverLat: _driverLat,
                            driverLng: _driverLng,
                            onNavigate: () {
                              if (pickupLat != null && pickupLng != null) {
                                _launchNavigation(pickupLat, pickupLng);
                              } else if (destLat != null && destLng != null) {
                                _launchNavigation(destLat, destLng);
                              } else {
                                _showSnack('Navigation destination is not available.');
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: SafeArea(
                        top: false,
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(26),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                            child: TripInfoCard(
                              riderId: riderId,
                              pickup: pickup,
                              destination: destination,
                              fare: fare,
                              busy: _completing,
                              onCall: _callRider,
                              onChat: (riderName) =>
                                  _openChat(rideDoc.id, riderName),
                              onNavigate: () {
                                if (pickupLat != null && pickupLng != null) {
                                  _launchNavigation(pickupLat, pickupLng);
                                } else if (destLat != null && destLng != null) {
                                  _launchNavigation(destLat, destLng);
                                } else {
                                  _showSnack('Navigation destination is not available.');
                                }
                              },
                              onCancel: () => _cancelTrip(rideDoc),
                              onComplete: () => _completeTrip(rideDoc),
                            ),
                          ),
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
