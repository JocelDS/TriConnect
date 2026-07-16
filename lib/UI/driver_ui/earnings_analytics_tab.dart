import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:triconnect/UI/driver_ui/widgets/completed_trip_tile.dart';
import 'package:triconnect/UI/driver_ui/widgets/earnings_summary_card.dart';
import 'package:triconnect/UI/driver_ui/widgets/earnings_trend_chart.dart';
import 'package:triconnect/services/auth_service.dart';

class EarningsTab extends StatefulWidget {
  const EarningsTab({super.key});

  @override
  State<EarningsTab> createState() => _EarningsTabState();
}

class _EarningsTabState extends State<EarningsTab> {
  static const _navy = Color(0xFF1A2744);
  static const _blue = Color(0xFF2F5BD3);

  final AuthService _authService = AuthService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? get _uid => _authService.currentUser?.uid;

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text("Earnings & Cashout"),
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: uid == null
          ? const Center(child: Text("Sign in to view your earnings."))
          : StreamBuilder<QuerySnapshot>(
              stream: _db
                  .collection('ride_history')
                  .where('driverId', isEqualTo: uid)
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

                final docs =
                    List<QueryDocumentSnapshot>.from(snapshot.data!.docs)
                      ..sort((a, b) {
                        final aTime =
                            (a.data() as Map<String, dynamic>)['completedAt'];
                        final bTime =
                            (b.data() as Map<String, dynamic>)['completedAt'];
                        if (aTime is Timestamp && bTime is Timestamp) {
                          return bTime.compareTo(aTime);
                        }
                        return 0;
                      });

                final stats = _computeStats(docs);

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      EarningsSummaryCard(
                        today: stats.today,
                        thisWeek: stats.thisWeek,
                        total: stats.total,
                        onCashOut: () => _showSnack(
                          "Cash out requested for ₱${stats.total.toStringAsFixed(2)}. This is a demo action.",
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "Earnings Trends",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      EarningsTrendChart(dailyTotals: stats.dailyTotals),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Completed Trips",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "${docs.length} total",
                            style: const TextStyle(color: _blue, fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (docs.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            "No completed trips yet.",
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      else
                        ...docs
                            .take(20)
                            .map((doc) => CompletedTripTile(doc: doc)),
                    ],
                  ),
                );
              },
            ),
    );
  }

  _EarningsSummary _computeStats(List<QueryDocumentSnapshot> docs) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));

    double today = 0;
    double thisWeek = 0;
    double total = 0;
    final dailyTotals = List<double>.filled(7, 0);

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final fare = (data['fare'] as num?)?.toDouble() ?? 0.0;
      final ts = data['completedAt'];
      total += fare;

      if (ts is Timestamp) {
        final completed = ts.toDate();
        if (!completed.isBefore(todayStart)) {
          today += fare;
        }
        if (!completed.isBefore(weekStart)) {
          thisWeek += fare;
        }

        final dayStart = DateTime(
          completed.year,
          completed.month,
          completed.day,
        );
        final daysAgo = todayStart.difference(dayStart).inDays;
        if (daysAgo >= 0 && daysAgo < 7) {
          dailyTotals[6 - daysAgo] += fare;
        }
      }
    }

    return _EarningsSummary(
      today: today,
      thisWeek: thisWeek,
      total: total,
      dailyTotals: dailyTotals,
    );
  }
}

class _EarningsSummary {
  final double today;
  final double thisWeek;
  final double total;
  final List<double> dailyTotals;

  const _EarningsSummary({
    required this.today,
    required this.thisWeek,
    required this.total,
    required this.dailyTotals,
  });
}
