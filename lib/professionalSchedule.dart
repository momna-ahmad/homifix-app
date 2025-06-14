import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // Required for DateFormat
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'main.dart';



//notification code
void _scheduleOrderReminder ({
  required String service,
  required DateTime scheduledDateTime,
  required int id,
}) {
  flutterLocalNotificationsPlugin.show(
    id,
    'Test Notification',
    'Reminder for your service: "$service"',
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'high_importance_channel',
        'High Importance Notifications',
        channelDescription: 'This channel is used for important notifications.',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
    ),
  );
  //final DateTime reminderTime = scheduledDateTime.subtract(const Duration(days: 1));
  //for testing
  final DateTime reminderTime = DateTime.now().add(const Duration(minutes: 1));
  print('📅 Scheduling notification for $service at $reminderTime');



  // Only schedule if the reminder time is still in the future
  if (reminderTime.isAfter(DateTime.now())) {
    print('inside if') ;
    print('📅 Scheduling notification for $service at $reminderTime');
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
      matchDateTimeComponents: DateTimeComponents.dateAndTime,
    );
  }
}

//widget code

class ProfessionalSchedule extends StatelessWidget {
  final String userId; // Parameter to receive the professional's user ID

  const ProfessionalSchedule({super.key, required this.userId});

  // Helper function to fetch the user document from Firestore
  Future<DocumentSnapshot<Map<String, dynamic>>> _fetchUserOrders() {
    return FirebaseFirestore.instance.collection('users').doc(userId).get();
  }

  // Helper function to parse date and time strings into a single DateTime object for sorting
  static DateTime? _parseDateTime(String? dateString, String? timeString) {
    if (dateString == null || timeString == null) {
      return null; // Cannot parse if parts are missing
    }
    try {
      // Combines date and time strings (e.g., "2025-06-10" + "10:30 AM")
      final String dateTimeCombined = '$dateString $timeString';
      // Parses the combined string into a DateTime object
      // "yyyy-MM-dd" for date part, "hh:mm a" for 12-hour time with AM/PM
      return DateFormat("yyyy-MM-dd hh:mm a").parse(dateTimeCombined);
    } catch (e) {
      // Print error if parsing fails, useful for debugging inconsistent data formats
      print('Error parsing date/time "$dateString $timeString": $e');
      return null; // Return null if parsing fails
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Schedule',
          style: TextStyle(color: Colors.black),
        ),
        centerTitle: false, // Aligns title to the left
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black), // back button & icons
        elevation: 1, // optional subtle shadow
      ),

      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: _fetchUserOrders(), // Call the async function to get user data
        builder: (context, snapshot) {
          // --- 1. Error Handling ---
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.red, fontSize: 16),
              ),
            );
          }

          // --- 2. Loading State ---
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
              ),
            );
          }

          // --- 3. No User Data / User Not Found ---
          if (!snapshot.hasData || !snapshot.data!.exists || snapshot.data!.data() == null) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_off, size: 80, color: Colors.grey),
                  SizedBox(height: 20),
                  Text(
                    'Professional profile not found or no data available.',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          // --- 4. Extracting and Sorting Orders ---
          final userData = snapshot.data!.data()!;
          // Safely get the 'assignedOrders' array (or whatever field name you use)
          final List<dynamic> rawOrders = userData['orders'] ?? [];

          // Cast to List<Map<String, dynamic>> and filter out any non-map items
          List<Map<String, dynamic>> orders = rawOrders
              .whereType<Map<String, dynamic>>() // Ensures only maps are processed
              .toList();

          if (orders.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_month, size: 80, color: Colors.grey),
                  SizedBox(height: 20),
                  Text(
                    'No assigned orders in your schedule yet.',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          // Sort the orders list by date and time
          orders.sort((a, b) {
            final DateTime? dateTimeA = _parseDateTime(a['date'] as String?, a['time'] as String?);
            final DateTime? dateTimeB = _parseDateTime(b['date'] as String?, b['time'] as String?);

            // Handle cases where parsing fails (e.g., missing or invalid date/time strings)
            // Nulls will be treated as later, pushing them to the end of the sorted list
            if (dateTimeA == null && dateTimeB == null) return 0;
            if (dateTimeA == null) return 1; // 'a' comes after 'b' (a is null)
            if (dateTimeB == null) return -1; // 'a' comes before 'b' (b is null)

            // Actual comparison of valid DateTime objects
            return dateTimeA.compareTo(dateTimeB);
          });

          // --- 5. Displaying the Sorted Schedule ---
          return ListView.separated(
            padding: const EdgeInsets.all(16.0),
            itemCount: orders.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12), // Space between cards
            itemBuilder: (context, index) {
              final order = orders[index];
              // Safely extract data with fallbacks
              final String service = order['service'] as String? ?? 'N/A Service';
              final String date = order['date'] as String? ?? 'N/A Date';
              final String time = order['time'] as String? ?? 'N/A Time';
              final String location = order['location']['address'] as String? ?? 'N/A' ;
              final String status = order['completionStatus'] as String? ?? 'Unknown';
              final String price = (order['price'] ?? 'N/A').toString(); // Convert price to string if it's a number
              //for notification
              final DateTime? orderDateTime = _parseDateTime(order['date'], order['time']);

              if (orderDateTime != null) {
                _scheduleOrderReminder(
                  service: service,
                  scheduledDateTime: orderDateTime,
                  id: index, // Or use a unique ID like order.hashCode
                );
              }

              // Determine display properties based on status
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
                elevation: 5, // Nice shadow effect
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15), // Rounded corners for the card
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Service Name
                          Expanded(
                            child: Text(
                              service,
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.deepPurple,
                              ),
                              overflow: TextOverflow.ellipsis, // Prevents text overflow
                            ),
                          ),
                          // Status Badge
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
                                Text(
                                  status,
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
                      const Divider(height: 16, thickness: 0.8, color: Colors.grey),
                      // Customer Name
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.location_pin, size: 20, color: Colors.blueGrey),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              'Location: $location',
                              style: Theme.of(context).textTheme.titleMedium,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),
                      // Date & Time
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Icon(Icons.calendar_today, size: 20, color: Colors.blueGrey),
                          Text(
                            'Date: $date',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const Icon(Icons.access_time, size: 20, color: Colors.blueGrey),
                          Text(
                            'Time: $time',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),
                      // Price
                      Row(
                        children: [
                          const Icon(Icons.payments, size: 20, color: Colors.blueGrey),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              'Price: Rs. $price',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                      // You can add action buttons (e.g., "Start Service", "Contact Customer") here
                      // Align(
                      //   alignment: Alignment.bottomRight,
                      //   child: TextButton(
                      //     onPressed: () {
                      //       // Action for this specific order
                      //     },
                      //     child: const Text('View Details'),
                      //   ),
                      // ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}