import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Route map for an active trip: pickup + destination markers and the
/// connecting line, plus an instruction pill that shows the current heading.
class TripMap extends StatefulWidget {
  final double? pickupLat;
  final double? pickupLng;
  final double? destLat;
  final double? destLng;
  final double? driverLat;
  final double? driverLng;
  final VoidCallback? onNavigate;

  const TripMap({
    super.key,
    required this.pickupLat,
    required this.pickupLng,
    required this.destLat,
    required this.destLng,
    this.driverLat,
    this.driverLng,
    this.onNavigate,
  });

  @override
  State<TripMap> createState() => _TripMapState();
}

class _TripMapState extends State<TripMap> {
  GoogleMapController? _mapController;

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TripMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final hasDriver = widget.driverLat != null && widget.driverLng != null;
    final moved =
        oldWidget.driverLat != widget.driverLat ||
        oldWidget.driverLng != widget.driverLng;
    if (hasDriver && moved) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(LatLng(widget.driverLat!, widget.driverLng!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPickup = widget.pickupLat != null && widget.pickupLng != null;
    final hasDest = widget.destLat != null && widget.destLng != null;

    final markers = <Marker>{};
    if (hasPickup) {
      markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: LatLng(widget.pickupLat!, widget.pickupLng!),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
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
    if (widget.driverLat != null && widget.driverLng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: LatLng(widget.driverLat!, widget.driverLng!),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(title: 'Driver'),
        ),
      );
    }

    final polylines = <Polyline>{};
    if (widget.driverLat != null && widget.driverLng != null && hasPickup) {
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

    final center = widget.driverLat != null && widget.driverLng != null
        ? LatLng(widget.driverLat!, widget.driverLng!)
        : hasPickup
            ? LatLng(widget.pickupLat!, widget.pickupLng!)
            : LatLng(widget.destLat ?? 14.0703, widget.destLng ?? 121.3255);

    return SizedBox(
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
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(242),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withAlpha(31), blurRadius: 8),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2F5BD3),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.navigation,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasDest ? 'Heading to destination' : 'En route',
                          style: const TextStyle(
                            color: Color(0xFF1A2744),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          hasPickup ? (widget.pickupLat != null ? 'Pickup set' : '') : '',
                          style: const TextStyle(color: Colors.black54, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (widget.onNavigate != null)
            Positioned(
              bottom: 16,
              right: 16,
              child: ElevatedButton.icon(
                onPressed: widget.onNavigate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A2744),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.navigation, size: 18),
                label: const Text('Navigate'),
              ),
            ),
        ],
      ),
    );
  }
}
