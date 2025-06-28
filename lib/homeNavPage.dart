import 'package:flutter/material.dart';
import 'CustomerOrderPage.dart';
import 'professional/professionalOrderPage.dart';
import 'professional/addServicesPage.dart';
import 'profilePage.dart';
import 'landingPage.dart';
import 'professional/professionalSchedule.dart';
import 'customerHistory.dart';
import 'professional/professionalProfile.dart';
import 'customerProfile.dart';
import 'adminDashboard.dart';
import 'users.dart';
import 'badgeRequestsPage.dart';
import 'adminOrders.dart';
import 'requests.dart';

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
    final role = widget.role.toLowerCase();

    if (role == 'professional') {
      _pages = [
        AddServicesPage(userId: widget.userId, role: widget.role),
        ProfessionalOrdersPage(professionalId: widget.userId),
        ProfessionalSchedule(userId: widget.userId),
        ProfessionalProfile(userId: widget.userId),
      ];
    } else if (role == 'client') {
      _pages = [
        LandingPage(),
        CustomerOrdersPage(userId: widget.userId),
        CustomerProfile(userId: widget.userId),
        CustomerHistoryPage(userId: widget.userId),
      ];
    } else if (role == 'admin') {
      _pages = [
        AdminDashboard(),
        UserSchedule(userId: widget.userId),
        AdminOrders(),
        UserRequests(userId: widget.userId), // Capitalized class name
      ];
    } else {
      _pages = [const Center(child: Text("Unknown role"))];
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
      backgroundColor: const Color(0xFFF0F9FF),
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: _buildBottomNavBar(role),
    );
  }

  Widget _buildBottomNavBar(String role) {
    int tabCount = _pages.length;

    return Container(
      height: 100,
      color: const Color(0xFFF0F9FF),
      child: Stack(
        children: [
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF22D3EE).withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(tabCount, (index) {
                  final isSelected = index == _selectedIndex;
                  final icon = _getSelectedIcon(role, index);
                  final label = _getSelectedLabel(role, index);

                  return Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(30),
                      onTap: () => _onItemTapped(index),
                      child: Container(
                        height: 60,
                        alignment: Alignment.center,
                        child: !isSelected
                            ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(icon, color: const Color(0xFF64748B), size: 20),
                            const SizedBox(height: 4),
                            Text(label,
                                style: const TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500)),
                          ],
                        )
                            : const SizedBox.shrink(), // hide because it's drawn by the animated bubble
                      ),
                    ),
                  );

                }),
              ),
            ),
          ),
          // Bubble animation
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            bottom: 30,
            left: 16 +
                (MediaQuery.of(context).size.width - 32) / tabCount * _selectedIndex +
                (MediaQuery.of(context).size.width - 32) / tabCount / 2 -
                30,
            child: Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                color: Color(0xFF22D3EE),
                shape: BoxShape.circle,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_getSelectedIcon(role, _selectedIndex),
                      color: Colors.white, size: 22),
                  const SizedBox(height: 2),
                  Text(_getSelectedLabel(role, _selectedIndex),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getSelectedIcon(String role, int index) {
    if (role == 'professional') {
      switch (index) {
        case 0:
          return Icons.home_repair_service_rounded;
        case 1:
          return Icons.work_rounded;
        case 2:
          return Icons.calendar_today_rounded;
        default:
          return Icons.person_rounded;
      }
    } else if (role == 'admin') {
      switch (index) {
        case 0:
          return Icons.dashboard;
        case 1:
          return Icons.people_alt_rounded;
        case 2:
          return Icons.shopping_cart_rounded;
        default:
          return Icons.assignment_turned_in_rounded;
      }
    } else {
      // client
      switch (index) {
        case 0:
          return Icons.home_rounded;
        case 1:
          return Icons.shopping_bag_rounded;
        case 2:
          return Icons.person_rounded;
        default:
          return Icons.history_rounded;
      }
    }
  }

  String _getSelectedLabel(String role, int index) {
    if (role == 'professional') {
      switch (index) {
        case 0:
          return 'Services';
        case 1:
          return 'Jobs';
        case 2:
          return 'Schedule';
        default:
          return 'Profile';
      }
    } else if (role == 'admin') {
      switch (index) {
        case 0:
          return 'Dashboard';
        case 1:
          return 'Users';
        case 2:
          return 'Orders';
        default:
          return 'Requests';
      }
    } else {
      switch (index) {
        case 0:
          return 'Home';
        case 1:
          return 'Orders';
        case 2:
          return 'Profile';
        default:
          return 'History';
      }
    }
  }
}