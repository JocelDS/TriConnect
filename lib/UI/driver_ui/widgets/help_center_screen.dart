import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// A real FAQ + support screen. "Email Support" opens the device's mail
/// app via a mailto: link, and "Call Support" opens the phone dialer —
/// both through url_launcher, so they actually do something.
class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  static const List<Map<String, String>> _faqs = [
    {
      'q': 'How do I accept a ride request?',
      'a':
          'When a request appears on your Home tab, review the pickup, destination, and fare, then tap "Accept Ride." You have to act before another driver takes it.',
    },
    {
      'q': 'How do I get paid?',
      'a':
          'Every completed trip is added to your Earnings tab automatically. Add a payout method under Profile > Payout Methods, then use "Cash Out" on the Earnings tab to withdraw your available balance.',
    },
    {
      'q': 'What if a rider isn\'t at the pickup point?',
      'a':
          'Try calling the rider using the call button on the Active Trip screen. If you can\'t reach them after a reasonable wait, you can cancel the trip.',
    },
    {
      'q': 'How is my rating calculated?',
      'a':
          'Your rating reflects feedback from completed trips. Keep pickups and drop-offs smooth and communicate clearly with riders to maintain a high rating.',
    },
  ];

  Future<void> _emailSupport(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'support@triconnect.app',
      query: 'subject=Driver Support Request',
    );
    try {
      final launched = await launchUrl(uri);
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't open your email app.")),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Couldn't open your email app: $e")),
        );
      }
    }
  }

  Future<void> _callSupport(BuildContext context) async {
    final uri = Uri(scheme: 'tel', path: '+639170000000');
    try {
      final launched = await launchUrl(uri);
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't open the dialer.")),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Couldn't open the dialer: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text("Help Center"),
        backgroundColor: const Color(0xFF1A2744),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _emailSupport(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2F5BD3),
                  ),
                  icon: const Icon(Icons.email_outlined, color: Colors.white),
                  label: const Text(
                    "Email Support",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _callSupport(context),
                  icon: const Icon(Icons.call_outlined),
                  label: const Text("Call Support"),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            "Frequently Asked Questions",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A2744),
            ),
          ),
          const SizedBox(height: 12),
          ..._faqs.map(
            (faq) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: ExpansionTile(
                title: Text(
                  faq['q']!,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    faq['a']!,
                    style: const TextStyle(color: Colors.grey, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
