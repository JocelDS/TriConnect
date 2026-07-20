import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:triconnect/services/auth_service.dart';
import 'package:triconnect/services/firestore_service.dart';

class HistoryTab extends StatelessWidget {
  final AuthService authService;
  final FirebaseFirestore db;

  const HistoryTab({super.key, required this.authService, required this.db});

  static final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    final user = authService.currentUser;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Text(
            "My Rides",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A6D),
            ),
          ),
        ),
        Expanded(
          child: user == null
              ? const Center(child: Text("Sign in to see your rides."))
              : StreamBuilder<QuerySnapshot>(
                  stream: db
                      .collection('rides')
                      .where('userId', isEqualTo: user.uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text("Error: ${snapshot.error}"));
                    }
                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF1E3A6D),
                        ),
                      );
                    }
                    final docs = snapshot.data!.docs;
                    final sortedDocs = List<QueryDocumentSnapshot>.from(docs)
                      ..sort((a, b) {
                        final aTime = (a.data() as Map<String, dynamic>)['createdAt'];
                        final bTime = (b.data() as Map<String, dynamic>)['createdAt'];
                        if (aTime is Timestamp && bTime is Timestamp) {
                          return bTime.compareTo(aTime);
                        }
                        return 0;
                      });
                    if (sortedDocs.isEmpty) {
                      return const Center(
                        child: Text("No rides yet. Book one from Home!"),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      itemCount: sortedDocs.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final data = sortedDocs[index].data() as Map<String, dynamic>;
                        final status = ((data['status'] ?? 'pending') as String)
                            .toLowerCase();
                        final pickup = data['pickupAddress'] ?? data['pickup'] ?? '-';
                        final destination =
                            data['destinationAddress'] ?? data['destination'] ?? '-';
                        final driverRating = (data['driverRating'] as num?)?.toDouble();
                        final driverId = data['driverId'] as String?;
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: const Color(
                                      0xFF1E3A6D,
                                    ).withValues(alpha: 0.08),
                                    child: const Icon(
                                      Icons.local_shipping_outlined,
                                      color: Color(0xFF1E3A6D),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "$pickup → $destination",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          status[0].toUpperCase() +
                                              status.substring(1),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: status == 'completed' || status == 'accepted'
                                                ? Colors.green
                                                : Colors.orange,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (status == 'completed' && driverId != null && driverId.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: driverRating != null
                                      ? Row(
                                          children: [
                                            const Icon(Icons.star, color: Colors.amber, size: 18),
                                            const SizedBox(width: 6),
                                            Text(
                                              'You rated your driver ${driverRating.toStringAsFixed(1)}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF1E3A6D),
                                              ),
                                            ),
                                          ],
                                        )
                                      : SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton(
                                            onPressed: () async {
                                              final rating = await _showDriverRatingDialog(context);
                                              if (rating == null) return;

                                              try {
                                                await _firestoreService.submitDriverRating(
                                                  driverId: driverId,
                                                  rating: rating,
                                                );
                                                await sortedDocs[index].reference.update({
                                                  'driverRating': rating,
                                                  'driverRatedAt': FieldValue.serverTimestamp(),
                                                });

                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(content: Text('Thank you for rating your driver.')),
                                                  );
                                                }
                                              } catch (e) {
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(content: Text('Rating failed: $e')),
                                                  );
                                                }
                                              }
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF1E3A6D),
                                              foregroundColor: Colors.white,
                                            ),
                                            child: const Text(
                                              'Rate Driver',
                                              style: TextStyle(fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                        ),
                                ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<double?> _showDriverRatingDialog(BuildContext context) async {
    double rating = 5.0;

    return showDialog<double>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Rate your driver',
            style: TextStyle(color: Color(0xFF1E3A6D)),
          ),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'How would you rate your driver?',
                    style: TextStyle(color: Color(0xFF1E3A6D)),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final value = index + 1;
                      return IconButton(
                        iconSize: 32,
                        icon: Icon(
                          value <= rating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                        ),
                        onPressed: () {
                          setState(() {
                            rating = value.toDouble();
                          });
                        },
                      );
                    }),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFF1E3A6D)),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(rating),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A6D),
                foregroundColor: Colors.white,
              ),
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }
}
