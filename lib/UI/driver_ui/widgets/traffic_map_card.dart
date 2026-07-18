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
  void didUpdateWidget(covariant TrafficMapCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Follow the driver as their GPS position updates instead of leaving
    // the camera stuck on wherever it started.
    if (oldWidget.driverPosition != widget.driverPosition) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(widget.driverPosition),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>{};

    for (final doc in widget.pendingRides) {
      final data = doc.data() as Map<String, dynamic>;
      final lat = (data['pickupLat'] as num?)?.toDouble();
      final lng = (data['pickupLng'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        markers.add(
          Marker(
            markerId: MarkerId(doc.id),
            position: LatLng(lat, lng),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueOrange,
            ),
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
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 220,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF3B5B92), Color(0xFF1E3A6D)],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
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
                  liteModeEnabled: false,
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
                    _PulsingDot(),
                    SizedBox(width: 6),
                    Text(
                      "Monitoring traffic in your area...",
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF1E3A6D),
                        fontWeight: FontWeight.w600,
                      ),
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

/// A small breathing dot next to "Monitoring traffic..." so the label
/// reads as a live indicator rather than a static caption.
class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(
        begin: 0.35,
        end: 1,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: const Icon(Icons.circle, size: 8, color: Color(0xFF2F5BD3)),
    );
  }
}
