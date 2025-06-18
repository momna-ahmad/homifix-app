import 'dart:ui';
import 'package:flutter/material.dart';
import 'CustomerOrderPage.dart';
import 'professionalOrderPage.dart';
import 'addServicesPage.dart';
import 'profilePage.dart';
import 'landingPage.dart';
import 'package:home_services_app/professionalSchedule.dart' ;
import 'customerHistory.dart';

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
        AddServicesPage(userId: widget.userId,role:widget.role),
        ProfessionalOrdersPage(professionalId: widget.userId),
        ProfessionalSchedule(userId: widget.userId),
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
    return CustomerHistoryPage(userId: widget.userId);
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
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          splashColor: Colors.transparent, // No ripple
          highlightColor: Colors.transparent, // No tap glow
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          backgroundColor: Colors.blue.shade800,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white70,
          type: BottomNavigationBarType.fixed,
          items: widget.role.toLowerCase() == 'professional'
              ? const [
            BottomNavigationBarItem(icon: Icon(Icons.home_repair_service), label: 'My Services'),
            BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'Job Posts'),
            BottomNavigationBarItem(icon: Icon(Icons.schedule), label: 'Schedule'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'My Profile'),
          ]
              : const [
            BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Explore'),
            BottomNavigationBarItem(icon: Icon(Icons.assignment), label: 'My Orders'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
            BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          ],
        ),
      ),
    );
  }

}
