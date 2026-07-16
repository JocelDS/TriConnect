import 'package:flutter/material.dart';
import 'driver_dashboard_tab.dart';
import 'driver_profile_tab.dart';
import 'earnings_analytics_tab.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  int _selectedTab = 0;

  final List<Widget> _tabs = const [
    DriverDashboardTab(),
    EarningsTab(),
    DriverProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedTab, children: _tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedTab,
        selectedItemColor: const Color(0xFF2F5BD3),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (index) => setState(() => _selectedTab = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: "History"),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: "Profile",
          ),
        ],
      ),
    );
  }
}
