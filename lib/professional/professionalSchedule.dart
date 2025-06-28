import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // Required for DateFormat
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../main.dart';
import 'viewRoute.dart';

//notification code
void _scheduleOrderReminder({
  required String service,
  required DateTime scheduledDateTime,
  required int id,
}) {
  //final DateTime reminderTime = scheduledDateTime.subtract(const Duration(days: 1));
  //for testing
  final DateTime reminderTime = DateTime.now().add(const Duration(minutes: 1));
  print('📅 Scheduling notification for $service at $reminderTime');

  // Only schedule if the reminder time is still in the future
  if (reminderTime.isAfter(DateTime.now())) {
    print('inside if');

    flutterLocalNotificationsPlugin.zonedSchedule(
      id, // Unique notification ID (you could hash order ID)
      'Upcoming Order Reminder',
      'You have "$service" scheduled tomorrow!',
      tz.TZDateTime.from(reminderTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'high_importance_channel', // Same as your channel ID
          'High Importance Notifications',
          channelDescription: 'This channel is used for important notifications.',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
      //matchDateTimeComponents: DateTimeComponents.dateAndTime,
    );
    print('📅 Scheduling notification for $service at $reminderTime');
  }
}

//widget code

class ProfessionalSchedule extends StatefulWidget {
  final String userId;

  const ProfessionalSchedule({super.key, required this.userId});

  @override
  State<ProfessionalSchedule> createState() => _ProfessionalScheduleState();
}

class _ProfessionalScheduleState extends State<ProfessionalSchedule> {
  String selectedFilter = 'upcoming'; // 'upcoming' or 'history'
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _appointmentsKey = GlobalKey();

  Future<DocumentSnapshot<Map<String, dynamic>>> _fetchUserOrders() {
    return FirebaseFirestore.instance.collection('users').doc(widget.userId).get();
  }

  static DateTime? _parseDateTime(String? dateString, String? timeString) {
    if (dateString == null || timeString == null) return null;
    try {
      return DateFormat("yyyy-MM-dd hh:mm a").parse('$dateString $timeString');
    } catch (e) {
      print('Error parsing: $e');
      return null;
    }
  }

  void _scrollToAppointments() {
    final RenderBox? renderBox = _appointmentsKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final position = renderBox.localToGlobal(Offset.zero);
      _scrollController.animateTo(
        position.dy - 100, // Offset to show some padding above the appointments
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F9FF), // Light blue background
      appBar: AppBar(
        title: const Text(
          'My Schedule',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF0EA5E9), // Changed to darker blue
              child: const Icon(
                Icons.schedule,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Section with Promo Card
            Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  // Promo Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF22D3EE), Color(0xFF0EA5E9)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF22D3EE).withOpacity(0.3),
                          spreadRadius: 0,
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Stay Organized',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const Text(
                                'Manage your appointments efficiently',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(height: 12),
                              GestureDetector(
                                onTap: _scrollToAppointments,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    'View Schedule',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0EA5E9), // Changed to darker blue
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.calendar_today,
                          size: 60,
                          color: Colors.white30,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Filter Buttons
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedFilter = 'upcoming';
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: selectedFilter == 'upcoming'
                              ? const Color(0xFF0EA5E9) // Changed to darker blue
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              spreadRadius: 0,
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          'Upcoming',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: selectedFilter == 'upcoming'
                                ? Colors.white
                                : const Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedFilter = 'history';
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: selectedFilter == 'history'
                              ? const Color(0xFF0EA5E9) // Changed to darker blue
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              spreadRadius: 0,
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          'History',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: selectedFilter == 'history'
                                ? Colors.white
                                : const Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Orders List
            Container(
              key: _appointmentsKey, // Key for scrolling reference
              child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: _fetchUserOrders(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _buildEmptyState('Error loading data', Icons.error);
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0EA5E9)), // Changed to darker blue
                        ),
                      ),
                    );
                  }

                  final userData = snapshot.data?.data();
                  final List<dynamic> rawOrders = userData?['orders'] ?? [];
                  List<Map<String, dynamic>> orders = rawOrders.whereType<Map<String, dynamic>>().toList();

                  // Sort by date
                  orders.sort((a, b) {
                    final dateTimeA = _parseDateTime(a['date'], a['time']);
                    final dateTimeB = _parseDateTime(b['date'], b['time']);
                    if (dateTimeA == null) return 1;
                    if (dateTimeB == null) return -1;
                    return dateTimeA.compareTo(dateTimeB);
                  });

                  // Filter orders
                  final now = DateTime.now();
                  List<Map<String, dynamic>> filteredOrders = orders.where((order) {
                    final orderDateTime = _parseDateTime(order['date'], order['time']);
                    if (orderDateTime == null) return false;
                    if (selectedFilter == 'upcoming') {
                      return orderDateTime.isAfter(now);
                    } else {
                      return orderDateTime.isBefore(now);
                    }
                  }).toList();

                  if (filteredOrders.isEmpty) {
                    return _buildEmptyState(
                      selectedFilter == 'upcoming' ? 'No upcoming orders' : 'No order history',
                      selectedFilter == 'upcoming' ? Icons.schedule : Icons.history,
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: filteredOrders.length,
                    itemBuilder: (context, index) {
                      final order = filteredOrders[index];
                      return _buildOrderCard(context, order, index);
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: 100), // Bottom padding
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, Map<String, dynamic> order, int index) {
    final String service = order['service'] ?? 'N/A Service';
    final String date = order['date'] ?? 'N/A Date';
    final String time = order['time'] ?? 'N/A Time';
    final String status = order['completionStatus'] ?? 'Unknown';
    final String price = (order['price'] ?? 'N/A').toString();
    final Map<String, dynamic> locationMap = order['location'] ?? {};
    final String location = locationMap['address'] ?? 'N/A';
    final double? lat = locationMap['lat'];
    final double? lng = locationMap['lng'];

    // Schedule notification
    final DateTime? orderDateTime = _parseDateTime(order['date'], order['time']);
    if (orderDateTime != null && selectedFilter == 'upcoming') {
      _scheduleOrderReminder(
        service: service,
        scheduledDateTime: orderDateTime,
        id: index,
      );
    }

    // Set status color/icon
    Color statusColor;
    IconData statusIcon;
    switch (status.toLowerCase()) {
      case 'pending':
        statusColor = const Color(0xFFF59E0B);
        statusIcon = Icons.pending_actions;
        break;
      case 'completed':
        statusColor = const Color(0xFF10B981);
        statusIcon = Icons.task_alt;
        break;
      case 'cancelled':
        statusColor = const Color(0xFFEF4444);
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = const Color(0xFF64748B);
        statusIcon = Icons.info_outline;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with service name and status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    service,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 16, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        status,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Location
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0EA5E9).withOpacity(0.1), // Changed to darker blue
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.location_on,
                    size: 16,
                    color: Color(0xFF0EA5E9), // Changed to darker blue
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    location,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Date and Time
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0EA5E9).withOpacity(0.1), // Changed to darker blue
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: Color(0xFF0EA5E9), // Changed to darker blue
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        date,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0EA5E9).withOpacity(0.1), // Changed to darker blue
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.access_time,
                          size: 16,
                          color: Color(0xFF0EA5E9), // Changed to darker blue
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        time,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Price and Route Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0EA5E9).withOpacity(0.1), // Changed to darker blue
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.payments,
                        size: 16,
                        color: Color(0xFF0EA5E9), // Changed to darker blue
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Rs. $price',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0EA5E9), // Changed to darker blue
                      ),
                    ),
                  ],
                ),
                if (selectedFilter == 'upcoming' && lat != null && lng != null)
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0EA5E9), // Changed to darker blue
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0EA5E9).withOpacity(0.3), // Changed to darker blue
                          spreadRadius: 0,
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ViewRoute(
                              address: location,
                              lat: lat,
                              lng: lng,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.map, color: Colors.white, size: 16),
                      label: const Text(
                        'View Route',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF0EA5E9).withOpacity(0.1), // Changed to darker blue
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              icon,
              size: 48,
              color: const Color(0xFF0EA5E9), // Changed to darker blue
            ),
          ),
          const SizedBox(height: 24),
          Text(
            message,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your scheduled appointments will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF64748B),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}