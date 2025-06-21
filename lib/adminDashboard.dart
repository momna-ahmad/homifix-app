import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:home_services_app/login.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

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

class _AdminDashboardState extends State<AdminDashboard>
    with TickerProviderStateMixin {
  int professionalCount = 0;
  int customerCount = 0;
  bool isLoading = true;
  Map<String, int> customerGrowthByMonth = {};
  Map<String, int> professionalGrowthByMonth = {};

  // Animation controllers - initialized as nullable first
  AnimationController? _fadeController;
  AnimationController? _slideController;
  Animation<double>? _fadeAnimation;
  Animation<Offset>? _slideAnimation;

  // Modern color palette
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color primaryPurple = Color(0xFF7C3AED);
  static const Color successGreen = Color(0xFF10B981);
  static const Color warningOrange = Color(0xFFF59E0B);
  static const Color errorRed = Color(0xFFEF4444);
  static const Color lightGray = Color(0xFFF0F9FF); // Using the background color from user
  static const Color darkGray = Color(0xFF64748B);
  static const Color cardBackground = Color(0xFFFFFFFF);

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    fetchCounts();
  }

  void _initializeAnimations() {
    // Initialize animations
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController!,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController!,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _fadeController?.dispose();
    _slideController?.dispose();
    super.dispose();
  }

  Future<void> fetchCounts() async {
    try {
      final usersCollection = FirebaseFirestore.instance.collection('users');
      final professionals = await usersCollection.where('role', isEqualTo: 'Professional').get();
      final customers = await usersCollection.where('role', isEqualTo: 'Client').get();
      final now = DateTime.now();

      Map<String, int> growth = {};
      for (int i = 0; i < 6; i++) {
        final date = DateTime(now.year, now.month - i);
        final monthKey = DateFormat('yyyy-MM').format(date);
        growth[monthKey] = 0;
      }

      for (var doc in customers.docs) {
        final timestamp = doc.data()['createdAt'];
        if (timestamp is Timestamp) {
          final date = timestamp.toDate();
          final month = DateFormat('yyyy-MM').format(date);
          if (growth.containsKey(month)) growth[month] = (growth[month] ?? 0) + 1;
        }
      }

      for (var doc in professionals.docs) {
        final timestamp = doc.data()['createdAt'];
        if (timestamp is Timestamp) {
          final date = timestamp.toDate();
          final month = DateFormat('yyyy-MM').format(date);
          if (growth.containsKey(month)) growth[month] = (growth[month] ?? 0) + 1;
        }
      }

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
                break;
              } else if (app['status'] == 'accepted') {
                accepted++;
                break;
              }
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          professionalCount = professionals.docs.length;
          customerCount = customers.docs.length;
          pendingOrders = pending;
          completedOrders = accepted;
          customerGrowthByMonth = growth;
          professionalGrowthByMonth = growth;
          isLoading = false;
        });

        // Start animations after data is loaded and widget is mounted
        _fadeController?.forward();
        _slideController?.forward();
      }
    } catch (e) {
      print('Error fetching data: $e');
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightGray,
      appBar: AppBar(
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: primaryBlue,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.logout, color: Colors.white, size: 20),
              ),
              tooltip: 'Logout',
              onPressed: () => logoutUser(context),
            ),
          ),
        ],
      ),
      body: isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
              strokeWidth: 3,
            ),
            const SizedBox(height: 16),
            Text(
              'Loading dashboard...',
              style: TextStyle(
                color: darkGray,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      )
          : _buildDashboardContent(),
    );
  }

  Widget _buildDashboardContent() {
    // Check if animations are initialized before using them
    if (_fadeAnimation == null || _slideAnimation == null) {
      return _buildStaticContent();
    }

    return FadeTransition(
      opacity: _fadeAnimation!,
      child: SlideTransition(
        position: _slideAnimation!,
        child: _buildStaticContent(),
      ),
    );
  }

  Widget _buildStaticContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Overview',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 16),
          // Fixed GridView with proper aspect ratio
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.1, // Increased aspect ratio to give more height
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              buildStatCard('Professionals', professionalCount, primaryPurple, Icons.work),
              buildStatCard('Clients', customerCount, primaryBlue, Icons.people),
              buildStatCard('Pending Orders', pendingOrders, warningOrange, Icons.pending_actions),
              buildStatCard('Completed Orders', completedOrders, successGreen, Icons.check_circle),
            ],
          ),
          const SizedBox(height: 32),
          const Text(
            'Analytics',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 16),
          buildOrderStatusChart(),
          const SizedBox(height: 24),
          buildGrowthChart('Customer Growth (Last 6 Months)', customerGrowthByMonth, primaryBlue),
          const SizedBox(height: 24),
          buildGrowthChart('Professional Growth (Last 6 Months)', professionalGrowthByMonth, primaryPurple),
        ],
      ),
    );
  }

  Widget buildStatCard(String title, int count, Color color, IconData icon) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 800 + (count % 4) * 200),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color,
                  color.withOpacity(0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16), // Reduced padding
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min, // Important: minimize the column size
                children: [
                  Container(
                    padding: const EdgeInsets.all(8), // Reduced padding
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      icon,
                      color: Colors.white,
                      size: 20, // Reduced icon size
                    ),
                  ),
                  const SizedBox(height: 8), // Reduced spacing
                  Flexible( // Use Flexible to prevent overflow
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12, // Reduced font size
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2, // Allow text to wrap
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 4), // Reduced spacing
                  TweenAnimationBuilder<int>(
                    duration: const Duration(milliseconds: 1500),
                    tween: IntTween(begin: 0, end: count),
                    builder: (context, value, child) {
                      return Text(
                        '$value',
                        style: const TextStyle(
                          fontSize: 24, // Reduced font size
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget buildOrderStatusChart() {
    return Container(
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.pie_chart,
                    color: primaryBlue,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  "Order Status",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Made the pie chart smaller
            SizedBox(
              height: 180, // Reduced from 250
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 1200),
                tween: Tween(begin: 0.0, end: 1.0),
                curve: Curves.easeInOutCubic,
                builder: (context, value, child) {
                  return PieChart(
                    PieChartData(
                      sectionsSpace: 3,
                      centerSpaceRadius: 40, // Reduced from 60
                      startDegreeOffset: -90,
                      sections: [
                        PieChartSectionData(
                          color: warningOrange,
                          value: (pendingOrders.toDouble() * value),
                          title: pendingOrders > 0 ? '${(pendingOrders * value).round()}' : '0',
                          radius: 45 + (15 * value), // Reduced radius
                          titleStyle: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        PieChartSectionData(
                          color: successGreen,
                          value: (completedOrders.toDouble() * value),
                          title: completedOrders > 0 ? '${(completedOrders * value).round()}' : '0',
                          radius: 45 + (15 * value), // Reduced radius
                          titleStyle: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildLegendItem('Pending', warningOrange, pendingOrders),
                _buildLegendItem('Completed', successGreen, completedOrders),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, int value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(5),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$label ($value)',
          style: TextStyle(
            color: darkGray,
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget buildGrowthChart(String title, Map<String, int> growthData, Color color) {
    final sortedKeys = growthData.keys.toList()..sort();
    final spots = List.generate(sortedKeys.length, (index) {
      final month = sortedKeys[index];
      return FlSpot(index.toDouble(), growthData[month]!.toDouble());
    });

    return Container(
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.trending_up,
                    color: color,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 1500),
                tween: Tween(begin: 0.0, end: 1.0),
                curve: Curves.easeInOutCubic,
                builder: (context, value, child) {
                  final animatedSpots = spots.map((spot) {
                    return FlSpot(spot.x, spot.y * value);
                  }).toList();

                  return LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 1,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: Colors.grey.withOpacity(0.2),
                            strokeWidth: 1,
                          );
                        },
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 35,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                value.toInt().toString(),
                                style: TextStyle(
                                  color: darkGray,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 25,
                            getTitlesWidget: (value, meta) {
                              int index = value.toInt();
                              if (index >= 0 && index < sortedKeys.length) {
                                final fullMonth = DateFormat('MMM')
                                    .format(DateTime.parse("${sortedKeys[index]}-01"));
                                return Text(
                                  fullMonth,
                                  style: TextStyle(
                                    color: darkGray,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                );
                              }
                              return const SizedBox();
                            },
                          ),
                        ),
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: animatedSpots,
                          isCurved: true,
                          curveSmoothness: 0.3,
                          barWidth: 3,
                          gradient: LinearGradient(
                            colors: [
                              color,
                              color.withOpacity(0.7),
                            ],
                          ),
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) {
                              return FlDotCirclePainter(
                                radius: 4,
                                color: Colors.white,
                                strokeWidth: 2,
                                strokeColor: color,
                              );
                            },
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                color.withOpacity(0.3),
                                color.withOpacity(0.05),
                              ],
                            ),
                          ),
                        ),
                      ],
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
}