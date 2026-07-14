import 'package:firebase_database/firebase_database.dart';

class RealtimeDatabaseService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  Future<void> addRideRequest({
    required String customerId,
    required String customerName,
    required String pickupAddress,
    required String destination,
  }) async {
    final rideRef = _db.child('ride_requests').push();

    await rideRef.set({
      'customerId': customerId,
      'customerName': customerName,
      'pickupAddress': pickupAddress,
      'destination': destination,
      'status': 'Pending',
      'timestamp': ServerValue.timestamp,
    });
  }
}
