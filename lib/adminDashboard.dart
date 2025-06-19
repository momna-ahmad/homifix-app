import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login.dart';
import 'adminOrders.dart';
import 'landingPage.dart';
import 'professionals.dart';
import 'customers.dart';
import 'package:home_services_app/BadgeRequestsPage.dart' ;
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart'; // for formatting dates
int pendingOrders = 0;
int completedOrders = 0;

void logoutUser(BuildContext context) async {
  await FirebaseAuth.instance.signOut();
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();

  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
  );
}


class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _currentIndex = 0;

  int professionalCount = 0;
  int customerCount = 0;
  bool isLoading = true;
  Map<String, int> customerGrowthByMonth = {};
  Map<String, int> professionalGrowthByMonth = {};



  @override
  void initState() {
    super.initState();
    fetchCounts();
  }



  Future<void> fetchCounts() async {
    try {
      final usersCollection = FirebaseFirestore.instance.collection('users');
      final professionals = await usersCollection.where('role', isEqualTo: 'Professional').get();
      final customers = await usersCollection.where('role', isEqualTo: 'Client').get();
      final now = DateTime.now();
      final sixMonthsAgo = DateTime(now.year, now.month - 5);

      Map<String, int> growth = {};
      for (int i = 0; i < 6; i++) {
        final date = DateTime(now.year, now.month - i);
        final monthKey = DateFormat('yyyy-MM').format(date);
        growth[monthKey] = 0;
      }

// Count actual customers
      for (var doc in customers.docs) {
        final timestamp = doc.data()['createdAt'];
        if (timestamp != null && timestamp is Timestamp) {
          final date = timestamp.toDate();
          final month = DateFormat('yyyy-MM').format(date);
          if (growth.containsKey(month)) {
            growth[month] = (growth[month] ?? 0) + 1;
          }
        }
      }
// Count actual customers
      for (var doc in professionals.docs) {
        final timestamp = doc.data()['createdAt'];
        if (timestamp != null && timestamp is Timestamp) {
          final date = timestamp.toDate();
          final month = DateFormat('yyyy-MM').format(date);
          if (growth.containsKey(month)) {
            growth[month] = (growth[month] ?? 0) + 1;
          }
        }
      }

      // Order data
      final ordersSnapshot = await FirebaseFirestore.instance.collection('orders').get();

      int pending = 0;
      int accepted = 0;

      for (var doc in ordersSnapshot.docs) {
        final applications = doc.data()['applications'] as List<dynamic>?;

        if (applications != null) {
          for (var app in applications) {
            if (app is Map<String, dynamic> && app.containsKey('status')) {
              if (app['status'] == 'pending') {
                pending++;
                break; // Count once per order
              } else if (app['status'] == 'accepted') {
                accepted++;
                break;
              }
            }
          }
        }
      }

      setState(() {
        professionalCount = professionals.docs.length;
        customerCount = customers.docs.length;
        customerGrowthByMonth = growth;
        pendingOrders = pending;
        completedOrders = accepted;
        professionalGrowthByMonth = growth;
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching counts: $e');
      setState(() {
        isLoading = false;
      });
    }
  }




  Widget buildStatCard(String title, int count, Color color) {
    return Card(
      elevation: 4,
      color: color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title,
                style: const TextStyle(fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            const SizedBox(height: 10),
            Text('$count',
                style: const TextStyle(fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
          ],
        ),
      ),
    );
  }

  // Pages list including Home with stats
  List<Widget> get _pages => [
    // 0: Dashboard
    isLoading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              buildStatCard('Professional', professionalCount, Colors.indigo),
              buildStatCard('Clients', customerCount, Colors.teal),
              buildStatCard('Pending Orders', pendingOrders, Colors.orange),
              buildStatCard('Accepted Orders', completedOrders, Colors.green),
            ],
          ),
          const SizedBox(height: 20),
          buildOrderStatusChart(),
          const SizedBox(height: 20),
          buildCustomerGrowthChart(),
          const SizedBox(height: 20),
          buildProfessionalGrowthChart(),
        ],
      ),
    ),

    // 1: Professionals Page
    const ProfessionalsPage(),

    // 2: Clients Page
    CustomersPage(),

    // 3: Admin Orders Page
    AdminOrders(),

    // 4: Badge Requests Page
    BadgeRequestsPage(),
  ];


  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: _currentIndex == 0
            ? AppBar(
          title: const Text('Admin Dashboard'),
          backgroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.black),
              tooltip: 'Logout',
              onPressed: () => logoutUser(context),
            ),
          ],
        )
            : null,
    body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        selectedItemColor: Colors.blue.shade800,
        unselectedItemColor: Colors.grey,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Professionals'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Clients'),
          BottomNavigationBarItem(icon: Icon(Icons.work), label: 'Services'),
          BottomNavigationBarItem(
              icon: Icon(Icons.verified_user), label: 'Badge Requests'),
        ],
      ),
    );
  }
  Widget buildOrderStatusChart() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text("Order Status", style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: [
                    PieChartSectionData(
                      color: Colors.orange,
                      value: pendingOrders.toDouble(),
                      title: 'Pending',
                      radius: 50,
                      titleStyle: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    PieChartSectionData(
                      color: Colors.green,
                      value: completedOrders.toDouble(),
                      title: 'Accepted',
                      radius: 50,
                      titleStyle: const TextStyle(color: Colors.white, fontSize: 14),
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
  Widget buildCustomerGrowthChart() {
    final sortedKeys = customerGrowthByMonth.keys.toList()..sort();
    final spots = List.generate(sortedKeys.length, (index) {
      final month = sortedKeys[index];
      return FlSpot(index.toDouble(), customerGrowthByMonth[month]!.toDouble());
    });

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Customer Growth (Last 6 Months)", style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          int index = value.toInt();
                          if (index >= 0 && index < sortedKeys.length) {
                            final fullMonth = DateFormat('MMM').format(DateTime.parse("${sortedKeys[index]}-01"));
                            return Text(fullMonth, style: const TextStyle(fontSize: 10));
                          }
                          return const SizedBox();
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      barWidth: 3,
                      color: Colors.blue,
                      dotData: FlDotData(show: false),
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

  Widget buildProfessionalGrowthChart() {
    final sortedKeys = professionalGrowthByMonth.keys.toList()..sort();
    final spots = List.generate(sortedKeys.length, (index) {
      final month = sortedKeys[index];
      return FlSpot(index.toDouble(), professionalGrowthByMonth[month]!.toDouble());
    });

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Professional Growth (Last 6 Months)", style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          int index = value.toInt();
                          if (index >= 0 && index < sortedKeys.length) {
                            final fullMonth = DateFormat('MMM').format(DateTime.parse("${sortedKeys[index]}-01"));
                            return Text(fullMonth, style: const TextStyle(fontSize: 10));
                          }
                          return const SizedBox();
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      barWidth: 3,
                      color: Colors.purple,
                      dotData: FlDotData(show: false),
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




}

