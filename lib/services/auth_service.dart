import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ================= LOGIN =================

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );

    if (credential.user != null) {
      await clearLegacyLocationFields(credential.user!.uid);
    }

    return credential;
  }

  // ================= REGISTER =================

  Future<UserCredential> signUp({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    required String role,
  }) async {
    final UserCredential credential = await _auth
        .createUserWithEmailAndPassword(
          email: email.trim(),
          password: password.trim(),
        );

    await credential.user?.updateDisplayName(fullName);

    await _firestore.collection('users').doc(credential.user!.uid).set({
      'uid': credential.user!.uid,
      'fullName': fullName,
      'email': email.trim(),
      'phone': phone,
      'role': role,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await clearLegacyLocationFields(credential.user!.uid);

    return credential;
  }

  // ================= PROFILE =================

  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();

    if (doc.exists) {
      return doc.data();
    }

    return null;
  }

  Future<void> clearLegacyLocationFields(String uid) async {
    await _firestore.collection('users').doc(uid).set({
      'lastAddress': FieldValue.delete(),
      'lastLat': FieldValue.delete(),
      'lastLng': FieldValue.delete(),
      'lastLocationUpdatedAt': FieldValue.delete(),
    }, SetOptions(merge: true));
  }

  Future<void> updateUserProfile({
    required String uid,
    Map<String, dynamic> data = const {},
  }) async {
    if (data.isEmpty) return;

    final payload = <String, dynamic>{...data};
    payload['lastAddress'] = FieldValue.delete();
    payload['lastLat'] = FieldValue.delete();
    payload['lastLng'] = FieldValue.delete();
    payload['lastLocationUpdatedAt'] = FieldValue.delete();

    await _firestore
        .collection('users')
        .doc(uid)
        .set(payload, SetOptions(merge: true));

    final fullName = data['fullName'];
    if (fullName is String &&
        fullName.trim().isNotEmpty &&
        currentUser != null) {
      await currentUser!.updateDisplayName(fullName.trim());
    }
  }

  /// Stream the user's profile document so UI can react to live updates.
  Stream<Map<String, dynamic>?> userProfileStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      if (doc.exists) return doc.data();
      return null;
    });
  }

  Future<String?> getUserRole(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();

    if (doc.exists) {
      return doc.data()?['role'] as String?;
    }

    return null;
  }

  // ================= PASSWORD RESET =================

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  // ================= LOGOUT =================

  Future<void> signOut() async {
    await _auth.signOut();
  }

  // ================= ERROR MESSAGES =================

  String getErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case "invalid-credential":
          return "Invalid email or password.";

        case "user-not-found":
          return "No user found with this email.";

        case "wrong-password":
          return "Incorrect password.";

        case "invalid-email":
          return "Invalid email address.";

        case "email-already-in-use":
          return "Email is already registered.";

        case "weak-password":
          return "Password must be at least 6 characters.";

        case "network-request-failed":
          return "No internet connection.";

        case "too-many-requests":
          return "Too many login attempts. Try again later.";

        default:
          return error.message ?? "Authentication failed.";
      }
    }

    if (error is FirebaseException) {
      return error.message ?? "Firebase error.";
    }

    return error.toString();
  }
}
