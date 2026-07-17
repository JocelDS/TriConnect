import 'package:flutter/material.dart';
import 'package:triconnect/services/auth_service.dart';

/// Lets the driver view and edit their name, phone, and vehicle (tricycle)
/// number. Saves straight to their `users/{uid}` Firestore document.
class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _vehicleController = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    final profile = await _authService.getUserProfile(uid);
    _nameController.text = profile?['fullName'] as String? ?? '';
    _phoneController.text = profile?['phone'] as String? ?? '';
    _vehicleController.text = profile?['tricycleNumber'] as String? ?? '';
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null || !_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      await _authService.updateUserProfile(
        uid: uid,
        data: {
          'fullName': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'tricycleNumber': _vehicleController.text.trim(),
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Personal information updated.")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Couldn't save changes: $e")));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _vehicleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text("Personal Information"),
        backgroundColor: const Color(0xFF1A2744),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1A2744)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: "Full Name"),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? "Required" : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: "Phone Number",
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? "Required" : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _vehicleController,
                      decoration: const InputDecoration(
                        labelText: "Tricycle / Plate Number",
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A2744),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _saving
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                "Save Changes",
                                style: TextStyle(color: Colors.white),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
