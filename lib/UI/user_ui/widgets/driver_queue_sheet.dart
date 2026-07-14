import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:triconnect/services/auth_service.dart';

class DriverQueueSheet extends StatefulWidget {
  final FirebaseFirestore db;

  const DriverQueueSheet({required this.db, super.key});

  @override
  State<DriverQueueSheet> createState() => _DriverQueueSheetState();
}

class _DriverQueueSheetState extends State<DriverQueueSheet> {
  final AuthService _authService = AuthService();
  
  FirebaseFirestore get _db => widget.db;

  int _selectedTab = 0;

  Future<void> _logout() async {
    await _authService.signOut();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [_buildAvailableRidesTab(), _buildProfileTab()];

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text("TriConnect Driver"),
        centerTitle: true,
        backgroundColor: const Color(0xFF2F5BD3),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: IndexedStack(index: _selectedTab, children: tabs),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedTab,
        selectedItemColor: const Color(0xFF2F5BD3),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (index) async {
          if (index == 2) {
            await _logout();
            return;
          }
          setState(() => _selectedTab = index);
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
          BottomNavigationBarItem(
            icon: Icon(Icons.exit_to_app),
            label: "Logout",
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableRidesTab() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text(
                      "Available Rides",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    StreamBuilder<QuerySnapshot>(
                      stream: _db
                          .collection('ride_requests')
                          .where('status', isEqualTo: 'Pending')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const CircularProgressIndicator();
                        }

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const Text(
                            "No available rides at the moment",
                            style: TextStyle(color: Colors.grey),
                          );
                        }

                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: snapshot.data!.docs.length,
                          itemBuilder: (context, index) {
                            final ride = snapshot.data!.docs[index];
                            return ListTile(
                              leading: const Icon(Icons.location_on_outlined),
                              title: Text(ride['destination']),
                              subtitle: Text("From: ${ride['pickupAddress']}"),
                              trailing: ElevatedButton(
                                onPressed: () async {
                                  final user = _authService.currentUser;
                                  try {
                                    await ride.reference.update({
                                      'status': 'Accepted',
                                      'driverId': user?.uid,
                                    });
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text("Ride accepted!"),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            "Couldn't accept ride: $e",
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2F5BD3),
                                ),
                                child: const Text(
                                  "Accept",
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTab() {
    final user = _authService.currentUser;

    return FutureBuilder<Map<String, dynamic>?>(
      future: user == null ? null : _authService.getUserProfile(user.uid),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final name =
            user?.displayName ?? profile?['fullName'] as String? ?? "Driver";
        final email = user?.email ?? "-";
        final phone = profile?['phone'] as String? ?? "-";

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          children: [
            Center(
              child: CircleAvatar(
                radius: 40,
                backgroundColor: const Color(0xFF2F5BD3).withValues(alpha: 0.1),
                child: const Icon(
                  Icons.person,
                  color: Color(0xFF2F5BD3),
                  size: 40,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2F5BD3),
                ),
              ),
            ),
            const SizedBox(height: 24),
            _ProfileField(
              icon: Icons.email_outlined,
              label: "Email",
              value: email,
            ),
            const SizedBox(height: 12),
            _ProfileField(
              icon: Icons.phone_outlined,
              label: "Phone",
              value: phone,
            ),
            const SizedBox(height: 30),
            SizedBox(
              height: 50,
              child: OutlinedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text(
                  "Sign Out",
                  style: TextStyle(color: Colors.red),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ProfileField extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileField({
    required this.icon,
    required this.label,
    required this.value,
  });

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
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF2F5BD3)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
