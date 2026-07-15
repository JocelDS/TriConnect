import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:triconnect/UI/user_ui/widgets/map_picker_screen.dart';
import 'dart:math' as math;

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
  double? _estimatedFare;

  static const double _baseFare = 40.0; // PHP
  static const double _perKmRate = 12.0; // PHP per km

  double _haversineDistanceKm(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0; // Earth radius in km
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) * math.cos(_deg2rad(lat2)) *
            math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  double _deg2rad(double deg) => deg * (math.pi / 180);

  void _recalculateFare() {
    if (_pickupLocation != null && _destinationLocation != null) {
      final lat1 = _pickupLocation!.latitude;
      final lon1 = _pickupLocation!.longitude;
      final lat2 = _destinationLocation!.latitude;
      final lon2 = _destinationLocation!.longitude;
      final km = _haversineDistanceKm(lat1, lon1, lat2, lon2);
      final fare = _baseFare + (_perKmRate * km);
      setState(() => _estimatedFare = double.parse(fare.toStringAsFixed(2)));
    } else {
      setState(() => _estimatedFare = null);
    }
  }

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
        _recalculateFare();
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    try {
      final pickupText = _pickupController.text.trim();
      final destinationText = _destinationController.text.trim();

      final fareToSave = _estimatedFare ?? 0.0;

      await widget.db.collection('rides').add({
        'userId': widget.userId,
        'pickup': pickupText,
        'pickupAddress': pickupText,
        'pickupLat': _pickupLocation?.latitude,
        'pickupLng': _pickupLocation?.longitude,
        'destination': destinationText,
        'destinationAddress': destinationText,
        'destinationLat': _destinationLocation?.latitude,
        'destinationLng': _destinationLocation?.longitude,
        'fare': fareToSave,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await widget.db.collection('notifications').add({
        'uid': widget.userId,
        'title': 'Ride requested',
        'body': 'Your ride request for $destinationText is waiting for a driver.',
        'read': false,
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
            const SizedBox(height: 12),
            if (_estimatedFare != null)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Estimated fare', style: TextStyle(color: Colors.black87)),
                    Text('₱${_estimatedFare!.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
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
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("Request Ride"),
                    if (_estimatedFare != null) ...[
                      const SizedBox(width: 8),
                      Text('₱${_estimatedFare!.toStringAsFixed(2)}'),
                    ]
                  ],
                ),
        ),
      ],
    );
  }
}
