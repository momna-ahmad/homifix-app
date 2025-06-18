import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // Required for DateFormat
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'main.dart';
import 'viewRoute.dart' ;

//notification code
void _scheduleOrderReminder ({
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
    print('inside if') ;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Schedule', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 1,
      ),

      body: Column(
        children: [
          // --- Filter Buttons ---
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilterChip(
                  label: const Text('Upcoming'),
                  selected: selectedFilter == 'upcoming',
                  onSelected: (_) {
                    setState(() {
                      selectedFilter = 'upcoming';
                    });
                  },
                  selectedColor: Colors.blue.shade100,
                  checkmarkColor: Colors.blue,
                ),
                const SizedBox(width: 10),
                FilterChip(
                  label: const Text('History'),
                  selected: selectedFilter == 'history',
                  onSelected: (_) {
                    setState(() {
                      selectedFilter = 'history';
                    });
                  },
                  selectedColor: Colors.blue.shade100,
                  checkmarkColor: Colors.blue,
                ),
              ],
            ),
          ),

          // --- Orders List ---
          Expanded(
            child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              future: _fetchUserOrders(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Error loading data'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
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
                  return const Center(child: Text('No orders found.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredOrders.length,
                  itemBuilder: (context, index) {
                    final order = filteredOrders[index];
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
                        statusColor = Colors.orange.shade700;
                        statusIcon = Icons.pending_actions;
                        break;
                      case 'completed':
                        statusColor = Colors.green.shade700;
                        statusIcon = Icons.task_alt;
                        break;
                      case 'cancelled':
                        statusColor = Colors.red.shade700;
                        statusIcon = Icons.cancel;
                        break;
                      default:
                        statusColor = Colors.grey.shade700;
                        statusIcon = Icons.info_outline;
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 5,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(service,
                                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue.shade800),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(statusIcon, size: 18, color: statusColor),
                                      const SizedBox(width: 6),
                                      Text(status,
                                        style: TextStyle(
                                          color: statusColor,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 16),
                            Row(
                              children: [
                                const Icon(Icons.location_pin, size: 20, color: Colors.blueGrey),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text('Location: $location',
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 16,
                              runSpacing: 8,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_today, size: 20, color: Colors.blueGrey),
                                    const SizedBox(width: 4),
                                    Text('Date: $date', style: Theme.of(context).textTheme.bodyLarge),
                                  ],
                                ),
                                Row(
                                  children: [
                                    const Icon(Icons.access_time, size: 20, color: Colors.blueGrey),
                                    const SizedBox(width: 4),
                                    Text('Time: $time', style: Theme.of(context).textTheme.bodyLarge),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.payments, size: 20, color: Colors.blueGrey),
                                const SizedBox(width: 10),
                                Text('Price: Rs. $price',
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (selectedFilter == 'upcoming' && lat != null && lng != null)
                              Align(
                                alignment: Alignment.centerRight,
                                child: ElevatedButton.icon(
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
                                  icon: const Icon(Icons.map, color: Colors.white),
                                  label: const Text('View Route'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue.shade800,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
