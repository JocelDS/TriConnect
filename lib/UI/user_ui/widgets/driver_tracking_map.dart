import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Live map for the rider: shows the assigned driver's current position
/// moving in real time, plus the pickup and destination points. The route
/// line always runs from the driver's live position to the pickup point,
/// so the rider can see the driver approaching.
class DriverTrackingMap extends StatefulWidget {
  final double? driverLat;
  final double? driverLng;
  final double? pickupLat;
  final double? pickupLng;
  final double? destLat;
  final double? destLng;
  final String? driverName;

  const DriverTrackingMap({
    super.key,
    required this.driverLat,
    required this.driverLng,
    required this.pickupLat,
    required this.pickupLng,
    required this.destLat,
    required this.destLng,
    this.driverName,
  });

  @override
  State<DriverTrackingMap> createState() => _DriverTrackingMapState();
}

class _DriverTrackingMapState extends State<DriverTrackingMap> {
  GoogleMapController? _mapController;

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DriverTrackingMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final hasDriver = widget.driverLat != null && widget.driverLng != null;
    final moved =
        oldWidget.driverLat != widget.driverLat ||
        oldWidget.driverLng != widget.driverLng;
    if (hasDriver && moved) {
      // Follow the driver's marker as they move toward the pickup point.
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(LatLng(widget.driverLat!, widget.driverLng!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasDriver = widget.driverLat != null && widget.driverLng != null;
    final hasPickup = widget.pickupLat != null && widget.pickupLng != null;
    final hasDest = widget.destLat != null && widget.destLng != null;

    if (!hasDriver && !hasPickup) {
      return Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFDCE3F0),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Icon(Icons.map_outlined, size: 48, color: Colors.grey),
        ),
      );
    }

    final markers = <Marker>{};
    if (hasPickup) {
      markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: LatLng(widget.pickupLat!, widget.pickupLng!),
          infoWindow: const InfoWindow(title: 'Pickup'),
        ),
      );
    }
    if (hasDest) {
      markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: LatLng(widget.destLat!, widget.destLng!),
          infoWindow: const InfoWindow(title: 'Destination'),
        ),
      );
    }
    if (hasDriver) {
      markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: LatLng(widget.driverLat!, widget.driverLng!),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
          infoWindow: InfoWindow(
            title: widget.driverName == null || widget.driverName!.isEmpty
                ? 'Your driver'
                : widget.driverName,
          ),
        ),
      );
    }

    final polylines = <Polyline>{};
    if (hasDriver && hasPickup) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('driver_to_pickup'),
          points: [
            LatLng(widget.driverLat!, widget.driverLng!),
            LatLng(widget.pickupLat!, widget.pickupLng!),
          ],
          color: const Color(0xFFFF7A30),
          width: 4,
        ),
      );
    }
    if (hasPickup && hasDest) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('pickup_to_destination'),
          points: [
            LatLng(widget.pickupLat!, widget.pickupLng!),
            LatLng(widget.destLat!, widget.destLng!),
          ],
          color: const Color(0xFF2F5BD3),
          width: 4,
        ),
      );
    }

    final center = hasDriver
        ? LatLng(widget.driverLat!, widget.driverLng!)
        : LatLng(widget.pickupLat!, widget.pickupLng!);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 180,
        width: double.infinity,
        child: Stack(
          children: [
            Positioned.fill(
              child: GoogleMap(
                initialCameraPosition: CameraPosition(target: center, zoom: 14),
                markers: markers,
                polylines: polylines,
                myLocationEnabled: false,
                zoomControlsEnabled: false,
                liteModeEnabled: false,
                onMapCreated: (controller) => _mapController = controller,
              ),
            ),
            if (!hasDriver)
              Positioned(
                left: 12,
                bottom: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    "Waiting for driver's location...",
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
