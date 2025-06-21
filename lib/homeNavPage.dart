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
      backgroundColor: const Color(0xFFF0F9FF), // Light blue background to match the theme
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      extendBody: false,
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          height: 56, // Reduced height from 60 to 56
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
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
            border: Border.all(
              color: const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(
              4,
                  (index) {
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
                      padding: const EdgeInsets.symmetric(vertical: 4), // Reduced vertical padding from 6 to 4
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Icon container
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF22D3EE)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: isSelected
                                  ? [
                                BoxShadow(
                                  color: const Color(0xFF22D3EE).withOpacity(0.3),
                                  spreadRadius: 0,
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                                  : null,
                            ),
                            child: Icon(
                              icon,
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF64748B),
                              size: 18, // Reduced icon size from 20 to 18
                            ),
                          ),
                          const SizedBox(height: 1), // Reduced spacing from 2 to 1
                          // Label
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            style: TextStyle(
                              color: isSelected
                                  ? const Color(0xFF22D3EE)
                                  : const Color(0xFF64748B),
                              fontSize: 10,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                            child: Text(
                              label,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}