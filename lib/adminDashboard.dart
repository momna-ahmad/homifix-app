import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login.dart'; // Adjust path as needed

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
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            buildStatCard('Professional', professionalCount, Colors.indigo),
            buildStatCard('Customers', customerCount, Colors.teal),
          ],
        ),
      ),
    );
  }
}