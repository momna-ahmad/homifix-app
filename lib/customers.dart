import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// ----------- Customer Model -----------
class Customer {
  final String uid;
  final String name;
  final String email;
  final String fcmToken;
  final String createdAt;
  final String role;
  final int orderCount;

  Customer({
    required this.uid,
    required this.name,
    required this.email,
    required this.fcmToken,
    required this.createdAt,
    required this.role,
    required this.orderCount,
  });

  factory Customer.fromFirestore(
      DocumentSnapshot doc,
      String emailIfMatch,
      int orderCount,
      ) {
    final data = doc.data() as Map<String, dynamic>;
    return Customer(
      uid: doc.id,
      name: data['name'] ?? 'No Name',
      email: emailIfMatch,
      fcmToken: data['fcmToken'] ?? 'No Token',
      createdAt: data['createdAt']?.toString() ?? 'No Date',
      role: data['role'] ?? '',
      orderCount: orderCount,
    );
  }
}

/// ----------- Customer Service -----------
class CustomersService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<int> _getOrderCount(String customerId) async {
    final ordersSnapshot = await _firestore
        .collection('orders')
        .where('customerId', isEqualTo: customerId)
        .get();

    return ordersSnapshot.docs.length;
  }

  Future<List<Customer>> fetchCustomers() async {
    final querySnapshot = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'Client')
        .get();

    List<Customer> customers = [];

    for (var doc in querySnapshot.docs) {
      // FIX: Get email from document data instead of only current user
      String email = doc.data()['email'] ?? 'No Email';
      int orderCount = await _getOrderCount(doc.id);

      customers.add(Customer.fromFirestore(doc, email, orderCount));
    }

    return customers;
  }

  /// ----------- Live Stream of Customers -----------
  Stream<List<Customer>> customersStream() {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: 'Client')
        .snapshots()
        .asyncMap((snapshot) async {
      List<Customer> customers = [];

      for (var doc in snapshot.docs) {
        String email = doc.data()['email'] ?? 'No Email';
        int orderCount = await _getOrderCount(doc.id);

        customers.add(Customer.fromFirestore(doc, email, orderCount));
      }

      return customers;
    });
  }
}

/// ----------- Static Customer List Page (With Refresh) -----------
class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key});

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  final CustomersService _customersService = CustomersService();
  List<Customer> _customers = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      final customers = await _customersService.fetchCustomers();
      setState(() {
        _customers = customers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 60, color: Colors.red),
            const SizedBox(height: 10),
            Text('Error: $_errorMessage'),
            ElevatedButton(
              onPressed: _loadCustomers,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_customers.isEmpty) {
      return const Center(child: Text('No customers found.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _customers.length,
      itemBuilder: (context, index) {
        final customer = _customers[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text(customer.name),
            // FIX: Display both email and order count
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(customer.email),
                Text('Total Orders: ${customer.orderCount}'),
              ],
            ),
            trailing: CircleAvatar(
              child: Text('${customer.orderCount}'),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Customers')),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadCustomers,
        child: const Icon(Icons.refresh),
      ),
    );
  }
}

/// ----------- Live Customer Page (StreamBuilder) -----------
class CustomersStreamPage extends StatelessWidget {
  final CustomersService _customersService = CustomersService();

  CustomersStreamPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Customers'),
      ),
      body: StreamBuilder<List<Customer>>(
        stream: _customersService.customersStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final customers = snapshot.data!;
          if (customers.isEmpty) {
            return const Center(child: Text('No customers found.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: customers.length,
            itemBuilder: (context, index) {
              final customer = customers[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(customer.name),
                  // FIX: Display both email and order count
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(customer.email),
                      Text('Total Orders: ${customer.orderCount}'),
                    ],
                  ),
                  trailing: CircleAvatar(
                    child: Text('${customer.orderCount}'),
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