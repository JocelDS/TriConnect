import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Live map showing the driver's current position plus markers for every
/// pending ride pickup nearby.
class TrafficMapCard extends StatefulWidget {
  final LatLng driverPosition;
  final List<QueryDocumentSnapshot> pendingRides;

  const TrafficMapCard({
    super.key,
    required this.driverPosition,
    required this.pendingRides,
  });

  @override
  State<TrafficMapCard> createState() => _TrafficMapCardState();
}

class _TrafficMapCardState extends State<TrafficMapCard> {
  GoogleMapController? _mapController;

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('driver'),
        position: widget.driverPosition,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: const InfoWindow(title: 'You'),
      ),
    };

    for (final doc in widget.pendingRides) {
      final data = doc.data() as Map<String, dynamic>;
      final lat = (data['pickupLat'] as num?)?.toDouble();
      final lng = (data['pickupLng'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        markers.add(
          Marker(
            markerId: MarkerId(doc.id),
            position: LatLng(lat, lng),
            infoWindow: InfoWindow(
              title:
                  (data['pickupAddress'] ?? data['pickup'] ?? 'Pickup')
                      as String,
            ),
          ),
        );
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 160,
        width: double.infinity,
        color: const Color(0xFFEDEFF5),
        child: Stack(
          children: [
            Positioned.fill(
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: widget.driverPosition,
                  zoom: 13,
                ),
                markers: markers,
                myLocationEnabled: false,
                zoomControlsEnabled: false,
                liteModeEnabled: true,
                onMapCreated: (controller) => _mapController = controller,
              ),
            ),
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.circle, size: 8, color: Color(0xFF2F5BD3)),
                    SizedBox(width: 6),
                    Text(
                      "Monitoring traffic in your area...",
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
