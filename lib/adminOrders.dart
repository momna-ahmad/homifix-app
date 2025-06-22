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
  String selectedStatus = 'All';

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

      Query query = FirebaseFirestore.instance.collection('orders');

      // Filter by status only if it's not 'All'
      if (selectedStatus != 'All') {
        query = query.where('status', isEqualTo: selectedStatus.toLowerCase());
      }

      QuerySnapshot orderSnapshot = await query.get();

      List<Map<String, dynamic>> tempOrders = [];

      for (var orderDoc in orderSnapshot.docs) {
        var order = orderDoc.data() as Map<String, dynamic>;
        String customerName = 'Unknown';
        String professionalName = 'Unknown';

        // Get customer name
        if (order['customerId'] != null) {
          try {
            DocumentSnapshot customerSnap = await FirebaseFirestore.instance
                .collection('users')
                .doc(order['customerId'])
                .get();

            if (customerSnap.exists) {
              var customerData = customerSnap.data() as Map<String, dynamic>;
              customerName = customerData['name'] ?? 'Unknown';
            }
          } catch (e) {
            customerName = 'Error loading';
          }
        }

        // Get professional name
        if (order['professionalId'] != null) {
          try {
            DocumentSnapshot profSnap = await FirebaseFirestore.instance
                .collection('users')
                .doc(order['professionalId'])
                .get();

            if (profSnap.exists) {
              var profData = profSnap.data() as Map<String, dynamic>;
              professionalName = profData['name'] ?? 'Unknown';
            }
          } catch (e) {
            professionalName = 'Error loading';
          }
        }

        // Parse createdAt timestamp
        String createdAtString = '';
        if (order['createdAt'] != null) {
          if (order['createdAt'] is Timestamp) {
            DateTime dateTime = (order['createdAt'] as Timestamp).toDate();
            createdAtString =
            '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
          } else if (order['createdAt'] is String) {
            createdAtString = order['createdAt'];
          }
        }

        tempOrders.add({
          'id': order['orderId'] ?? orderDoc.id,
          'service': order['category'] ?? '',
          'professional': professionalName,
          'client': customerName,
          'status': order['status'] ?? '',
          'createdAt': createdAtString,
          'price': order['price'] ?? '',
          'message': order['message'] ?? '',
          'address': order['address'] ?? '',
          'phone': order['phone'] ?? '',
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

      String csv = const ListToCsvConverter().convert(csvData);

      if (kIsWeb) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('CSV export on web - please implement web-specific code'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        await _saveCsvToMobile(csv);
      }
    } catch (e) {
      Navigator.of(context).pop();
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
      if (Platform.isAndroid) {
        var status = await Permission.storage.status;
        if (!status.isGranted) {
          status = await Permission.storage.request();
          if (!status.isGranted) {
            Navigator.of(context).pop();
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

      Directory? directory;
      if (Platform.isAndroid) {
        directory = await getExternalStorageDirectory();
      } else if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory != null) {
        String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        String fileName = 'orders_$timestamp.csv';
        String filePath = '${directory.path}/$fileName';

        File file = File(filePath);
        await file.writeAsString(csvContent);

        Navigator.of(context).pop();
        _showExportSuccessDialog(filePath, fileName);
      } else {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not access storage directory'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      Navigator.of(context).pop();
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
                  color: Color(0xFF1A202C),
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
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF22D3EE)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.file_present, color: Color(0xFF22D3EE), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        fileName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF1A202C),
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
                backgroundColor: const Color(0xFF22D3EE),
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
                  text: 'Orders CSV Export',
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
      backgroundColor: const Color(0xFFF7FAFC),
      appBar: AppBar(
        title: const Text(
          'Orders',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
            color: Color(0xFF1A202C),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1A202C)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ElevatedButton.icon(
              onPressed: filteredOrders.isNotEmpty ? exportToCSV : null,
              icon: const Icon(Icons.download, size: 18),
              label: const Text('Export CSV'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22D3EE),
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
          // Stay Organized Card
          Container(
            margin: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF22D3EE),
                  Color(0xFF0EA5E9),
                ],
              ),
              borderRadius: BorderRadius.circular(16.0),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
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
                        const SizedBox(height: 8),
                        const Text(
                          'Manage your Orders',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.calendar_today,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Search Bar and Stats
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Search Bar
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(color: const Color(0xFF67E8F9)),
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
                        color: Color(0xFF22D3EE),
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
                      color: Color(0xFF1A202C),
                    ),
                  ),
                ),

                // Stats Row
                if (!isLoading)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Row(
                      children: [
                        _buildStatCard(
                          'Total',
                          filteredOrders.length.toString(),
                          const Color(0xFF22D3EE),
                          Icons.receipt_long,
                        ),
                        const SizedBox(width: 8),
                        _buildStatCard(
                          'Complete',
                          filteredOrders.where((o) => o['status']?.toLowerCase() == 'completed').length.toString(),
                          const Color(0xFF059669),
                          Icons.check_circle,
                        ),
                        const SizedBox(width: 8),
                        _buildStatCard(
                          'Assigned',
                          filteredOrders.where((o) => o['status']?.toLowerCase() == 'assigned').length.toString(),
                          const Color(0xFF7C3AED),
                          Icons.assignment,
                        ),
                        const SizedBox(width: 8),
                        _buildStatCard(
                          'waiting',
                          filteredOrders.where((o) => o['status']?.toLowerCase() == 'waiting').length.toString(),
                          const Color(0xFFD97706),
                          Icons.pending,
                        ),
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
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF22D3EE)),
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

  Widget _buildStatCard(String title, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: color,
              size: 20,
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
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
                      color: Color(0xFF1A202C),
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
                      'Rs. ${order['price']}',
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
                  color: Color(0xFF1A202C),
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
        return const Color(0xFF059669);
      case 'assigned':
        return const Color(0xFF7C3AED);
      case 'pending':
        return const Color(0xFFD97706);
      case 'cancelled':
        return const Color(0xFFDC2626);
      case 'in progress':
        return const Color(0xFF22D3EE);
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