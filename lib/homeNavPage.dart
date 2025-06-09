import 'dart:ui';
import 'package:flutter/material.dart';
import 'CustomerOrderPage.dart';
import 'professionalOrderPage.dart';
import 'addServicesPage.dart';
import 'profilePage.dart';
import 'landingPage.dart';

class HomeNavPage extends StatefulWidget {
  final String userId;
  final String role; // Add this
  const HomeNavPage({super.key, required this.userId, required this.role});


  @override
  State<HomeNavPage> createState() => _HomeNavPageState();
}

class _HomeNavPageState extends State<HomeNavPage> {
  int _selectedIndex = 0;

  late final List<Widget> _pages;

  @override
  @override
  void initState() {
    super.initState();
    if (widget.role.toLowerCase() == 'professional') {
      _pages = [
        LandingPage(),
        AddServicesPage(userId: widget.userId),
        ProfessionalOrdersPage(professionalId: widget.userId),
        _buildHistoryPage(),
        ProfilePage(userId: widget.userId),
      ];
    } else {
      // Assume client/customer
      _pages = [
        LandingPage(),
        CustomerOrdersPage(userId: widget.userId),
        ProfilePage(userId: widget.userId),
        _buildHistoryPage(),
      ];
    }
  }


  Widget _buildHomePage() {
    return const Center(
      child: Text("Welcome to Home Page", style: TextStyle(fontSize: 18)),
    );
  }

  Widget _buildHistoryPage() {
    return const Center(
      child: Text("History Page", style: TextStyle(fontSize: 18)),
    );
  }
  Widget _buildCustomerOrdersPage() {
    return const Center(
      child: Text("Customer Orders Page", style: TextStyle(fontSize: 18)),
    );
  }


  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.blue,
        type: BottomNavigationBarType.fixed,
        items: widget.role.toLowerCase() == 'professional'
            ? const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.home_repair_service), label: 'My Services'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'Job Posts'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'My Profile'),
        ]
            : const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.assignment), label: 'My Orders'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
        ],
      ),
    );
  }
}
