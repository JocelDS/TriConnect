import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:triconnect/UI/user_ui/widgets/map_picker_screen.dart';
import 'package:triconnect/services/auth_service.dart';
import 'dart:math' as math;

const _navy = Color(0xFF1E3A6D);

Future<bool> showBookRideDialog({
  required BuildContext context,
  required FirebaseFirestore db,
  required String userId,
  String? initialAddress,
  double? initialLat,
  double? initialLng,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => _BookRideDialog(
      db: db,
      userId: userId,
      initialAddress: initialAddress,
      initialLat: initialLat,
      initialLng: initialLng,
    ),
  );
  return result ?? false;
}

class _BookRideDialog extends StatefulWidget {
  final FirebaseFirestore db;
  final String userId;
  final String? initialAddress;
  final double? initialLat;
  final double? initialLng;

  const _BookRideDialog({
    required this.db,
    required this.userId,
    this.initialAddress,
    this.initialLat,
    this.initialLng,
  });

  @override
  State<_BookRideDialog> createState() => _BookRideDialogState();
}

class _BookRideDialogState extends State<_BookRideDialog> {
  final _formKey = GlobalKey<FormState>();
  final _pickupController = TextEditingController();
  final _destinationController = TextEditingController();
  final AuthService _authService = AuthService();

  PickedLocation? _pickupLocation;
  PickedLocation? _destinationLocation;

  bool _submitting = false;
  bool _detectingPickup = true;
  double? _estimatedFare;

  static const double _baseFare = 40.0; // PHP
  static const double _perKmRate = 12.0; // PHP per km

  // Falls back to a default Philippine location (San Pablo City) whenever
  // GPS can't be read, so pickup always has a sensible starting point.
  static const double _defaultLat = 14.0703;
  static const double _defaultLng = 121.3255;
  static const String _defaultAddress = "San Pablo City, Laguna, Philippines";

  @override
  void initState() {
    super.initState();
    if (widget.initialAddress != null &&
        widget.initialLat != null &&
        widget.initialLng != null) {
      _pickupLocation = PickedLocation(
        address: widget.initialAddress!,
        latitude: widget.initialLat!,
        longitude: widget.initialLng!,
      );
      _pickupController.text = widget.initialAddress!;
      _detectingPickup = false;
      // Fare needs both points; destination isn't set yet, so nothing to
      // recalculate until the customer picks a destination.
    } else {
      _autoDetectPickup();
    }
  }

  /// Automatically detects the customer's current location (requesting
  /// location permission the first time, same as the driver dashboard
  /// does) and pre-fills the pickup field with the resolved address, so
  /// the customer doesn't have to manually search or tap the map first.
  /// The resolved address is also saved onto the customer's profile.
  Future<void> _autoDetectPickup() async {
    setState(() => _detectingPickup = true);
    try {
      // Priority 1: the customer's saved home address, if set.
      final profile = await _authService.getUserProfile(widget.userId);
      final homeAddress = (profile?['homeAddress'] as String?)?.trim();
      if (homeAddress != null && homeAddress.isNotEmpty) {
        try {
          final results = await locationFromAddress(homeAddress);
          if (results.isNotEmpty) {
            final loc = results.first;
            if (!mounted) return;
            setState(() {
              _pickupLocation = PickedLocation(
                address: homeAddress,
                latitude: loc.latitude,
                longitude: loc.longitude,
              );
              _pickupController.text = homeAddress;
            });
            _recalculateFare();
            return;
          }
        } catch (_) {
          // Fall through to GPS/default if the home address can't be geocoded.
        }
      }

      // Priority 2: live GPS.
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _useDefaultPickup();
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _useDefaultPickup();
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      final lat = position.latitude;
      final lng = position.longitude;

      String address = "${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}";
      try {
        final placemarks = await placemarkFromCoordinates(lat, lng);
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final parts = [
            p.street,
            p.subLocality,
            p.locality,
            p.administrativeArea,
          ].where((e) => e != null && e.trim().isNotEmpty).toList();
          if (parts.isNotEmpty) address = parts.join(", ");
        }
      } catch (_) {
        // Keep the coordinate fallback if reverse geocoding fails.
      }

      if (!mounted) return;
      setState(() {
        _pickupLocation = PickedLocation(
          address: address,
          latitude: lat,
          longitude: lng,
        );
        _pickupController.text = address;
      });
      _recalculateFare();

      // Save the customer's detected address to their profile so it's
      // available elsewhere in the app (e.g. showing "Your location: ...").
      await _authService.updateUserProfile(
        uid: widget.userId,
        data: {
          'lastAddress': address,
          'lastLat': lat,
          'lastLng': lng,
          'lastLocationUpdatedAt': FieldValue.serverTimestamp(),
        },
      );
    } catch (_) {
      _useDefaultPickup();
    } finally {
      if (mounted) setState(() => _detectingPickup = false);
    }
  }

  void _useDefaultPickup() {
    if (!mounted) return;
    setState(() {
      _pickupLocation = const PickedLocation(
        address: _defaultAddress,
        latitude: _defaultLat,
        longitude: _defaultLng,
      );
      _pickupController.text = _defaultAddress;
    });
    _recalculateFare();
  }

  double _haversineDistanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const R = 6371.0; // Earth radius in km
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
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
    // Center on the destination if one's already picked; otherwise fall
    // back to the pickup location (already resolved from the database)
    // instead of letting the map picker do its own independent GPS lookup.
    final centerOn = _destinationLocation ?? _pickupLocation;
    final result = await showMapPickerScreen(
      context: context,
      title: "Set Destination",
      initialLocation: centerOn == null
          ? null
          : LatLng(centerOn.latitude, centerOn.longitude),
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
        'body':
            'Your ride request for $destinationText is waiting for a driver.',
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
                hintText: _detectingPickup
                    ? "Detecting your location..."
                    : "Tap to adjust on map",
                prefixIcon: _detectingPickup
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _navy,
                          ),
                        ),
                      )
                    : const Icon(Icons.my_location, color: _navy),
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
                padding: const EdgeInsets.symmetric(
                  vertical: 6,
                  horizontal: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Estimated fare',
                      style: TextStyle(color: Colors.black87),
                    ),
                    Text(
                      '₱${_estimatedFare!.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
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
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}
