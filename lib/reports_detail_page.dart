import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ReportsDetailPage extends StatefulWidget {
  final String userId;
  final String professionalName;

  const ReportsDetailPage({
    super.key,
    required this.userId,
    required this.professionalName,
  });

  @override
  State<ReportsDetailPage> createState() => _ReportsDetailPageState();
}

class _ReportsDetailPageState extends State<ReportsDetailPage> {
  String? _selectedWarning;

  // Predefined warning messages
  final List<String> _warningMessages = [
    'Please maintain professional behavior with clients',
    'Your service quality needs improvement',
    'Multiple complaints received about delayed responses',
    'Inappropriate communication reported',
    'Service delivery standards not met',
    'Please follow platform guidelines',
    'Customer satisfaction scores are low',
    'Unprofessional conduct reported',
    'Service cancellation without proper notice',
    'Pricing disputes with customers',
  ];

  Stream<QuerySnapshot> _getReportsStream() {
    return FirebaseFirestore.instance
        .collection('reports')
        .where('reportedProfessionalId', isEqualTo: widget.userId) // Changed from 'reportedUserId'
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  String _formatTimestamp(dynamic timestamp) {
    try {
      DateTime dateTime;
      if (timestamp is Timestamp) {
        dateTime = timestamp.toDate();
      } else if (timestamp is int) {
        dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      } else if (timestamp is String) {
        // Handle string timestamps like "2025-06-29T15:33:38.051132"
        dateTime = DateTime.parse(timestamp);
      } else {
        return 'Unknown date';
      }
      return DateFormat('MMM dd, yyyy • hh:mm a').format(dateTime);
    } catch (e) {
      return 'Invalid date';
    }
  }

  // Send warning dialog with predefined messages
  void _showSendWarningDialog(String reportId) {
    _selectedWarning = null;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'Send Warning to ${widget.professionalName}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A202C),
                ),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select a warning message:',
                      style: TextStyle(
                        color: Color(0xFF4A5568),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 300,
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.builder(
                        itemCount: _warningMessages.length,
                        itemBuilder: (context, index) {
                          final message = _warningMessages[index];
                          final isSelected = _selectedWarning == message;

                          return ListTile(
                            title: Text(
                              message,
                              style: TextStyle(
                                fontSize: 14,
                                color: isSelected ? const Color(0xFF22D3EE) : const Color(0xFF4A5568),
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                            leading: Radio<String>(
                              value: message,
                              groupValue: _selectedWarning,
                              onChanged: (String? value) {
                                setState(() {
                                  _selectedWarning = value;
                                });
                              },
                              activeColor: const Color(0xFF22D3EE),
                            ),
                            onTap: () {
                              setState(() {
                                _selectedWarning = message;
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: Color(0xFF718096),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _selectedWarning != null
                      ? () => _sendWarning(reportId)
                      : null,
                  child: const Text(
                    'Send Warning',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Send warning function
  void _sendWarning(String reportId) async {
    if (_selectedWarning == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a warning message'),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
      return;
    }

    try {
      final warningData = {
        'message': _selectedWarning!,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'sentBy': 'admin', // You can pass admin ID if needed
        'reportId': reportId,
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({
        'warnings': FieldValue.arrayUnion([warningData]),
      });

      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Warning sent to ${widget.professionalName}'),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending warning: $e'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }

  Widget _buildReportCard(Map<String, dynamic> reportData, String reportId) {
    // Updated field names to match your Firestore structure
    final reportedReason = reportData['reportReason']?.toString() ?? 'No reason provided'; // Changed from 'reportedreason'
    final reporterName = reportData['customerName']?.toString() ?? 'Anonymous'; // Changed from 'reporterName'
    final timestamp = reportData['timestamp'] ?? reportData['createdAt']; // Try both timestamp fields
    final additionalDetails = reportData['additionalDetails']?.toString();
    final customerId = reportData['customerId']?.toString() ?? '';
    final reportedProfessionalName = reportData['reportedProfessionalName']?.toString() ?? '';

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
            // Header with timestamp only
            Row(
              children: [
                const Spacer(),
                Text(
                  _formatTimestamp(timestamp),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Report reason
            Text(
              'Report Reason',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              reportedReason,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF1F2937),
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 12),

            // Reporter info
            Row(
              children: [
                const Icon(
                  Icons.person_outline,
                  size: 16,
                  color: Color(0xFF6B7280),
                ),
                const SizedBox(width: 4),
                Text(
                  'Reported by: $reporterName',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),

            // Professional info (if different from the one being viewed)
            if (reportedProfessionalName.isNotEmpty && reportedProfessionalName != widget.professionalName) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.work_outline,
                    size: 16,
                    color: Color(0xFF6B7280),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Professional: $reportedProfessionalName',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],

            // Additional details if available
            if (additionalDetails != null && additionalDetails.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Additional Details',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                additionalDetails,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],

            // Customer ID (for debugging/admin purposes)
            if (customerId.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Customer ID: ${customerId.substring(0, 8)}...',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF9CA3AF),
                  fontFamily: 'monospace',
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Send Warning Button for each report
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => _showSendWarningDialog(reportId),
                child: const Text(
                  'Send Warning for this Report',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard(int totalReports, int resolvedReports, int pendingReports) {
    return Container(
      margin: const EdgeInsets.all(16.0),
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFDC2626).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reports for ${widget.professionalName}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Total reports overview',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.report_problem,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '$totalReports',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Total Reports',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFC),
      appBar: AppBar(
        title: Text(
          'Reports - ${widget.professionalName}',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: Color(0xFF1A202C),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1A202C)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: const Color(0xFFE2E8F0),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getReportsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFDC2626)),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading reports: ${snapshot.error}',
                    style: const TextStyle(fontSize: 16, color: Color(0xFF718096)),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.report_off, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text(
                    'No reports found for this professional',
                    style: TextStyle(fontSize: 16, color: Color(0xFF718096)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Professional ID: ${widget.userId}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                  ),
                ],
              ),
            );
          }

          final reports = snapshot.data!.docs;
          final totalReports = reports.length;
          final resolvedReports = reports.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['status']?.toString().toLowerCase() == 'resolved';
          }).length;
          final pendingReports = totalReports - resolvedReports;

          return Column(
            children: [
              // Stats Card - simplified to show only total reports
              _buildStatsCard(totalReports, resolvedReports, pendingReports),

              // Reports List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemCount: reports.length,
                  itemBuilder: (context, index) {
                    final report = reports[index];
                    final reportData = report.data() as Map<String, dynamic>;
                    return _buildReportCard(reportData, report.id);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
