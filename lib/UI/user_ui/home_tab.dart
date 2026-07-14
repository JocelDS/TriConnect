import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:triconnect/UI/user_ui/widgets/book_ride_dialog.dart';
import 'package:triconnect/UI/user_ui/widgets/driver_queue_sheet.dart';
import 'package:triconnect/UI/user_ui/widgets/map_grid_painter.dart';
import 'package:triconnect/UI/user_ui/widgets/notifications_sheet.dart';
import 'package:triconnect/UI/user_ui/widgets/quick_action.dart';
import 'package:triconnect/services/auth_service.dart';

class HomeTab extends StatefulWidget {
  final AuthService authService;
  final FirebaseFirestore db;

  const HomeTab({super.key, required this.authService, required this.db});

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

  void _openDriverQueue() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DriverQueueSheet(db: widget.db),
    );
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
        onTap: () => _showSnack("Check the History tab below."),
      ),
      QuickAction(
        icon: Icons.groups_outlined,
        title: "Driver Queue",
        subtitle: "Monitor nearby drivers",
        onTap: _openDriverQueue,
      ),
      QuickAction(
        icon: Icons.notifications_none,
        title: "Notifications",
        subtitle: "Check your messages",
        onTap: _openNotifications,
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
            Positioned.fill(child: CustomPaint(painter: MapGridPainter())),
            Positioned(
              left: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Live Traffic",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  StreamBuilder<QuerySnapshot>(
                    stream: widget.db
                        .collection('drivers')
                        .where('active', isEqualTo: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      final count = snapshot.hasData
                          ? snapshot.data!.docs.length
                          : null;
                      return Row(
                        children: [
                          const Icon(
                            Icons.circle,
                            color: Colors.greenAccent,
                            size: 8,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            count == null
                                ? "Loading drivers..."
                                : "$count Drivers Active Nearby",
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
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
                onTap: _openDriverQueue,
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
