import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
// Conditional imports
//import 'dart:html' as html show AnchorElement, Blob, Url;

class AdminOrders extends StatefulWidget {
  @override
  _AdminOrdersState createState() => _AdminOrdersState();
}

class _AdminOrdersState extends State<AdminOrders> {
  List<Map<String, dynamic>> orders = [];
  List<Map<String, dynamic>> filteredOrders = [];
  TextEditingController searchController = TextEditingController();
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    fetchOrders();
  }

  Future<void> fetchOrders() async {
    try {
      setState(() {
        isLoading = true;
      });

      // Access the orders collection directly
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('orders')
          .get();

      List<Map<String, dynamic>> tempOrders = [];

      for (var doc in snapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;

        String professionalName = 'Unknown';
        String customerName = 'Unknown';

        // Fetch professional name using selectedWorkerId
        if (data['selectedWorkerId'] != null && data['selectedWorkerId'].toString().isNotEmpty) {
          try {
            DocumentSnapshot professionalSnap = await FirebaseFirestore.instance
                .collection('users')
                .doc(data['selectedWorkerId'])
                .get();

            if (professionalSnap.exists) {
              var professionalData = professionalSnap.data() as Map<String, dynamic>?;
              professionalName = professionalData?['name'] ?? 'Unknown';
            }
          } catch (e) {
            print('Error fetching professional: $e');
            professionalName = 'Error loading';
          }
        }

        // Fetch customer name using customerId
        if (data['customerId'] != null && data['customerId'].toString().isNotEmpty) {
          try {
            DocumentSnapshot customerSnap = await FirebaseFirestore.instance
                .collection('users')
                .doc(data['customerId'])
                .get();

            if (customerSnap.exists) {
              var customerData = customerSnap.data() as Map<String, dynamic>?;
              customerName = customerData?['name'] ?? 'Unknown';
            }
          } catch (e) {
            print('Error fetching customer: $e');
            customerName = 'Error loading';
          }
        }

        // Handle createdAt field properly
        String createdAtString = '';
        if (data['createdAt'] != null) {
          if (data['createdAt'] is Timestamp) {
            createdAtString = data['createdAt'].toDate().toString();
          } else if (data['createdAt'] is String) {
            createdAtString = data['createdAt'];
          }
        }

        tempOrders.add({
          'service': data['category'] ?? '',
          'professional': professionalName,
          'client': customerName,
          'status': data['status'] ?? '',
          'createdAt': createdAtString,
          'price': data['price'] ?? '',
          'message': data['message'] ?? '',
        });
      }

      setState(() {
        orders = tempOrders;
        filteredOrders = tempOrders;
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching orders: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  void searchOrders(String query) {
    setState(() {
      filteredOrders = orders
          .where((order) => order['service'].toString().toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  Future<void> exportToCSV() async {
    try {
      if (!kIsWeb) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('CSV export is only supported on web')),
        );
        return;
      }

      // Prepare CSV data
      List<List<String>> csvData = [
        ['Service', 'Professional', 'Client', 'Status', 'Post Date', 'Price', 'Message']
      ];

      for (var order in filteredOrders) {
        csvData.add([
          order['service']?.toString() ?? '',
          order['professional']?.toString() ?? '',
          order['client']?.toString() ?? '',
          order['status']?.toString() ?? '',
          order['createdAt']?.toString() ?? '',
          order['price']?.toString() ?? '',
          order['message']?.toString() ?? '',
        ]);
      }

      // Convert to CSV string
      String csv = const ListToCsvConverter().convert(csvData);

      // Create and download file for web
      /*
      final bytes = utf8.encode(csv);
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', 'orders_${DateTime.now().millisecondsSinceEpoch}.csv')
        ..click();
      html.Url.revokeObjectUrl(url);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('CSV file downloaded successfully!'),
          backgroundColor: Colors.green,
        ),
      );
       */
    } catch (e) {
      print('Error exporting CSV: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error exporting CSV: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Orders'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: searchController,
                    onChanged: searchOrders,
                    decoration: InputDecoration(
                      labelText: 'Search by service name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: filteredOrders.isNotEmpty ? exportToCSV : null,
                  icon: Icon(Icons.download),
                  label: Text('Export CSV'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            // Show total count
            if (!isLoading)
              Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'Total Orders: ${filteredOrders.length}',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            Expanded(
              child: isLoading
                  ? Center(child: CircularProgressIndicator())
                  : filteredOrders.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inbox, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No orders found',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  ],
                ),
              )
                  : ListView.builder(
                itemCount: filteredOrders.length,
                itemBuilder: (context, index) {
                  var order = filteredOrders[index];
                  return Card(
                    margin: EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(
                        order['service'] ?? 'Unknown Service',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 4),
                          Text('Professional: ${order['professional'] ?? 'Unknown'}'),
                          Text('Client: ${order['client'] ?? 'Unknown'}'),
                          Text('Status: ${order['status'] ?? 'Unknown'}'),
                          if (order['price'] != null && order['price'].toString().isNotEmpty)
                            Text('Price: \$${order['price']}'),
                          Text('Date: ${order['createdAt'] ?? 'Unknown'}'),
                          if (order['message'] != null && order['message'].toString().isNotEmpty)
                            Text('Message: ${order['message']}',
                                style: TextStyle(fontStyle: FontStyle.italic)),
                        ],
                      ),
                      trailing: Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusColor(order['status']),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          order['status'] ?? 'Unknown',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      case 'in progress':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}