import 'package:flutter/material.dart';
import 'badgeRequestsPage.dart'; // <-- Badge requests screen
import 'reported.dart';     // <-- Reported profiles screen

class UserRequests extends StatefulWidget {
  final String userId;

  const UserRequests({super.key, required this.userId});

  @override
  State<UserRequests> createState() => _UserScheduleState();
}

class _UserScheduleState extends State<UserRequests> {
  bool showBadgeRequests = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F9FF),
      appBar: AppBar(
        title: const Text(
          'Request Management',
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
              _buildToggleButton('Badge Requests', showBadgeRequests, () {
                setState(() {
                  showBadgeRequests = true;
                });
              }),
              const SizedBox(width: 12),
              _buildToggleButton('Reports', !showBadgeRequests, () {
                setState(() {
                  showBadgeRequests = false;
                });
              }),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: showBadgeRequests
                ? BadgeRequestsPage()
                : ReportsPage(userId:widget.userId),
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
