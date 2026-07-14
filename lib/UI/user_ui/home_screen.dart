import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:triconnect/UI/user_ui/history_tab.dart';
import 'package:triconnect/UI/user_ui/home_tab.dart';
import 'package:triconnect/UI/user_ui/profile_tab.dart';
import 'package:triconnect/services/auth_service.dart';

class HomeScreenFunctional extends StatefulWidget {
  const HomeScreenFunctional({super.key});

  @override
  State<HomeScreenFunctional> createState() => _HomeScreenFunctionalState();
}

class _HomeScreenFunctionalState extends State<HomeScreenFunctional> {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      HomeTab(authService: _authService, db: _db),
      HistoryTab(authService: _authService, db: _db),
      ProfileTab(authService: _authService, db: _db),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: SafeArea(
        child: IndexedStack(index: _selectedTab, children: tabs),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedTab,
        selectedItemColor: const Color(0xFF1E3A6D),
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
  