import 'package:flutter/material.dart';
import 'CustomerOrderPage.dart';
import 'professionalOrderPage.dart';
import 'addServicesPage.dart';
import 'profilePage.dart';
import 'landingPage.dart';
import 'professionalSchedule.dart';
import 'customerHistory.dart';
import 'adminDashboard.dart';
import 'badgeRequestsPage.dart'; // <-- make sure this page exists

class HomeNavPage extends StatefulWidget {
  final String userId;
  final String role;

  const HomeNavPage({super.key, required this.userId, required this.role});

  @override
  State<HomeNavPage> createState() => _HomeNavPageState();
}

class _HomeNavPageState extends State<HomeNavPage> {
  int _selectedIndex = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();

    if (widget.role.toLowerCase() == 'professional') {
      _pages = [
        AddServicesPage(userId: widget.userId, role: widget.role),
        ProfessionalOrdersPage(professionalId: widget.userId),
        ProfessionalSchedule(userId: widget.userId),
        ProfilePage(userId: widget.userId),
      ];
    } else if (widget.role.toLowerCase() == 'admin') {
      _pages = [
        const AdminDashboard(),
        const BadgeRequestsPage(), // This must be created
      ];
    } else {
      _pages = [
        LandingPage(),
        CustomerOrdersPage(userId: widget.userId),
        ProfilePage(userId: widget.userId),
        CustomerHistoryPage(userId: widget.userId),
      ];
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.role.toLowerCase();

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          backgroundColor: Colors.blue.shade800,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white70,
          type: BottomNavigationBarType.fixed,
          items: role == 'professional'
              ? const [
            BottomNavigationBarItem(icon: Icon(Icons.home_repair_service), label: 'My Services'),
            BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'Job Posts'),
            BottomNavigationBarItem(icon: Icon(Icons.schedule), label: 'Schedule'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'My Profile'),
          ]
              : role == 'admin'
              ? const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
            BottomNavigationBarItem(icon: Icon(Icons.verified_user), label: 'Badge Requests'),
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
