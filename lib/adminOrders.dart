import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';

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

      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('orders')
          .orderBy('createdAt', descending: true)
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
            DateTime dateTime = data['createdAt'].toDate();
            createdAtString = '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
          } else if (data['createdAt'] is String) {
            createdAtString = data['createdAt'];
          }
        }

        tempOrders.add({
          'id': doc.id,
          'service': data['category'] ?? '',
          'professional': professionalName,
          'client': customerName,
          'status': data['status'] ?? '',
          'createdAt': createdAtString,
          'price': data['price'] ?? '',
          'message': data['message'] ?? '',
          'address': data['address'] ?? '',
          'phone': data['phone'] ?? '',
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
      filteredOrders = orders.where((order) {
        return order['service'].toString().toLowerCase().contains(query.toLowerCase()) ||
            order['professional'].toString().toLowerCase().contains(query.toLowerCase()) ||
            order['client'].toString().toLowerCase().contains(query.toLowerCase()) ||
            order['status'].toString().toLowerCase().contains(query.toLowerCase());
      }).toList();
    });
  }

  Future<void> exportToCSV() async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text("Preparing CSV file..."),
              ],
            ),
          );
        },
      );

      // Prepare CSV data
      List<List<String>> csvData = [
        ['Order ID', 'Service', 'Professional', 'Client', 'Status', 'Date', 'Price', 'Address', 'Phone', 'Message']
      ];

      for (var order in filteredOrders) {
        csvData.add([
          order['id']?.toString() ?? '',
          order['service']?.toString() ?? '',
          order['professional']?.toString() ?? '',
          order['client']?.toString() ?? '',
          order['status']?.toString() ?? '',
          order['createdAt']?.toString() ?? '',
          order['price']?.toString() ?? '',
          order['address']?.toString() ?? '',
          order['phone']?.toString() ?? '',
          order['message']?.toString() ?? '',
        ]);
      }

      // Convert to CSV string
      String csv = const ListToCsvConverter().convert(csvData);

      if (kIsWeb) {
        // Web implementation (if needed)
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('CSV export on web - please implement web-specific code'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        // Mobile implementation
        await _saveCsvToMobile(csv);
      }
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      print('Error exporting CSV: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error exporting CSV: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveCsvToMobile(String csvContent) async {
    try {
      // Request storage permission for Android
      if (Platform.isAndroid) {
        var status = await Permission.storage.status;
        if (!status.isGranted) {
          status = await Permission.storage.request();
          if (!status.isGranted) {
            Navigator.of(context).pop(); // Close loading dialog
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Storage permission is required to save CSV file'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }
        }
      }

      // Get the directory to save the file
      Directory? directory;
      if (Platform.isAndroid) {
        directory = await getExternalStorageDirectory();
      } else if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory != null) {
        // Create filename with timestamp
        String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        String fileName = 'admin_orders_$timestamp.csv';
        String filePath = '${directory.path}/$fileName';

        // Write CSV content to file
        File file = File(filePath);
        await file.writeAsString(csvContent);

        Navigator.of(context).pop(); // Close loading dialog

        // Show options dialog
        _showExportSuccessDialog(filePath, fileName);
      } else {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not access storage directory'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      print('Error saving CSV to mobile: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving CSV: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showExportSuccessDialog(String filePath, String fileName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 12),
              Text(
                'Export Successful',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2D3748),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CSV file has been saved successfully!',
                style: const TextStyle(
                  color: Color(0xFF4A5568),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.file_present, color: Color(0xFF4299E1), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        fileName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF2D3748),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Close',
                style: TextStyle(
                  color: Color(0xFF718096),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4299E1),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () async {
                Navigator.of(context).pop();
                await Share.shareXFiles(
                  [XFile(filePath)],
                  text: 'Admin Orders CSV Export',
                );
              },
              icon: const Icon(Icons.share, size: 18),
              label: const Text(
                'Share',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Admin Orders',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
            color: Color(0xFF2D3748),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF2D3748)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ElevatedButton.icon(
              onPressed: filteredOrders.isNotEmpty ? exportToCSV : null,
              icon: const Icon(Icons.download, size: 18),
              label: const Text('Export CSV'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF38A169),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: const Color(0xFFE2E8F0),
          ),
        ),
      ),
      body: Column(
        children: [
          // Search Bar and Stats
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Search Bar
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7FAFC),
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: TextField(
                    controller: searchController,
                    onChanged: searchOrders,
                    decoration: InputDecoration(
                      hintText: 'Search by service, professional, client, or status',
                      hintStyle: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 16,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Color(0xFF4299E1),
                        size: 22,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 16.0,
                      ),
                    ),
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                ),

                // Stats Row
                if (!isLoading)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Row(
                      children: [
                        _buildStatCard('Total Orders', filteredOrders.length.toString(), Colors.blue),
                        const SizedBox(width: 12),
                        _buildStatCard('Completed',
                            filteredOrders.where((o) => o['status']?.toLowerCase() == 'completed').length.toString(),
                            Colors.green),
                        const SizedBox(width: 12),
                        _buildStatCard('Pending',
                            filteredOrders.where((o) => o['status']?.toLowerCase() == 'pending').length.toString(),
                            Colors.orange),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Orders List
          Expanded(
            child: isLoading
                ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4299E1)),
              ),
            )
                : filteredOrders.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    searchController.text.isNotEmpty
                        ? 'No orders found matching "${searchController.text}"'
                        : 'No orders found',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF718096),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: filteredOrders.length,
              itemBuilder: (context, index) {
                var order = filteredOrders[index];
                return _buildOrderCard(order);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    order['service'] ?? 'Unknown Service',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(order['status']),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    order['status'] ?? 'Unknown',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Details Grid
            Row(
              children: [
                Expanded(
                  child: _buildDetailItem(
                    Icons.person_outline,
                    'Professional',
                    order['professional'] ?? 'Unknown',
                  ),
                ),
                Expanded(
                  child: _buildDetailItem(
                    Icons.account_circle_outlined,
                    'Client',
                    order['client'] ?? 'Unknown',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildDetailItem(
                    Icons.access_time,
                    'Date',
                    order['createdAt'] ?? 'Unknown',
                  ),
                ),
                if (order['price'] != null && order['price'].toString().isNotEmpty)
                  Expanded(
                    child: _buildDetailItem(
                      Icons.attach_money,
                      'Price',
                      '\$${order['price']}',
                    ),
                  ),
              ],
            ),

            if (order['address'] != null && order['address'].toString().isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildDetailItem(
                Icons.location_on_outlined,
                'Address',
                order['address'],
              ),
            ],

            if (order['phone'] != null && order['phone'].toString().isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildDetailItem(
                Icons.phone_outlined,
                'Phone',
                order['phone'],
              ),
            ],

            if (order['message'] != null && order['message'].toString().isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildDetailItem(
                Icons.message_outlined,
                'Message',
                order['message'],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: const Color(0xFF718096),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF718096),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF2D3748),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
        return const Color(0xFF38A169);
      case 'pending':
        return const Color(0xFFED8936);
      case 'cancelled':
        return const Color(0xFFE53E3E);
      case 'in progress':
        return const Color(0xFF4299E1);
      default:
        return const Color(0xFF718096);
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }
}