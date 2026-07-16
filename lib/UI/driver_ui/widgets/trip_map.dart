import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Route map for an active trip: pickup + destination markers and the
/// connecting line, or a neutral placeholder if no coordinates are set.
class TripMap extends StatefulWidget {
  final double? pickupLat;
  final double? pickupLng;
  final double? destLat;
  final double? destLng;

  const TripMap({
    super.key,
    required this.pickupLat,
    required this.pickupLng,
    required this.destLat,
    required this.destLng,
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
  Widget build(BuildContext context) {
    final hasPickup = widget.pickupLat != null && widget.pickupLng != null;
    final hasDest = widget.destLat != null && widget.destLng != null;

    if (!hasPickup && !hasDest) {
      return Container(
        height: 220,
        width: double.infinity,
        color: const Color(0xFFDCE3F0),
        child: const Center(
          child: Icon(Icons.map, size: 60, color: Colors.grey),
        ),
      );
    }

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

    final polylines = <Polyline>{};
    if (hasPickup && hasDest) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('trip_route'),
          points: [
            LatLng(widget.pickupLat!, widget.pickupLng!),
            LatLng(widget.destLat!, widget.destLng!),
          ],
          color: const Color(0xFF2F5BD3),
          width: 4,
        ),
      );
    }

    final center = hasPickup
        ? LatLng(widget.pickupLat!, widget.pickupLng!)
        : LatLng(widget.destLat!, widget.destLng!);

    return SizedBox(
      height: 220,
      width: double.infinity, 
      child: GoogleMap(
        initialCameraPosition: CameraPosition(target: center, zoom: 14),
        markers: markers,
        polylines: polylines,
        myLocationEnabled: false,
        zoomControlsEnabled: false,
        liteModeEnabled: true,
        onMapCreated: (controller) => _mapController = controller,
      ),
    );
  }
}
