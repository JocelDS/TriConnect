import 'package:flutter/material.dart';

/// "Today's Earnings" summary card shown at the top of the driver dashboard.
class EarningsCard extends StatelessWidget {
  final double todayEarnings;
  final double? percentChangeFromYesterday;

  const EarningsCard({
    super.key,
    required this.todayEarnings,
    required this.percentChangeFromYesterday,
  });

  @override
  Widget build(BuildContext context) {
    final hasChange = percentChangeFromYesterday != null;
    final isUp = hasChange && percentChangeFromYesterday! >= 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "TODAY'S EARNINGS",
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "₱${todayEarnings.toStringAsFixed(2)}",
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A2744),
                ),
              ),
              const SizedBox(height: 6),
              if (hasChange)
                Row(
                  children: [
                    Icon(
                      isUp ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 14,
                      color: isUp ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      "${percentChangeFromYesterday!.abs().toStringAsFixed(0)}% from yesterday",
                      style: TextStyle(
                        fontSize: 12,
                        color: isUp ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                )
              else
                const Text(
                  "No earnings recorded yesterday",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF2F5BD3).withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.credit_card,
              color: Color(0xFF2F5BD3),
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}
