import 'package:flutter/material.dart';

/// Navy summary card on the Earnings screen: today/this-week/available
/// balance plus the Cash Out action.
class EarningsSummaryCard extends StatelessWidget {
  final double today;
  final double thisWeek;
  final double total;
  final double availableBalance;

  const EarningsSummaryCard({
    super.key,
    required this.today,
    required this.thisWeek,
    required this.total,
    required this.availableBalance,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2744),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "₱${today.toStringAsFixed(2)}",
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const Text("Today's Earnings", style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2F5BD3),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "₱${availableBalance.toStringAsFixed(2)}",
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const Text("Available Balance", style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "₱${thisWeek.toStringAsFixed(2)}",
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const Text("This Week", style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 8),
          Text(
            "₱${total.toStringAsFixed(2)} lifetime",
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }
}