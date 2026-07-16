import 'package:flutter/material.dart';
import 'package:triconnect/UI/driver_ui/widgets/profile_header_card.dart';
import 'package:triconnect/UI/driver_ui/widgets/profile_info_tile.dart';
import 'package:triconnect/UI/driver_ui/widgets/profile_menu_tile.dart';
import 'package:triconnect/services/auth_service.dart';

class DriverProfileTab extends StatelessWidget {
  const DriverProfileTab({super.key});

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final user = authService.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text("Driver Profile"),
        backgroundColor: const Color(0xFF1A2744),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: user == null
          ? const Center(child: Text("Sign in to view your profile."))
          : FutureBuilder<Map<String, dynamic>?>(
              future: authService.getUserProfile(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF1A2744)),
                  );
                }

                final profile = snapshot.data;
                final name =
                    user.displayName ??
                    profile?['fullName'] as String? ??
                    "Driver";
                final email = user.email ?? "-";
                final phone = profile?['phone'] as String? ?? "-";
                final tricycleNumber =
                    (profile?['tricycleNumber'] as String?) ?? '';
                final vehicleLabel = tricycleNumber.isEmpty
                    ? "No vehicle on file"
                    : tricycleNumber;
                final status = (profile?['status'] as String?) ?? "Available";

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      ProfileHeaderCard(
                        name: name,
                        vehicleLabel: vehicleLabel,
                        status: status,
                      ),
                      const SizedBox(height: 20),
                      ProfileInfoTile(
                        icon: Icons.email_outlined,
                        label: "Email",
                        value: email,
                      ),
                      ProfileInfoTile(
                        icon: Icons.phone_outlined,
                        label: "Phone",
                        value: phone,
                      ),
                      const SizedBox(height: 6),
                      ProfileMenuTile(
                        icon: Icons.person_outline,
                        title: "Personal Information",
                        onTap: () => _showSnack(
                          context,
                          "Personal Information isn't available in this demo yet.",
                        ),
                      ),
                      ProfileMenuTile(
                        icon: Icons.payment_outlined,
                        title: "Payout Methods",
                        onTap: () => _showSnack(
                          context,
                          "Payout Methods isn't available in this demo yet.",
                        ),
                      ),
                      ProfileMenuTile(
                        icon: Icons.shield_outlined,
                        title: "Insurance Policy",
                        onTap: () => _showSnack(
                          context,
                          "Insurance Policy isn't available in this demo yet.",
                        ),
                      ),
                      ProfileMenuTile(
                        icon: Icons.description_outlined,
                        title: "Documents & Licenses",
                        onTap: () => _showSnack(
                          context,
                          "Documents & Licenses isn't available in this demo yet.",
                        ),
                      ),
                      ProfileMenuTile(
                        icon: Icons.help_outline,
                        title: "Help Center",
                        onTap: () => _showSnack(
                          context,
                          "Help Center isn't available in this demo yet.",
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await authService.signOut();
                            if (context.mounted) {
                              Navigator.pushNamedAndRemoveUntil(
                                context,
                                '/login',
                                (route) => false,
                              );
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          icon: const Icon(Icons.logout),
                          label: const Text("Log Out"),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
