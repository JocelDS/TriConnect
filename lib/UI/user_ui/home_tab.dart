import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:triconnect/UI/user_ui/widgets/book_ride_dialog.dart';
// Removed map_grid_painter; using GoogleMap for live markers.
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:triconnect/services/notification_service.dart';
import 'package:triconnect/UI/user_ui/widgets/notifications_sheet.dart';
import 'package:triconnect/UI/user_ui/widgets/quick_action.dart';
import 'package:triconnect/services/auth_service.dart';

class HomeTab extends StatefulWidget {
  final AuthService authService;
  final FirebaseFirestore db;
  final void Function(int index)? onNavigateToTab;

  const HomeTab({
    super.key,
    required this.authService,
    required this.db,
    this.onNavigateToTab,
  });

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  static const _navy = Color(0xFF1E3A6D);
  static const _orange = Color(0xFFFF7A30);

  // Used whenever GPS can't be read (permission denied, location services
  // off, etc.) so the customer still has a sensible starting point instead
  // of an empty/unavailable location.
  static const double _defaultLat = 14.0703;
  static const double _defaultLng = 121.3255;
  static const String _defaultAddress = "San Pablo City, Laguna, Philippines";

  String? _fullName;
  bool _loadingProfile = true;

  String? _currentAddress;
  double? _currentLat;
  double? _currentLng;
  bool _detectingLocation = true;

  StreamSubscription<QuerySnapshot>? _notificationsSub;
  bool _notificationsBaselineSet = false;
  final Set<String> _seenNotificationIds = {};

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _detectCurrentLocation();
    _listenForNewNotifications();
  }

  /// Fires a real device notification whenever a *new* document appears in
  /// this customer's `notifications` collection (e.g. "Ride accepted",
  /// "Trip completed" — written by the driver side). The first snapshot is
  /// treated as a baseline so existing/old notifications don't all fire at
  /// once when the Home tab first loads.
  void _listenForNewNotifications() {
    final user = widget.authService.currentUser;
    if (user == null) return;

    _notificationsSub = widget.db
        .collection('notifications')
        .where('uid', isEqualTo: user.uid)
        .snapshots()
        .listen((snapshot) {
          if (!_notificationsBaselineSet) {
            for (final doc in snapshot.docs) {
              _seenNotificationIds.add(doc.id);
            }
            _notificationsBaselineSet = true;
            return;
          }

          for (final change in snapshot.docChanges) {
            if (change.type != DocumentChangeType.added) continue;
            final doc = change.doc;
            if (_seenNotificationIds.contains(doc.id)) continue;
            _seenNotificationIds.add(doc.id);

            final data = doc.data();
            final title = (data?['title'] as String?) ?? 'TriConnect';
            final body = (data?['body'] as String?) ?? '';
            NotificationService().showNotification(
              id: doc.id.hashCode & 0x7fffffff,
              title: title,
              body: body,
            );
          }
        });
  }

  /// Automatically detects the customer's current location (requesting
  /// location permission the first time) and reverse-geocodes it into a
  /// readable address, so it's ready before they even open "Book a Ride".
  /// The resolved address is saved onto the customer's profile so it's
  /// available anywhere in the app.
  Future<void> _detectCurrentLocation() async {
    final user = widget.authService.currentUser;
    setState(() => _detectingLocation = true);
    try {
      // Priority 1: the customer's saved home address, if they've set one
      // in their profile — this is what they consider "home" and avoids
      // relying on GPS (which can be wrong/unavailable, e.g. on emulators).
      if (user != null) {
        final profile = await widget.authService.getUserProfile(user.uid);
        final homeAddress = (profile?['homeAddress'] as String?)?.trim();
        if (homeAddress != null && homeAddress.isNotEmpty) {
          final resolved = await _geocodeAddress(homeAddress);
          if (resolved != null) {
            if (!mounted) return;
            setState(() {
              _currentAddress = homeAddress;
              _currentLat = resolved.latitude;
              _currentLng = resolved.longitude;
            });
            await widget.authService.updateUserProfile(
              uid: user.uid,
              data: {
                'lastAddress': homeAddress,
                'lastLat': resolved.latitude,
                'lastLng': resolved.longitude,
                'lastLocationUpdatedAt': FieldValue.serverTimestamp(),
              },
            );
            return;
          }
        }
      }

      // Priority 2: live GPS.
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _useDefaultLocation();
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _useDefaultLocation();
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      final lat = position.latitude;
      final lng = position.longitude;

      String address = "${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}";
      try {
        final placemarks = await placemarkFromCoordinates(lat, lng);
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final parts = [
            p.street,
            p.subLocality,
            p.locality,
            p.administrativeArea,
          ].where((e) => e != null && e.trim().isNotEmpty).toList();
          if (parts.isNotEmpty) address = parts.join(", ");
        }
      } catch (_) {
        // Keep the coordinate fallback if reverse geocoding fails.
      }

      if (!mounted) return;
      setState(() {
        _currentAddress = address;
        _currentLat = lat;
        _currentLng = lng;
      });

      if (user != null) {
        await widget.authService.updateUserProfile(
          uid: user.uid,
          data: {
            'lastAddress': address,
            'lastLat': lat,
            'lastLng': lng,
            'lastLocationUpdatedAt': FieldValue.serverTimestamp(),
          },
        );
      }
    } catch (_) {
      _useDefaultLocation();
    } finally {
      if (mounted) setState(() => _detectingLocation = false);
    }
  }

  /// Turns a saved address string into coordinates. Returns null if the
  /// address can't be resolved (e.g. it's too vague or geocoding fails).
  Future<Location?> _geocodeAddress(String address) async {
    try {
      final results = await locationFromAddress(address);
      if (results.isNotEmpty) return results.first;
    } catch (_) {
      // Fall through to null — caller will try GPS/default instead.
    }
    return null;
  }

  /// Falls back to a default Philippine location (San Pablo City) whenever
  /// GPS can't be read, so the customer always has a starting point instead
  /// of an "unavailable" state.
  void _useDefaultLocation() {
    if (!mounted) return;
    setState(() {
      _currentAddress = _defaultAddress;
      _currentLat = _defaultLat;
      _currentLng = _defaultLng;
    });
  }

  Future<void> _loadProfile() async {
    final user = widget.authService.currentUser;
    if (user == null) {
      setState(() => _loadingProfile = false);
      return;
    }

    if (user.displayName != null && user.displayName!.trim().isNotEmpty) {
      setState(() {
        _fullName = user.displayName;
        _loadingProfile = false;
      });
      return;
    }

    try {
      final profile = await widget.authService.getUserProfile(user.uid);
      setState(() {
        _fullName = profile?['fullName'] as String?;
        _loadingProfile = false;
      });
    } catch (_) {
      setState(() => _loadingProfile = false);
    }
  }

  String get _firstName {
    if (_fullName == null || _fullName!.trim().isEmpty) return "there";
    return _fullName!.trim().split(" ").first;
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _openMyRides() {
    widget.onNavigateToTab?.call(1);
    _showSnack("Opening your ride history.");
  }

  Future<void> _bookRide() async {
    final user = widget.authService.currentUser;
    if (user == null) {
      _showSnack("You must be signed in to book a ride.");
      return;
    }
    final success = await showBookRideDialog(
      context: context,
      db: widget.db,
      userId: user.uid,
      initialAddress: _currentAddress,
      initialLat: _currentLat,
      initialLng: _currentLng,
    );
    _showSnack(
      success
          ? "Ride requested! We're matching you with a nearby driver."
          : "Couldn't book a ride. Please try again.",
    );
  }

  void _showLearnMore() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "About TriConnect",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _navy,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "TriConnect connects you with nearby tricycle drivers for quick, "
              "affordable trips around your area — no haggling, no guesswork.",
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 20),
            _learnMoreItem(
              icon: Icons.my_location,
              title: "Automatic pickup detection",
              body:
                  "We detect your location (or use your saved home address) so pickup is pre-filled when you book.",
            ),
            _learnMoreItem(
              icon: Icons.payments_outlined,
              title: "Upfront fares in ₱",
              body:
                  "See your estimated fare before you request a ride — no surprises when you arrive.",
            ),
            _learnMoreItem(
              icon: Icons.directions_car_filled,
              title: "Real drivers, real time",
              body:
                  "Requests go out to nearby drivers instantly, and you can track your trip as it happens.",
            ),
            _learnMoreItem(
              icon: Icons.shield_outlined,
              title: "Built for your area",
              body:
                  "TriConnect is designed around everyday tricycle routes, not long-haul rideshare.",
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 46,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _bookRide();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _navy,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  "Book a Ride",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _learnMoreItem({
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: _orange),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openCurrentRide() {
    final user = widget.authService.currentUser;
    if (user == null) {
      _showSnack("Sign in first to view your ride.");
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _CurrentRideSheet(db: widget.db, uid: user.uid),
    );
  }

  void _openSupport() {
    _showSnack("Support is not configured yet. Please contact the admin.");
  }

  void _openNotifications() {
    final user = widget.authService.currentUser;
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => NotificationsSheet(db: widget.db, uid: user.uid),
    );
  }

  Future<void> _confirmSignOut() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Sign Out"),
        content: const Text("Are you sure you want to sign out?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Sign Out", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldSignOut == true) {
      await widget.authService.signOut();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  void dispose() {
    _notificationsSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadProfile,
      color: _navy,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          _buildTopBar(),
          const SizedBox(height: 20),
          _buildWelcomeCard(),
          const SizedBox(height: 24),
          const Text(
            "Quick Actions",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _navy,
            ),
          ),
          const SizedBox(height: 12),
          _buildQuickActionsGrid(),
          const SizedBox(height: 20),
          _buildLiveTrafficCard(),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        GestureDetector(
          onTap: _confirmSignOut,
          child: CircleAvatar(
            radius: 22,
                backgroundColor: _navy.withValues(alpha: 0.1),
            child: const Icon(Icons.person, color: _navy),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Hello,",
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              _loadingProfile
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _navy,
                      ),
                    )
                  : Text(
                      "$_firstName!",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _navy,
                      ),
                    ),
            ],
          ),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: _openNotifications,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.notifications_none, color: _navy),
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _navy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.electric_rickshaw,
                  color: _navy,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  "Welcome to TriConnect",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _navy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          RichText(
            text: const TextSpan(
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Colors.black87,
              ),
              children: [
                TextSpan(text: "Experience the future of urban mobility. "),
                TextSpan(text: "TriConnect"),
                TextSpan(text: " provides "),
                TextSpan(
                  text: "seamless, smart, and sustainable",
                  style: TextStyle(color: _orange, fontWeight: FontWeight.w600),
                ),
                TextSpan(text: " tricycle transport at your fingertips."),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _navy.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  _detectingLocation ? Icons.my_location : Icons.location_on,
                  size: 18,
                  color: _orange,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _detectingLocation
                      ? const Text(
                          "Detecting your location...",
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                        )
                      : Text(
                          _currentAddress ??
                              "Location unavailable — set it when booking a ride.",
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 46,
            child: ElevatedButton(
              onPressed: _showLearnMore,
              style: ElevatedButton.styleFrom(
                backgroundColor: _navy,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                "Learn More",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsGrid() {
    final actions = [
      QuickAction(
        icon: Icons.local_shipping_outlined,
        title: "Book a Ride",
        subtitle: "Request a tricycle now",
        onTap: _bookRide,
      ),
      QuickAction(
        icon: Icons.history,
        title: "My Rides",
        subtitle: "View your trip history",
        onTap: _openMyRides,
      ),
      QuickAction(
        icon: Icons.local_taxi_outlined,
        title: "Track Ride",
        subtitle: "View your current request",
        onTap: _openCurrentRide,
      ),
      QuickAction(
        icon: Icons.help_outline,
        title: "Support",
        subtitle: "Need help with a ride?",
        onTap: _openSupport,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: actions.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 1.35,
      ),
      itemBuilder: (context, index) => actions[index],
    );
  }

  Widget _buildLiveTrafficCard() {
    final user = widget.authService.currentUser;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 160,
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF3B5B92), Color(0xFF1E3A6D)],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: StreamBuilder<QuerySnapshot>(
                stream: widget.db
                    .collection('rides')
                    .where('status', isEqualTo: 'pending')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (_detectingLocation) {
                    return const Center(
                      child: SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white70,
                        ),
                      ),
                    );
                  }

                  final centerLat = _currentLat ?? _defaultLat;
                  final centerLng = _currentLng ?? _defaultLng;
                  final initial = CameraPosition(
                    target: LatLng(centerLat, centerLng),
                    zoom: 13,
                  );

                  final markers = <Marker>{
                    Marker(
                      markerId: const MarkerId('me'),
                      position: LatLng(centerLat, centerLng),
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueBlue,
                      ),
                      infoWindow: const InfoWindow(title: 'You'),
                    ),
                  };
                  if (snapshot.hasData) {
                    for (final doc in snapshot.data!.docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      final lat =
                          (data['destinationLat'] ??
                                  data['destination_lat'] ??
                                  data['destinationLatitude'])
                              as double?;
                      final lng =
                          (data['destinationLng'] ??
                                  data['destination_lng'] ??
                                  data['destinationLongitude'])
                              as double?;
                      if (lat != null && lng != null) {
                        markers.add(
                          Marker(
                            markerId: MarkerId(doc.id),
                            position: LatLng(lat, lng),
                            infoWindow: InfoWindow(
                              title: data['destination'] ?? 'Ride',
                            ),
                          ),
                        );
                      }
                    }
                  }

                  return GoogleMap(
                    initialCameraPosition: initial,
                    markers: markers,
                    myLocationEnabled: false,
                    zoomControlsEnabled: false,
                    liteModeEnabled: true,
                  );
                },
              ),
            ),
            Positioned(
              left: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Ride Status",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  StreamBuilder<QuerySnapshot>(
                    stream: user == null
                        ? const Stream.empty()
                        : widget.db
                              .collection('rides')
                              .where('userId', isEqualTo: user.uid)
                              .where(
                                'status',
                                whereIn: const ['pending', 'accepted'],
                              )
                              .snapshots(),
                    builder: (context, snapshot) {
                      if (user == null) {
                        return const Text(
                          "Sign in to track your ride.",
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        );
                      }

                      final count = snapshot.hasData
                          ? snapshot.data!.docs.length
                          : null;

                      if (count == 0) {
                        return const Text(
                          "No active ride requests.",
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        );
                      }

                      return Text(
                        count == null
                            ? "Checking your ride status..."
                            : "$count active ride request${count == 1 ? '' : 's'}",
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            Positioned(
              right: 14,
              bottom: 14,
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: _openCurrentRide,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.navigation, color: _navy, size: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CurrentRideSheet extends StatefulWidget {
  final FirebaseFirestore db;
  final String uid;

  const _CurrentRideSheet({required this.db, required this.uid});

  @override
  State<_CurrentRideSheet> createState() => _CurrentRideSheetState();
}

class _CurrentRideSheetState extends State<_CurrentRideSheet> {
  String? _lastStatus;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.35,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                "Current Ride",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A6D),
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: widget.db
                    .collection('rides')
                    .where('userId', isEqualTo: widget.uid)
                    .where('status', whereIn: const ['pending', 'accepted'])
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text("Error: ${snapshot.error}"));
                  }
                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF1E3A6D),
                      ),
                    );
                  }
                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) {
                    return const Center(
                      child: Text("You have no active ride requests."),
                    );
                  }
                  final doc = docs.first;
                  final ride = doc.data() as Map<String, dynamic>;
                  final status = ((ride['status'] ?? 'pending') as String)
                      .toLowerCase();
                  final pickup = ride['pickupAddress'] ?? ride['pickup'] ?? '-';
                  final destination =
                      ride['destinationAddress'] ?? ride['destination'] ?? '-';
                  final driver = ride['driverId'] as String?;

                  // notify on status change
                  if (_lastStatus != status) {
                    _lastStatus = status;
                    if (status == 'accepted') {
                      NotificationService().showNotification(
                        id: 1,
                        title: 'Driver Assigned',
                        body: 'A driver accepted your ride to $destination.',
                      );
                    } else if (status == 'cancelled') {
                      NotificationService().showNotification(
                        id: 2,
                        title: 'Ride Cancelled',
                        body: 'Your ride to $destination was cancelled.',
                      );
                    }
                  }

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _InfoTile(label: 'Pickup', value: pickup),
                        const SizedBox(height: 10),
                        _InfoTile(label: 'Destination', value: destination),
                        const SizedBox(height: 10),
                        _InfoTile(
                          label: 'Status',
                          value: status[0].toUpperCase() + status.substring(1),
                        ),
                        const SizedBox(height: 10),
                        _InfoTile(
                          label: 'Driver',
                          value: driver != null && driver.isNotEmpty
                              ? driver
                              : 'Waiting for driver',
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () async {
                                  Navigator.pop(context);
                                },
                                child: const Text('Close'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: status == 'cancelled'
                                    ? null
                                    : () async {
                                        try {
                                          await doc.reference.update({
                                            'status': 'cancelled',
                                            'updatedAt':
                                                FieldValue.serverTimestamp(),
                                          });
                                          await widget.db
                                              .collection('notifications')
                                              .add({
                                                'uid': widget.uid,
                                                'title': 'Ride cancelled',
                                                'body':
                                                    'You cancelled your ride to $destination.',
                                                'read': false,
                                                'createdAt':
                                                    FieldValue.serverTimestamp(),
                                              });
                                          NotificationService().showNotification(
                                            id: 3,
                                            title: 'Cancelled',
                                            body:
                                                'Your ride request was cancelled.',
                                          );
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Cancellation failed: $e',
                                                ),
                                              ),
                                            );
                                          }
                                        }
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E3A6D),
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Cancel Ride'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;

  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
