import 'package:flutter/material.dart';
import 'active_trip_tab.dart';

class DriverDashboardTab extends StatefulWidget {
  const DriverDashboardTab({super.key});

  @override
  State<DriverDashboardTab> createState() => _DriverDashboardTabState();
}

class _DriverDashboardTabState extends State<DriverDashboardTab> {
  static const _navy = Color(0xFF1A2744);
  static const _blue = Color(0xFF2F5BD3);

  bool _hasRequest = true;

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _declineRide() {
    setState(() => _hasRequest = false);
    _showSnack("Ride request declined.");
  }

  void _acceptRide() {
    setState(() => _hasRequest = false);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ActiveTripTab()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _buildTopBar(),
            const SizedBox(height: 18),
            _buildEarningsCard(),
            const SizedBox(height: 14),

            // Stats row
            Row(
              children: [
                Expanded(
                  child: _statCard(
                    icon: Icons.directions_car_filled,
                    value: "12",
                    label: "Trips",
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statCard(
                    icon: Icons.star,
                    value: "4.95",
                    label: "Rating",
                    iconColor: Colors.amber,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Active Requests",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _navy,
                  ),
                ),
                if (_hasRequest) _liveBadge(),
              ],
            ),
            const SizedBox(height: 12),

            if (_hasRequest)
              _rideRequestCard(
                name: "Alex Johnson",
                rating: "4.8",
                distance: "2.4 miles away",
                fare: "\$18.20",
                pickup: "302 Market St, San Francisco",
                destination: "Mission District, 16th St",
              )
            else
              _noRequestCard(),
            const SizedBox(height: 20),

            const Text(
              "Scheduled Ride",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _navy,
              ),
            ),
            const SizedBox(height: 12),
            _scheduledRideCard(),
            const SizedBox(height: 20),

            _trafficMapCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Color(0xFF3B5B92), Color(0xFF1A2744)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Icon(
            Icons.directions_car,
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            "TriConnect",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _navy,
            ),
          ),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => _showSnack("No new notifications."),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha:0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.notifications_none, color: _navy, size: 22),
          ),
        ),
      ],
    );
  }

  Widget _buildEarningsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.05),
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
              const Text(
                "\$142.50",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: _navy,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: const [
                  Icon(Icons.arrow_upward, size: 14, color: Colors.green),
                  SizedBox(width: 2),
                  Text(
                    "+12% from yesterday",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _blue.withValues(alpha:0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.credit_card, color: _blue, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required String value,
    required String label,
    Color iconColor = _blue,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha:0.05), blurRadius: 8),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _navy,
            ),
          ),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _liveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: _blue.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.circle, size: 8, color: _blue),
          SizedBox(width: 6),
          Text(
            "Live",
            style: TextStyle(
              color: _blue,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _noRequestCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha:0.05), blurRadius: 8),
        ],
      ),
      alignment: Alignment.center,
      child: const Text(
        "No active ride requests right now.",
        style: TextStyle(color: Colors.grey),
      ),
    );
  }

  Widget _rideRequestCard({
    required String name,
    required String rating,
    required String distance,
    required String fare,
    required String pickup,
    required String destination,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha:0.05), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(
                radius: 18,
                backgroundColor: Color(0xFFE5EAF5),
                child: Icon(Icons.person, color: _blue),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _navy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.star, size: 13, color: Colors.amber),
                        const SizedBox(width: 3),
                        Text(
                          "$rating · $distance",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    fare,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _blue,
                      fontSize: 16,
                    ),
                  ),
                  const Text(
                    "Estimated Fare",
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: _blue, width: 2),
                    ),
                  ),
                  Container(width: 2, height: 26, color: Colors.grey.shade300),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: _navy,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "PICKUP",
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      pickup,
                      style: const TextStyle(fontSize: 13, color: _navy),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      "DESTINATION",
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      destination,
                      style: const TextStyle(fontSize: 13, color: _navy),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _declineRide,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _navy,
                    side: const BorderSide(color: Color(0xFFD8DEEA)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text("Decline"),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _acceptRide,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _navy,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Accept Ride",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _scheduledRideCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha:0.05), blurRadius: 8),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F2F7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.schedule, color: _navy, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Scheduled Ride",
                  style: TextStyle(fontWeight: FontWeight.bold, color: _navy),
                ),
                SizedBox(height: 2),
                Text(
                  "In 45 minutes · Downtown",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          const Text(
            "\$24.00",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: _navy,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _trafficMapCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 150,
        width: double.infinity,
        color: const Color(0xFFEDEFF5),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _LightMapGridPainter()),
            ),
            Positioned(
              left: 12,
              bottom: 12,
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: _blue,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    "Monitoring traffic in your area...",
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LightMapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.black.withValues(alpha:0.06)
      ..strokeWidth = 1;

    const spacing = 22.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    final roadPaint = Paint()
      ..color = Colors.black.withValues(alpha:0.14)
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(size.width * 0.1, 0),
      Offset(size.width * 0.5, size.height),
      roadPaint,
    );
    canvas.drawLine(
      Offset(0, size.height * 0.65),
      Offset(size.width, size.height * 0.25),
      roadPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _LightMapGridPainter oldDelegate) => false;
}
