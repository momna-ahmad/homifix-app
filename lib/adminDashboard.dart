import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login.dart'; // Adjust path if needed
import 'adminOrders.dart';
import 'landingPage.dart';
import 'professionals.dart';
import 'customers.dart';
import 'package:home_services_app/BadgeRequestsPage.dart' ;

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

      setState(() {
        professionalCount = professionals.docs.length;
        customerCount = customers.docs.length;
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching user counts: $e');
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
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 10),
            Text('$count',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
      ),
    );
  }

  // Pages list including Home with stats
  List<Widget> get _pages => [
    isLoading
        ? const Center(child: CircularProgressIndicator())
        : Padding(
      padding: const EdgeInsets.all(16.0),
      child: GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        children: [
          buildStatCard('Professionals', professionalCount, Colors.indigo),
          buildStatCard('Clients', customerCount, Colors.teal),
        ],
      ),
    ),
    const ProfessionalsPage(),
    CustomersPage(),
    AdminOrders(),
    BadgeRequestsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black),
            tooltip: 'Logout',
            onPressed: () => logoutUser(context),
          ),
        ],
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        selectedItemColor: Colors.blue.shade800,
        unselectedItemColor: Colors.grey,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Professionals'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Clients'),
          BottomNavigationBarItem(icon: Icon(Icons.work), label: 'Services'),
          BottomNavigationBarItem(icon: Icon(Icons.work), label: 'Requests'),
        ],
      ),
    );
  }
}
