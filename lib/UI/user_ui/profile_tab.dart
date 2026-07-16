import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:triconnect/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

const _navy = Color(0xFF1E3A6D);

// Enhancements: Edit profile, ride stats, and support message

class ProfileTab extends StatelessWidget {
  final AuthService authService;
  final FirebaseFirestore db;

  const ProfileTab({super.key, required this.authService, required this.db});

  Future<void> _signOut(BuildContext context) async {
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
      await authService.signOut();
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = authService.currentUser;

    return FutureBuilder<Map<String, dynamic>?>(
      future: user == null ? null : authService.getUserProfile(user.uid),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final name =
            user?.displayName ?? profile?['fullName'] as String? ?? "User";
        final email = user?.email ?? "-";
        final phone = profile?['phone'] as String? ?? "-";

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          children: [
            Center(
              child: CircleAvatar(
                radius: 40,
                backgroundColor: const Color(0xFF1E3A6D).withValues(alpha: 0.1),
                child: const Icon(
                  Icons.person,
                  color: Color(0xFF1E3A6D),
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
                  color: Color(0xFF1E3A6D),
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
            const SizedBox(height: 20),
            // Ride stats
            StreamBuilder<QuerySnapshot>(
              stream: db
                  .collection('rides')
                  .where('userId', isEqualTo: user?.uid)
                  .snapshots(),
              builder: (context, ridesSnap) {
                final docs = ridesSnap.data?.docs ?? [];
                final totalRides = docs.length;
                double totalSpent = 0;
                for (final d in docs) {
                  final data = d.data() as Map<String, dynamic>;
                  final fare = (data['fare'] ?? 0) as num;
                  totalSpent += fare.toDouble();
                }

                return Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        label: 'Total Rides',
                        value: totalRides.toString(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        label: 'Total Spent',
                        value: '₱${totalSpent.toStringAsFixed(2)}',
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () => _showEditProfileDialog(context, user?.uid, profile),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Edit Profile'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                          onPressed: () => _showSupportDialog(context, user?.uid),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _navy,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Support'),
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            SizedBox(
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () => _signOut(context),
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
          Icon(icon, color: const Color(0xFF1E3A6D)),
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

class _StatCard extends StatelessWidget {
  final String label;
  final String value;

  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}

// Dialogs
extension on ProfileTab {
  void _showEditProfileDialog(BuildContext context, String? uid, Map<String, dynamic>? profile) {
    if (uid == null) return;
    final nameController = TextEditingController(text: profile?['fullName'] as String?);
    final phoneController = TextEditingController(text: profile?['phone'] as String?);

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Full name')),
            TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Phone')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () async {
            final fn = nameController.text.trim();
            final ph = phoneController.text.trim();
            try {
              await FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .update({'fullName': fn, 'phone': ph});

                await FirebaseAuth.instance.currentUser?.updateDisplayName(fn);

                if (!context.mounted) return;

                Navigator.pop(context);
            } catch (e) {
              if (!context.mounted) return;

                Navigator.pop(context);

                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Update failed: $e')));
            }
          }, child: const Text('Save')),
        ],
      ),
    ).then((_) => (context as Element).markNeedsBuild());
  }

  void _showSupportDialog(BuildContext context, String? uid) {
    if (uid == null) return;
    final msgController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Support'),
        content: TextField(controller: msgController, decoration: const InputDecoration(hintText: 'Describe your issue')), 
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () async {
            final msg = msgController.text.trim();
            if (msg.isEmpty) return;
            try {
              await FirebaseFirestore.instance.collection('support').add({
                  'uid': uid,
                  'message': msg,
                  'createdAt': FieldValue.serverTimestamp(),
                });

                if (!context.mounted) return;

                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Support request sent')),
                );
            } catch (e) {
              if (!context.mounted) return;

                Navigator.pop(context);

                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Update failed: $e')));
            }
          }, child: const Text('Send')),
        ],
      ),
    );
  }
}
