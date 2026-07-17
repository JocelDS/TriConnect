import 'package:flutter/material.dart';
import 'package:triconnect/services/auth_service.dart';

/// Lets the driver record their license details. Saved to
/// `users/{uid}.license`.
class DocumentsLicensesScreen extends StatefulWidget {
  const DocumentsLicensesScreen({super.key});

  @override
  State<DocumentsLicensesScreen> createState() =>
      _DocumentsLicensesScreenState();
}

class _DocumentsLicensesScreenState extends State<DocumentsLicensesScreen> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  final _licenseNumberController = TextEditingController();
  final _expiryController = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    final profile = await _authService.getUserProfile(uid);
    final license = profile?['license'] as Map<String, dynamic>?;
    if (license != null) {
      _licenseNumberController.text = license['number'] as String? ?? '';
      _expiryController.text = license['expiry'] as String? ?? '';
    }
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
          'license': {
            'number': _licenseNumberController.text.trim(),
            'expiry': _expiryController.text.trim(),
          },
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("License details updated.")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Couldn't save license details: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickExpiryDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null) {
      _expiryController.text =
          "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
    }
  }

  @override
  void dispose() {
    _licenseNumberController.dispose();
    _expiryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text("Documents & Licenses"),
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
                      controller: _licenseNumberController,
                      decoration: const InputDecoration(
                        labelText: "Driver's License Number",
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? "Required" : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _expiryController,
                      readOnly: true,
                      onTap: _pickExpiryDate,
                      decoration: const InputDecoration(
                        labelText: "Expiry Date",
                        suffixIcon: Icon(Icons.calendar_today),
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
                                "Save Documents",
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
