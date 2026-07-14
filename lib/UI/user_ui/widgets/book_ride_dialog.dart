import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:triconnect/UI/user_ui/widgets/map_picker_screen.dart';

const _navy = Color(0xFF1E3A6D);

Future<bool> showBookRideDialog({
  required BuildContext context,
  required FirebaseFirestore db,
  required String userId,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => _BookRideDialog(db: db, userId: userId),
  );
  return result ?? false;
}

class _BookRideDialog extends StatefulWidget {
  final FirebaseFirestore db;
  final String userId;

  const _BookRideDialog({required this.db, required this.userId});

  @override
  State<_BookRideDialog> createState() => _BookRideDialogState();
}

class _BookRideDialogState extends State<_BookRideDialog> {
  final _formKey = GlobalKey<FormState>();
  final _pickupController = TextEditingController();
  final _destinationController = TextEditingController();

  PickedLocation? _pickupLocation;
  PickedLocation? _destinationLocation;

  bool _submitting = false;

  @override
  void dispose() {
    _pickupController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  Future<void> _pickPickupLocation() async {
    final result = await showMapPickerScreen(
      context: context,
      title: "Set Pickup Location",
      initialLocation: _pickupLocation == null
          ? null
          : LatLng(_pickupLocation!.latitude, _pickupLocation!.longitude),
    );
    if (result != null) {
      setState(() {
        _pickupLocation = result;
        _pickupController.text = result.address;
      });
    }
  }

  Future<void> _pickDestinationLocation() async {
    final result = await showMapPickerScreen(
      context: context,
      title: "Set Destination",
      initialLocation: _destinationLocation == null
          ? null
          : LatLng(
              _destinationLocation!.latitude,
              _destinationLocation!.longitude,
            ),
    );
    if (result != null) {
      setState(() {
        _destinationLocation = result;
        _destinationController.text = result.address;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    try {
      await widget.db.collection('rides').add({
        'userId': widget.userId,
        'pickup': _pickupController.text.trim(),
        'pickupLat': _pickupLocation?.latitude,
        'pickupLng': _pickupLocation?.longitude,
        'destination': _destinationController.text.trim(),
        'destinationLat': _destinationLocation?.latitude,
        'destinationLng': _destinationLocation?.longitude,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) Navigator.pop(context, false);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text(
        "Book a Ride",
        style: TextStyle(color: _navy, fontWeight: FontWeight.bold),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _pickupController,
              readOnly: true,
              onTap: _pickPickupLocation,
              decoration: InputDecoration(
                labelText: "Pickup location",
                hintText: "Tap to pin on map",
                prefixIcon: const Icon(Icons.my_location, color: _navy),
                suffixIcon: const Icon(Icons.map_outlined, color: _navy),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? "Required" : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _destinationController,
              readOnly: true,
              onTap: _pickDestinationLocation,
              decoration: InputDecoration(
                labelText: "Destination",
                hintText: "Tap to pin on map",
                prefixIcon: const Icon(Icons.place_outlined, color: _navy),
                suffixIcon: const Icon(Icons.map_outlined, color: _navy),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? "Required" : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context, false),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: _submitting ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: _navy,
            foregroundColor: Colors.white,
          ),
          child: _submitting
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text("Request Ride"),
        ),
      ],
    );
  }
}
