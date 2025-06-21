import 'package:flutter/material.dart';
import 'customers.dart'; // <-- Your existing customers profile screen
import 'professionals.dart'; // <-- Your existing professionals profile screen

class UserSchedule extends StatefulWidget {
  final String userId;

  const UserSchedule({super.key, required this.userId});

  @override
  State<UserSchedule> createState() => _UserScheduleState();
}

class _UserScheduleState extends State<UserSchedule> {
  bool showCustomers = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F9FF),
      appBar: AppBar(
        title: const Text(
          'User Management',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildToggleButton('Customers', showCustomers, () {
                setState(() {
                  showCustomers = true;
                });
              }),
              const SizedBox(width: 12),
              _buildToggleButton('Professionals', !showCustomers, () {
                setState(() {
                  showCustomers = false;
                });
              }),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: showCustomers
                ? CustomersPage(userId: widget.userId)
                : ProfessionalsPageWithOrders(userId: widget.userId),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String title, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0EA5E9) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF64748B),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
