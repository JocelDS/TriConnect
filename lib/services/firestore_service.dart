import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Save user profile after successful sign up
  Future<void> saveUser({
    required String uid,
    required String fullName,
    required String email,
    required String phone,
    required String role,
    String? tricycleNumber,
  }) async {
    await _firestore.collection('users').doc(uid).set({
      'uid': uid,
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'role': role,
      'tricycleNumber': tricycleNumber ?? '',
      'status': role == 'driver' ? 'Available' : '',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get user profile
  Future<DocumentSnapshot<Map<String, dynamic>>> getUser(String uid) async {
    return await _firestore.collection('users').doc(uid).get();
  }

  /// Update user profile
  Future<void> updateUser({
    required String uid,
    required Map<String, dynamic> data,
  }) async {
    await _firestore.collection('users').doc(uid).update(data);
  }

  /// Save completed ride to history
  Future<void> saveRideHistory({
    required String rideId,
    required String customerId,
    required String driverId,
    required String pickupAddress,
    required String destinationAddress,
    required double fare,
  }) async {
    await _firestore.collection('ride_history').add({
      'rideId': rideId,
      'customerId': customerId,
      'driverId': driverId,
      'pickupAddress': pickupAddress,
      'destinationAddress': destinationAddress,
      'fare': fare,
      'completedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get ride history of a customer
  Stream<QuerySnapshot<Map<String, dynamic>>> getCustomerRideHistory(
    String customerId,
  ) {
    return _firestore
        .collection('ride_history')
        .where('customerId', isEqualTo: customerId)
        .orderBy('completedAt', descending: true)
        .snapshots();
  }

  /// Pushes the driver's live GPS position onto their active ride so the
  /// rider's app can track them moving in real time. Called repeatedly
  /// (throttled) from a position stream while a trip is accepted/ongoing.
  Future<void> updateDriverLiveLocation({
    required String rideId,
    required double lat,
    required double lng,
  }) async {
    await _firestore.collection('rides').doc(rideId).update({
      'driverLat': lat,
      'driverLng': lng,
      'driverLocationUpdatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Submit a rating for a driver and update their average rating.
  Future<void> submitDriverRating({
    required String driverId,
    required double rating,
  }) async {
    final driverRef = _firestore.collection('users').doc(driverId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(driverRef);
      if (!snapshot.exists) {
        throw Exception('Driver profile not found.');
      }
      final data = snapshot.data() ?? {};
      final currentRating = (data['rating'] as num?)?.toDouble();
      final currentCount = (data['ratingCount'] as num?)?.toInt() ?? 0;
      final newCount = currentCount + 1;
      final newRating = currentCount == 0
          ? rating
          : ((currentRating ?? 0.0) * currentCount + rating) / newCount;
      transaction.update(driverRef, {
        'rating': double.parse(newRating.toStringAsFixed(1)),
        'ratingCount': newCount,
      });
    });
  }
}
