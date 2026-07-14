import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

const _navy = Color(0xFF1E3A6D);
const _orange = Color(0xFFFF7A30);

class PickedLocation {
  final String address;
  final double latitude;
  final double longitude;

  const PickedLocation({
    required this.address,
    required this.latitude,
    required this.longitude,
  });
}

Future<PickedLocation?> showMapPickerScreen({
  required BuildContext context,
  String title = "Choose Location",
  LatLng? initialLocation,
}) {
  return Navigator.push<PickedLocation>(
    context,
    MaterialPageRoute(
      builder: (_) =>
          MapPickerScreen(title: title, initialLocation: initialLocation),
    ),
  );
}

class MapPickerScreen extends StatefulWidget {
  final String title;
  final LatLng? initialLocation;

  const MapPickerScreen({
    super.key,
    this.title = "Choose Location",
    this.initialLocation,
  });

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  static const LatLng _defaultCenter = LatLng(
    14.0703,
    121.3255,
  ); // San Pablo City, PH

  final _searchController = TextEditingController();
  GoogleMapController? _mapController;

  LatLng _pickedLatLng = _defaultCenter;
  String _pickedAddress = "Tap on the map or search a place";
  bool _resolvingAddress = false;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialLocation != null) {
      _pickedLatLng = widget.initialLocation!;
      _reverseGeocode(_pickedLatLng);
    } else {
      _useCurrentLocation(silent: true);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _moveCamera(LatLng target) async {
    await _mapController?.animateCamera(CameraUpdate.newLatLngZoom(target, 16));
  }

  Future<void> _reverseGeocode(LatLng point) async {
    setState(() => _resolvingAddress = true);
    try {
      final placemarks = await placemarkFromCoordinates(
        point.latitude,
        point.longitude,
      );
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = [
          p.street,
          p.subLocality,
          p.locality,
          p.administrativeArea,
        ].where((e) => e != null && e.trim().isNotEmpty).toList();
        setState(() {
          _pickedAddress = parts.isNotEmpty
              ? parts.join(", ")
              : "${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}";
        });
      }
    } catch (_) {
      setState(() {
        _pickedAddress =
            "${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}";
      });
    } finally {
      if (mounted) setState(() => _resolvingAddress = false);
    }
  }

  void _onMapTapped(LatLng point) {
    setState(() => _pickedLatLng = point);
    _reverseGeocode(point);
  }

  Future<void> _searchAddress() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    FocusScope.of(context).unfocus();
    setState(() => _searching = true);
    try {
      final locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        final loc = locations.first;
        final target = LatLng(loc.latitude, loc.longitude);
        setState(() => _pickedLatLng = target);
        await _moveCamera(target);
        await _reverseGeocode(target);
      } else {
        _showMessage("No results found for \"$query\".");
      }
    } catch (_) {
      _showMessage("Couldn't find that place. Try a different search.");
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _useCurrentLocation({bool silent = false}) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!silent) _showMessage("Please enable location services.");
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!silent) _showMessage("Location permission is required.");
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      final target = LatLng(position.latitude, position.longitude);
      setState(() => _pickedLatLng = target);
      await _moveCamera(target);
      await _reverseGeocode(target);
    } catch (_) {
      if (!silent) _showMessage("Couldn't get your current location.");
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _confirm() {
    Navigator.pop(
      context,
      PickedLocation(
        address: _pickedAddress,
        latitude: _pickedLatLng.latitude,
        longitude: _pickedLatLng.longitude,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: _navy,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _pickedLatLng,
              zoom: 15,
            ),
            onMapCreated: (controller) => _mapController = controller,
            onTap: _onMapTapped,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            markers: {
              Marker(
                markerId: const MarkerId("picked"),
                position: _pickedLatLng,
                draggable: true,
                onDragEnd: _onMapTapped,
              ),
            },
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(14),
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _searchAddress(),
                decoration: InputDecoration(
                  hintText: "Search for a place",
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.search, color: _navy),
                  suffixIcon: _searching
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
                      : IconButton(
                          icon: const Icon(Icons.arrow_forward, color: _navy),
                          onPressed: _searchAddress,
                        ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 160,
            child: FloatingActionButton(
              heroTag: "current_location_btn",
              backgroundColor: Colors.white,
              foregroundColor: _navy,
              onPressed: () => _useCurrentLocation(),
              child: const Icon(Icons.my_location),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 12,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.place, color: _orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _resolvingAddress
                            ? const Text("Locating address...")
                            : Text(
                                _pickedAddress,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _resolvingAddress ? null : _confirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _navy,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        "Confirm Location",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
