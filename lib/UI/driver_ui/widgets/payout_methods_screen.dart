import 'package:flutter/material.dart';
import 'package:triconnect/services/auth_service.dart';

/// Lets the driver record where their earnings should be paid out to
/// (GCash, bank transfer, etc.). Saved to `users/{uid}.payoutMethod`.
class PayoutMethodsScreen extends StatefulWidget {
  const PayoutMethodsScreen({super.key});

  @override
  State<PayoutMethodsScreen> createState() => _PayoutMethodsScreenState();
}

class _PayoutMethodsScreenState extends State<PayoutMethodsScreen> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  String _type = 'GCash';
  final _accountNameController = TextEditingController();
  final _accountNumberController = TextEditingController();

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
    final method = profile?['payoutMethod'] as Map<String, dynamic>?;
    if (method != null) {
      _type = (method['type'] as String?) ?? 'GCash';
      _accountNameController.text = method['accountName'] as String? ?? '';
      _accountNumberController.text = method['accountNumber'] as String? ?? '';
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
          'payoutMethod': {
            'type': _type,
            'accountName': _accountNameController.text.trim(),
            'accountNumber': _accountNumberController.text.trim(),
          },
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Payout method saved.")));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Couldn't save payout method: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _accountNameController.dispose();
    _accountNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text("Payout Methods"),
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
                    DropdownButtonFormField<String>(
                      initialValue: _type,
                      decoration: const InputDecoration(
                        labelText: "Payout Method",
                      ),
                      items: const [
                        DropdownMenuItem(value: 'GCash', child: Text('GCash')),
                        DropdownMenuItem(value: 'Maya', child: Text('Maya')),
                        DropdownMenuItem(
                          value: 'Bank Transfer',
                          child: Text('Bank Transfer'),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _type = value ?? 'GCash'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _accountNameController,
                      decoration: const InputDecoration(
                        labelText: "Account Name",
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? "Required" : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _accountNumberController,
                      decoration: const InputDecoration(
                        labelText: "Account / Mobile Number",
                      ),
                      keyboardType: TextInputType.text,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? "Required" : null,
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
                                "Save Payout Method",
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
