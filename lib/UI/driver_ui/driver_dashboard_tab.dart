import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:triconnect/UI/driver_ui/active_trip_tab.dart';
import 'package:triconnect/UI/driver_ui/widgets/dashboard_top_bar.dart';
import 'package:triconnect/UI/driver_ui/widgets/earnings_card.dart';
import 'package:triconnect/UI/driver_ui/widgets/empty_state_card.dart';
import 'package:triconnect/UI/driver_ui/widgets/live_badge.dart';
import 'package:triconnect/UI/driver_ui/widgets/ride_request_card.dart';
import 'package:triconnect/UI/driver_ui/widgets/stat_card.dart';
import 'package:triconnect/UI/driver_ui/widgets/traffic_map_card.dart';
import 'package:triconnect/services/auth_service.dart';
import 'package:triconnect/services/notification_service.dart';

class DriverDashboardTab extends StatefulWidget {
  const DriverDashboardTab({super.key});

  @override
  State<DriverDashboardTab> createState() => _DriverDashboardTabState();
}

class _DriverDashboardTabState extends State<DriverDashboardTab> {
  static const _navy = Color(0xFF1A2744);
  static const LatLng _defaultCenter = LatLng(
    14.0703,
    121.3255,
  ); // San Pablo City, PH

  final AuthService _authService = AuthService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  LatLng _driverPosition = _defaultCenter;
  bool _busy = false;
  bool _hasProfileAnchor = false;

  StreamSubscription<QuerySnapshot>? _pendingRidesSub;
  bool _pendingRidesBaselineSet = false;
  final Set<String> _seenPendingRideIds = {};

  StreamSubscription<Position>? _positionSub;

  String? get _uid => _authService.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _initializeDashboardLocation();
    _listenForNewRideRequests();
  }

  Future<void> _initializeDashboardLocation() async {
    await _loadDriverPositionFromProfile();
    if (!mounted) return;
    await _loadCurrentLocation();
    await _startLiveLocationTracking();
  }

  @override
  void dispose() {
    _pendingRidesSub?.cancel();
    _positionSub?.cancel();
    super.dispose();
  }

  /// Keeps `_driverPosition` continuously in sync with the device's GPS so
  /// the map can follow the driver while still preserving the profile-based
  /// home address as the primary anchor when available.
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
              distanceFilter: 15, // meters between updates
            ),
          ).listen((position) {
            if (!mounted) return;
            if (_hasProfileAnchor) return;
            setState(() {
              _driverPosition = LatLng(
                position.latitude,
                position.longitude,
              );
            });
          });
    } catch (_) {
      // Keep whatever position we already have if the stream can't start.
    }
  }

  /// Fires a real device notification whenever a genuinely *new* pending
  /// ride request comes in, so a driver gets alerted even while looking at
  /// another tab (the dashboard stays mounted in the background). The
  /// first snapshot is a baseline — existing pending rides don't all fire
  /// at once when the dashboard first loads.
  void _listenForNewRideRequests() {
    _pendingRidesSub = _db
        .collection('rides')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
          final uid = _uid;

          if (!_pendingRidesBaselineSet) {
            for (final doc in snapshot.docs) {
              _seenPendingRideIds.add(doc.id);
            }
            _pendingRidesBaselineSet = true;
            return;
          }

          for (final change in snapshot.docChanges) {
            if (change.type != DocumentChangeType.added) continue;
            final doc = change.doc;
            if (_seenPendingRideIds.contains(doc.id)) continue;
            _seenPendingRideIds.add(doc.id);

            final data = doc.data();
            final declinedBy = (data?['declinedBy'] as List?) ?? [];
            if (uid != null && declinedBy.contains(uid)) continue;

            final destination =
                (data?['destinationAddress'] ??
                        data?['destination'] ??
                        'a nearby destination')
                    as String;
            NotificationService().showNotification(
              id: doc.id.hashCode & 0x7fffffff,
              title: 'New ride request',
              body: 'A rider is requesting a trip to $destination.',
            );
          }
        });
  }

  Future<void> _loadCurrentLocation() async {
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

      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      if (_hasProfileAnchor) return;
      setState(() {
        if (_driverPosition == _defaultCenter) {
          _driverPosition = LatLng(position.latitude, position.longitude);
        }
      });
    } catch (_) {
      // Keep default center if location can't be resolved.
    }
  }

  Future<LatLng?> _resolveAddressToPosition(String address) async {
    final cleaned = address.trim();
    if (cleaned.isEmpty) return null;

    final candidates = <String>{
      cleaned,
      cleaned.replaceAll(RegExp(r'\s+'), ' '),
      '$cleaned, Philippines',
      '$cleaned, Batangas, Philippines',
      cleaned.replaceAll(RegExp(r'\s*,\s*'), ', '),
      cleaned.replaceAll(RegExp(r'\s+'), ' '),
    }.toList();

    for (final candidate in candidates) {
      try {
        final locations = await Geocoding().locationFromAddress(candidate);
        if (locations.isNotEmpty) {
          final loc = locations.first;
          return LatLng(loc.latitude, loc.longitude);
        }
      } catch (_) {
        // Try the next candidate if this one fails.
      }
    }

    return null;
  }

  /// Load the driver's saved position from their user profile in Firestore.
  /// Prefer stored numeric fields (`driverLat`/`driverLng` or `lat`/`lng`),
  /// otherwise attempt to forward-geocode the saved address fields.
  Future<void> _loadDriverPositionFromProfile() async {
    try {
      final uid = _authService.currentUser?.uid;
      if (uid == null) return;
      final profile = await _authService.getUserProfile(uid);
      if (profile == null) return;

      // Check for a saved GeoPoint first.
      final geoPoint = profile['location'] ??
          profile['geoPoint'] ??
          profile['homeLocation'] ??
          profile['driverLocation'];
      if (geoPoint is GeoPoint) {
        if (!mounted) return;
        setState(() {
          _hasProfileAnchor = true;
          _driverPosition = LatLng(geoPoint.latitude, geoPoint.longitude);
        });
        return;
      }

      // Check for numeric lat/lng stored in user doc.
      final lat = (profile['driverLat'] ??
              profile['lat'] ??
              profile['homeLat'] ??
              profile['latitude']) as num?;
      final lng = (profile['driverLng'] ??
              profile['lng'] ??
              profile['homeLng'] ??
              profile['longitude']) as num?;
      if (lat != null && lng != null) {
        if (!mounted) return;
        setState(() {
          _hasProfileAnchor = true;
          _driverPosition = LatLng(lat.toDouble(), lng.toDouble());
        });
        return;
      }

      // If no stored coordinates, try forward geocoding the saved address fields.
      final addressCandidates = <String?>[
        profile['address'] as String?,
        profile['homeAddress'] as String?,
        profile['fullAddress'] as String?,
        profile['locationAddress'] as String?,
      ];

      for (final rawAddress in addressCandidates) {
        final address = rawAddress?.trim();
        if (address == null || address.isEmpty) continue;

        final resolved = await _resolveAddressToPosition(address);
        if (resolved != null) {
          if (!mounted) return;
          setState(() {
            _hasProfileAnchor = true;
            _driverPosition = resolved;
          });
          return;
        }
      }
    } catch (_) {
      // Non-fatal — leave center at default or GPS-derived position.
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _declineRide(QueryDocumentSnapshot doc) async {
    final uid = _uid;
    if (uid == null) return;
    setState(() => _busy = true);
    try {
      await doc.reference.update({
        'declinedBy': FieldValue.arrayUnion([uid]),
      });
      _showSnack("Ride request declined.");
    } catch (e) {
      _showSnack("Couldn't decline ride: $e");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _acceptRide(QueryDocumentSnapshot doc) async {
    final uid = _uid;
    if (uid == null) return;
    setState(() => _busy = true);
    try {
      final data = doc.data() as Map<String, dynamic>;
      await doc.reference.update({
        'status': 'accepted',
        'driverId': uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final riderId = data['userId'] as String?;
      final destination =
          data['destinationAddress'] ??
          data['destination'] ??
          'the destination';
      if (riderId != null && riderId.isNotEmpty) {
        await _db.collection('notifications').add({
          'uid': riderId,
          'title': 'Ride accepted',
          'body': 'A driver accepted your ride to $destination.',
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      NotificationService().showNotification(
        id: 10,
        title: 'Ride accepted',
        body: 'You accepted a ride to $destination.',
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ActiveTripTab(rideId: doc.id)),
        );
      }
    } catch (e) {
      _showSnack("Couldn't accept ride: $e");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  _EarningsStats _computeEarningsStats(
    List<QueryDocumentSnapshot> historyDocs,
  ) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));

    double today = 0;
    double yesterday = 0;

    for (final doc in historyDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final ts = data['completedAt'];
      final fare = (data['fare'] as num?)?.toDouble() ?? 0.0;
      if (ts is Timestamp) {
        final completed = ts.toDate();
        if (!completed.isBefore(todayStart)) {
          today += fare;
        } else if (!completed.isBefore(yesterdayStart) &&
            completed.isBefore(todayStart)) {
          yesterday += fare;
        }
      }
    }

    double? percentChange;
    if (yesterday > 0) {
      percentChange = ((today - yesterday) / yesterday) * 100;
    }

    return _EarningsStats(
      tripCount: historyDocs.length,
      todayEarnings: today,
      percentChangeFromYesterday: percentChange,
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: SafeArea(
        child: uid == null
            ? const Center(child: Text("Sign in to view your dashboard."))
            : StreamBuilder<QuerySnapshot>(
                stream: _db
                    .collection('ride_history')
                    .where('driverId', isEqualTo: uid)
                    .snapshots(),
                builder: (context, historySnapshot) {
                  final historyDocs = historySnapshot.data?.docs ?? [];
                  final stats = _computeEarningsStats(historyDocs);

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      DashboardTopBar(uid: uid),
                      const SizedBox(height: 18),
                      EarningsCard(
                        todayEarnings: stats.todayEarnings,
                        percentChangeFromYesterday:
                            stats.percentChangeFromYesterday,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: StatCard(
                              icon: Icons.directions_car_filled,
                              value: "${stats.tripCount}",
                              label: "Trips",
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FutureBuilder<Map<String, dynamic>?>(
                              future: _authService.getUserProfile(uid),
                              builder: (context, profileSnapshot) {
                                final rating = profileSnapshot.data?['rating'];
                                final ratingText = rating == null
                                    ? "5.0"
                                    : (rating as num).toStringAsFixed(2);
                                return StatCard(
                                  icon: Icons.star,
                                  value: ratingText,
                                  label: "Rating",
                                  iconColor: Colors.amber,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      StreamBuilder<QuerySnapshot>(
                        stream: _db
                            .collection('rides')
                            .where('status', isEqualTo: 'pending')
                            .snapshots(),
                        builder: (context, requestSnapshot) {
                          final allPending = requestSnapshot.data?.docs ?? [];
                          final available = allPending.where((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final declinedBy =
                                (data['declinedBy'] as List?) ?? [];
                            return !declinedBy.contains(uid);
                          }).toList();

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    "Active Requests",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: _navy,
                                    ),
                                  ),
                                  if (available.isNotEmpty)
                                    LiveBadge(count: available.length),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (!requestSnapshot.hasData)
                                const Center(
                                  child: CircularProgressIndicator(
                                    color: _navy,
                                  ),
                                )
                              else if (available.isEmpty)
                                const EmptyStateCard(
                                  message: "No active ride requests right now.",
                                )
                              else
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxHeight: 320,
                                  ),
                                  child: ListView.separated(
                                    padding: EdgeInsets.zero,
                                    physics: const BouncingScrollPhysics(),
                                    itemCount: available.length,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(height: 10),
                                    itemBuilder: (context, index) {
                                      final doc = available[index];
                                      return RideRequestCard(
                                        doc: doc,
                                        driverPosition: _driverPosition,
                                        busy: _busy,
                                        onAccept: () => _acceptRide(doc),
                                        onDecline: () => _declineRide(doc),
                                      );
                                    },
                                  ),
                                ),
                              const SizedBox(height: 20),
                              TrafficMapCard(
                                driverPosition: _driverPosition,
                                pendingRides: available,
                              ),
                              const SizedBox(height: 8),
                            ],
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}

class _EarningsStats {
  final int tripCount;
  final double todayEarnings;
  final double? percentChangeFromYesterday;

  const _EarningsStats({
    required this.tripCount,
    required this.todayEarnings,
    required this.percentChangeFromYesterday,
  });
}
