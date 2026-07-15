import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

const _navy = Color(0xFF1E3A6D);
const _orange = Color(0xFFFF7A30);

class NotificationsSheet extends StatelessWidget {
  final FirebaseFirestore db;
  final String uid;

  const NotificationsSheet({super.key, required this.db, required this.uid});

  Future<void> _markRead(String docId) {
    return db.collection('notifications').doc(docId).update({'read': true});
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                "Notifications",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _navy,
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: db
                    .collection('notifications')
                    .where('uid', isEqualTo: uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text("Error: ${snapshot.error}"));
                  }
                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(color: _navy),
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
                    return const Center(child: Text("You're all caught up."));
                  }
                  return ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    itemCount: sortedDocs.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final doc = sortedDocs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final title = (data['title'] ?? 'Notification') as String;
                      final body = (data['body'] ?? '') as String;
                      final read = (data['read'] ?? false) as bool;

                      return InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: read ? null : () => _markRead(doc.id),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: read
                                ? Colors.white
                                : _navy.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!read)
                                Container(
                                  margin: const EdgeInsets.only(
                                    top: 5,
                                    right: 8,
                                  ),
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: _orange,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (body.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        body,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
