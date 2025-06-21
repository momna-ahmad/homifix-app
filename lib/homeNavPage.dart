import 'package:flutter/material.dart';
import 'CustomerOrderPage.dart';
import 'professionalOrderPage.dart';
import 'addServicesPage.dart';
import 'profilePage.dart';
import 'landingPage.dart';
import 'professionalSchedule.dart';
import 'customerHistory.dart';
import 'professionalProfile.dart';

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
        ProfessionalProfile(userId: widget.userId),
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
      backgroundColor: const Color(0xFFF0F9FF),
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      extendBody: false,
      bottomNavigationBar: Container(
        height: 100, // Increased height to accommodate the bubble
        color: const Color(0xFFF0F9FF), // Match background color
        child: Stack(
          children: [
            // Main navbar container
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
                      spreadRadius: 0,
                      blurRadius: 20,
                      offset: const Offset(0, -5),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      spreadRadius: 0,
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(4, (index) {
                    final isSelected = index == _selectedIndex;

                    IconData icon;
                    String label;

                    if (role == 'professional') {
                      switch (index) {
                        case 0:
                          icon = Icons.home_repair_service_rounded;
                          label = 'Services';
                          break;
                        case 1:
                          icon = Icons.work_rounded;
                          label = 'Jobs';
                          break;
                        case 2:
                          icon = Icons.calendar_today_rounded;
                          label = 'Schedule';
                          break;
                        default:
                          icon = Icons.person_rounded;
                          label = 'Profile';
                      }
                    } else {
                      switch (index) {
                        case 0:
                          icon = Icons.home_rounded;
                          label = 'Home';
                          break;
                        case 1:
                          icon = Icons.shopping_bag_rounded;
                          label = 'Orders';
                          break;
                        case 2:
                          icon = Icons.person_rounded;
                          label = 'Profile';
                          break;
                        default:
                          icon = Icons.history_rounded;
                          label = 'History';
                      }
                    }

                    return Expanded(
                      child: GestureDetector(
                        onTap: () => _onItemTapped(index),
                        child: Container(
                          height: 60,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Only show icon and label for non-selected items
                              if (!isSelected) ...[
                                Icon(
                                  icon,
                                  color: const Color(0xFF64748B),
                                  size: 20,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  label,
                                  style: const TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),

            // Floating bubble for selected item
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              bottom: 30, // Position above the navbar
              left: 16 + (MediaQuery.of(context).size.width - 32) / 4 * _selectedIndex +
                  (MediaQuery.of(context).size.width - 32) / 8 - 30, // Center the bubble
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFF22D3EE),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF22D3EE).withOpacity(0.3),
                      spreadRadius: 0,
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _getSelectedIcon(role, _selectedIndex),
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _getSelectedLabel(role, _selectedIndex),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getSelectedIcon(String role, int index) {
    if (role == 'professional') {
      switch (index) {
        case 0: return Icons.home_repair_service_rounded;
        case 1: return Icons.work_rounded;
        case 2: return Icons.calendar_today_rounded;
        default: return Icons.person_rounded;
      }
    } else {
      switch (index) {
        case 0: return Icons.home_rounded;
        case 1: return Icons.shopping_bag_rounded;
        case 2: return Icons.person_rounded;
        default: return Icons.history_rounded;
      }
    }
  }

  String _getSelectedLabel(String role, int index) {
    if (role == 'professional') {
      switch (index) {
        case 0: return 'Services';
        case 1: return 'Jobs';
        case 2: return 'Schedule';
        default: return 'Profile';
      }
    } else {
      switch (index) {
        case 0: return 'Home';
        case 1: return 'Orders';
        case 2: return 'Profile';
        default: return 'History';
      }
    }
  }
}
