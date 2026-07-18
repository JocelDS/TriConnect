import 'package:flutter/material.dart';
import 'package:triconnect/UI/driver_ui/widgets/documents_licenses_screen.dart';
import 'package:triconnect/UI/driver_ui/widgets/help_center_screen.dart';
import 'package:triconnect/UI/driver_ui/widgets/insurance_policy_screen.dart';
import 'package:triconnect/UI/driver_ui/widgets/personal_info_screen.dart';
import 'package:triconnect/UI/driver_ui/widgets/profile_header_card.dart';
import 'package:triconnect/UI/driver_ui/widgets/profile_info_tile.dart';
import 'package:triconnect/UI/driver_ui/widgets/profile_menu_tile.dart';
import 'package:triconnect/services/auth_service.dart';

class DriverProfileTab extends StatelessWidget {
  const DriverProfileTab({super.key});

  Future<void> _confirmSignOut(BuildContext context, AuthService authService) async {
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
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    }
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
          : StreamBuilder<Map<String, dynamic>?>(
              stream: authService.userProfileStream(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF1A2744)));
                }

                final profile = snapshot.data;
                final name = user.displayName ?? profile?['fullName'] as String? ?? "Driver";
                final email = user.email ?? "-";
                final phone = profile?['phone'] as String? ?? "-";
                final address = profile?['address'] as String? ?? "-";
                final tricycleNumber = (profile?['tricycleNumber'] as String?) ?? '';
                final vehicleLabel = tricycleNumber.isEmpty ? "No vehicle on file" : tricycleNumber;
                final status = (profile?['status'] as String?) ?? "Available";

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Column(
                    children: [
                      ProfileHeaderCard(name: name, vehicleLabel: vehicleLabel, status: status),
                      const SizedBox(height: 18),
                      ProfileInfoTile(icon: Icons.email_outlined, label: "Email", value: email),
                      ProfileInfoTile(icon: Icons.phone_outlined, label: "Phone", value: phone),
                      ProfileInfoTile(icon: Icons.location_on_outlined, label: "Address", value: address),
                      const SizedBox(height: 8),
                      ProfileMenuTile(
                        icon: Icons.person_outline,
                        title: "Personal Information",
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const PersonalInfoScreen()),
                        ),
                      ),
                      ProfileMenuTile(
                        icon: Icons.shield_outlined,
                        title: "Insurance Policy",
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const InsurancePolicyScreen()),
                        ),
                      ),
                      ProfileMenuTile(
                        icon: Icons.description_outlined,
                        title: "Documents & Licenses",
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const DocumentsLicensesScreen()),
                        ),
                      ),
                      ProfileMenuTile(
                        icon: Icons.help_outline,
                        title: "Help Center",
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const HelpCenterScreen()),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _confirmSignOut(context, authService),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.logout, color: Colors.red),
                          label: const Text(
                            "Sign Out",
                            style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                          ),
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