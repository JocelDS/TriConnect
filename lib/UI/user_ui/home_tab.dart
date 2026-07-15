import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
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

  String? _fullName;
  bool _loadingProfile = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
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
    );
    _showSnack(
      success
          ? "Ride requested! We're matching you with a nearby driver."
          : "Couldn't book a ride. Please try again.",
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
          const SizedBox(height: 16),
          SizedBox(
            height: 46,
            child: ElevatedButton(
              onPressed: _bookRide,
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
                "Book a Ride",
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
                  final initial = CameraPosition(
                    target: LatLng(14.0703, 121.3255),
                    zoom: 13,
                  );

                  final markers = <Marker>{};
                  if (snapshot.hasData) {
                    for (final doc in snapshot.data!.docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      final lat = (data['destinationLat'] ?? data['destination_lat'] ?? data['destinationLatitude']) as double?;
                      final lng = (data['destinationLng'] ?? data['destination_lng'] ?? data['destinationLongitude']) as double?;
                      if (lat != null && lng != null) {
                        markers.add(Marker(
                          markerId: MarkerId(doc.id),
                          position: LatLng(lat, lng),
                          infoWindow: InfoWindow(title: data['destination'] ?? 'Ride'),
                        ));
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
                            .where('status', whereIn: const ['pending', 'accepted'])
                            .snapshots(),
                    builder: (context, snapshot) {
                      if (user == null) {
                        return const Text(
                          "Sign in to track your ride.",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        );
                      }

                      final count = snapshot.hasData
                          ? snapshot.data!.docs.length
                          : null;

                      if (count == 0) {
                        return const Text(
                          "No active ride requests.",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
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
                  final status = ((ride['status'] ?? 'pending') as String).toLowerCase();
                  final pickup = ride['pickupAddress'] ?? ride['pickup'] ?? '-';
                  final destination = ride['destinationAddress'] ?? ride['destination'] ?? '-';
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
                                            'updatedAt': FieldValue.serverTimestamp(),
                                          });
                                          await widget.db.collection('notifications').add({
                                            'uid': widget.uid,
                                            'title': 'Ride cancelled',
                                            'body': 'You cancelled your ride to $destination.',
                                            'read': false,
                                            'createdAt': FieldValue.serverTimestamp(),
                                          });
                                          NotificationService().showNotification(
                                            id: 3,
                                            title: 'Cancelled',
                                            body: 'Your ride request was cancelled.',
                                          );
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Cancellation failed: $e')),
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
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
