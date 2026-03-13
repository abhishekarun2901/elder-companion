// lib/health_vitals_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'log_vitals_screen.dart';

// Data model for a vital
class Vital {
  final String title;
  final String unit;
  final String value;
  final String status;
  final Color color;
  final DateTime timestamp;
  final String documentId;

  Vital({
    required this.title,
    required this.unit,
    required this.value,
    required this.status,
    required this.color,
    required this.timestamp,
    required this.documentId,
  });

  // Convert Firestore document to Vital object
  factory Vital.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Vital(
      title: data['title'] ?? 'Unknown',
      unit: data['unit'] ?? '',
      value: data['value'] ?? '0',
      status: data['status'] ?? 'Normal',
      color: _getColorForStatus(data['status'] ?? 'Normal'),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      documentId: doc.id,
    );
  }

  static Color _getColorForStatus(String status) {
    switch (status) {
      case 'High':
        return Colors.red;
      case 'Low':
        return Colors.orange;
      case 'Critical':
        return Colors.red.shade900;
      default:
        return Colors.green;
    }
  }
}

// Main vitals screen
class HealthVitalsScreen extends StatefulWidget {
  final String elderName;
  final String? elderId; // ID of the elder (if being viewed by caregiver)

  const HealthVitalsScreen({super.key, required this.elderName, this.elderId});

  @override
  State<HealthVitalsScreen> createState() => _HealthVitalsScreenState();
}

class _HealthVitalsScreenState extends State<HealthVitalsScreen> {
  late Future<List<Vital>> _vitalsFuture;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final List<_VitalChartConfig> _chartConfigs = const [
    _VitalChartConfig(
      vitalType: 'Heart Rate',
      unit: 'BPM',
      normalMin: 60,
      normalMax: 100,
      showBand: true,
    ),
    _VitalChartConfig(
      vitalType: 'Blood Pressure',
      unit: 'mmHg',
      normalMin: 90,
      normalMax: 120,
      showBand: true,
    ),
    _VitalChartConfig(
      vitalType: 'Blood Oxygen',
      unit: '%',
      normalMin: 95,
      normalMax: 100,
      showBand: true,
    ),
    _VitalChartConfig(
      vitalType: 'Blood Glucose',
      unit: 'mg/dL',
      normalMin: 70,
      normalMax: 140,
      showBand: true,
    ),
    _VitalChartConfig(
      vitalType: 'Steps Count',
      unit: 'steps',
      normalMin: 0,
      normalMax: 0,
      showBand: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _vitalsFuture = _fetchLatestVitals();
  }

  String get _targetUserId {
    // If elderId is provided, use it. Otherwise use current user's ID.
    return widget.elderId ?? _auth.currentUser?.uid ?? '';
  }

  // Fetch the latest vital for each type from Firestore
  Future<List<Vital>> _fetchLatestVitals() async {
    final uid = _targetUserId;
    if (uid.isEmpty) {
      throw Exception('User not identified');
    }

    final vitalTypes = [
      'Heart Rate',
      'Blood Pressure',
      'Blood Oxygen',
      'Blood Glucose',
      'Steps Count',
    ];

    final List<Future<QuerySnapshot>> futures = [];

    for (var type in vitalTypes) {
      futures.add(
        _firestore
            .collection('users')
            .doc(uid)
            .collection('health_vitals')
            .where('title', isEqualTo: type)
            .orderBy('timestamp', descending: true)
            .limit(1)
            .get(),
      );
    }

    final List<QuerySnapshot> results = await Future.wait(futures);
    final List<Vital> vitals = [];

    for (var snapshot in results) {
      if (snapshot.docs.isNotEmpty) {
        vitals.add(Vital.fromFirestore(snapshot.docs.first));
      }
    }

    return vitals;
  }

  // Delete a vital record
  Future<void> _deleteVital(String documentId) async {
    final uid = _targetUserId;
    if (uid.isEmpty) return;

    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('health_vitals')
          .doc(documentId)
          .delete();

      setState(() {
        _vitalsFuture = _fetchLatestVitals();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vital record deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete vital: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Show history of a specific vital type
  void _showVitalHistory(String vitalType) {
    final uid = _targetUserId;
    if (uid.isEmpty) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('History - $vitalType'),
          content: SizedBox(
            width: double.maxFinite,
            child: FutureBuilder<QuerySnapshot>(
              future: _firestore
                  .collection('users')
                  .doc(uid)
                  .collection('health_vitals')
                  .where('title', isEqualTo: vitalType)
                  .orderBy('timestamp', descending: true)
                  .limit(10)
                  .get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No history available'));
                }

                final docs = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final timestamp = (data['timestamp'] as Timestamp?)
                        ?.toDate();
                    final formattedTime = timestamp != null
                        ? '${timestamp.day}/${timestamp.month}/${timestamp.year} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}'
                        : 'Unknown';

                    return ListTile(
                      title: Text('${data['value']} ${data['unit']}'),
                      subtitle: Text(formattedTime),
                      trailing: Text(
                        data['status'] ?? 'Normal',
                        style: TextStyle(
                          color: Vital._getColorForStatus(
                            data['status'] ?? 'Normal',
                          ),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Vitals'),
        backgroundColor: Colors.redAccent[700],
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _vitalsFuture = _fetchLatestVitals();
              });
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Current Health Metrics',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey,
              ),
            ),
            const SizedBox(height: 10),
            FutureBuilder<List<Vital>>(
              future: _vitalsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text(
                      'No vitals logged yet.\nTap "Manually Log Vitals" to start.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  );
                }

                final vitals = snapshot.data!;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10.0,
                    mainAxisSpacing: 10.0,
                    childAspectRatio: 1.2,
                  ),
                  itemCount: vitals.length,
                  itemBuilder: (context, index) {
                    return VitalCard(
                      vital: vitals[index],
                      onDelete: () => _deleteVital(vitals[index].documentId),
                      onViewHistory: () =>
                          _showVitalHistory(vitals[index].title),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 30),
            const Text(
              'Vitals History & Trends',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey,
              ),
            ),
            const SizedBox(height: 10),
            DefaultTabController(
              length: _chartConfigs.length,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    TabBar(
                      isScrollable: true,
                      labelColor: Colors.teal.shade700,
                      unselectedLabelColor: Colors.grey.shade600,
                      indicatorColor: Colors.teal,
                      tabs: _chartConfigs
                          .map((cfg) => Tab(text: cfg.vitalType))
                          .toList(),
                    ),
                    SizedBox(
                      height: 280,
                      child: TabBarView(
                        children: _chartConfigs
                            .map(
                              (cfg) => Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: VitalChartWidget(
                                  vitalType: cfg.vitalType,
                                  targetUserId: _targetUserId,
                                  unit: cfg.unit,
                                  normalMin: cfg.normalMin,
                                  normalMax: cfg.normalMax,
                                  showBand: cfg.showBand,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LogVitalsScreen(),
                  ),
                );
                setState(() {
                  _vitalsFuture = _fetchLatestVitals();
                });
              },
              icon: const Icon(Icons.add_circle, color: Colors.white),
              label: const Text(
                'Manually Log Vitals',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade600,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VitalChartConfig {
  final String vitalType;
  final String unit;
  final double normalMin;
  final double normalMax;
  final bool showBand;

  const _VitalChartConfig({
    required this.vitalType,
    required this.unit,
    required this.normalMin,
    required this.normalMax,
    required this.showBand,
  });
}

class VitalChartWidget extends StatefulWidget {
  final String vitalType;
  final String targetUserId;
  final String unit;
  final double normalMin;
  final double normalMax;
  final bool showBand;

  const VitalChartWidget({
    super.key,
    required this.vitalType,
    required this.targetUserId,
    required this.unit,
    required this.normalMin,
    required this.normalMax,
    required this.showBand,
  });

  @override
  State<VitalChartWidget> createState() => _VitalChartWidgetState();
}

class _VitalChartWidgetState extends State<VitalChartWidget> {
  bool _loading = true;
  List<_ChartReading> _readings = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant VitalChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.vitalType != widget.vitalType ||
        oldWidget.targetUserId != widget.targetUserId) {
      _load();
    }
  }

  double? _parseValue(String value) {
    final raw = value.trim();
    if (widget.vitalType == 'Blood Pressure') {
      final parts = raw.split('/');
      if (parts.isNotEmpty) {
        return double.tryParse(parts.first.trim());
      }
    }

    final cleaned = raw.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(cleaned);
  }

  Future<void> _load() async {
    if (widget.targetUserId.isEmpty) {
      if (mounted) {
        setState(() {
          _loading = false;
          _readings = [];
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _loading = true;
      });
    }

    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.targetUserId)
          .collection('health_vitals')
          .where('title', isEqualTo: widget.vitalType)
          .orderBy('timestamp', descending: true)
          .limit(30)
          .get();

      final rows = <_ChartReading>[];
      for (final d in query.docs) {
        final data = d.data();
        final ts = (data['timestamp'] as Timestamp?)?.toDate();
        if (ts == null) continue;

        final parsed = _parseValue((data['value'] ?? '').toString());
        if (parsed == null) continue;

        rows.add(_ChartReading(time: ts, value: parsed));
      }

      rows.sort((a, b) => a.time.compareTo(b.time));

      if (mounted) {
        setState(() {
          _readings = rows;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _readings = [];
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_readings.length < 2) {
      return const Center(
        child: Text(
          'Not enough data points for trend chart.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final earliest = _readings.first.time;
    final spots = _readings.map((r) {
      final x = r.time.difference(earliest).inHours / 24.0;
      return FlSpot(x, r.value);
    }).toList();

    final minYValue = _readings
        .map((e) => e.value)
        .reduce((a, b) => a < b ? a : b);
    final maxYValue = _readings
        .map((e) => e.value)
        .reduce((a, b) => a > b ? a : b);

    final minY = widget.showBand
        ? (minYValue < widget.normalMin ? minYValue - 5 : widget.normalMin - 5)
        : (minYValue - 5);
    final maxY = widget.showBand
        ? (maxYValue > widget.normalMax ? maxYValue + 5 : widget.normalMax + 5)
        : (maxYValue + 5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${widget.vitalType} (${widget.unit})',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: LineChart(
            LineChartData(
              minY: minY,
              maxY: maxY,
              lineTouchData: const LineTouchData(enabled: true),
              gridData: FlGridData(show: true, drawVerticalLine: false),
              borderData: FlBorderData(
                show: true,
                border: Border.all(color: Colors.grey.shade300),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: true, reservedSize: 42),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: (spots.last.x / 3).clamp(1, 10).toDouble(),
                    getTitlesWidget: (value, meta) {
                      final date = earliest.add(
                        Duration(hours: (value * 24).round()),
                      );
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${date.day}/${date.month}',
                          style: const TextStyle(fontSize: 10),
                        ),
                      );
                    },
                  ),
                ),
              ),
              rangeAnnotations: widget.showBand
                  ? RangeAnnotations(
                      horizontalRangeAnnotations: [
                        HorizontalRangeAnnotation(
                          y1: widget.normalMin,
                          y2: widget.normalMax,
                          color: Colors.green.withOpacity(0.12),
                        ),
                      ],
                    )
                  : const RangeAnnotations(),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  barWidth: 3,
                  color: Colors.teal,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      final outside = widget.showBand &&
                          (spot.y < widget.normalMin || spot.y > widget.normalMax);
                      return FlDotCirclePainter(
                        radius: 3.5,
                        color: outside ? Colors.red : Colors.teal,
                        strokeWidth: 1,
                        strokeColor: Colors.white,
                      );
                    },
                  ),
                  belowBarData: BarAreaData(show: false),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ChartReading {
  final DateTime time;
  final double value;

  const _ChartReading({required this.time, required this.value});
}

// Vital card widget with swipe to delete and history view
class VitalCard extends StatelessWidget {
  final Vital vital;
  final VoidCallback onDelete;
  final VoidCallback onViewHistory;

  const VitalCard({
    super.key,
    required this.vital,
    required this.onDelete,
    required this.onViewHistory,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () {
        _showVitalOptions(context);
      },
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: vital.color, width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    _getIconForVital(vital.title),
                    color: vital.color.withOpacity(0.8),
                    size: 28,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      vital.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey.shade800,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: vital.value,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: vital.color.withOpacity(0.9),
                        ),
                      ),
                      TextSpan(
                        text: ' ${vital.unit}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: vital.color.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: vital.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      vital.status,
                      style: TextStyle(
                        color: vital.color.withOpacity(0.8),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Text(
                    _formatTime(vital.timestamp),
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showVitalOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.history, color: Colors.blue),
                title: const Text('View History'),
                onTap: () {
                  Navigator.pop(context);
                  onViewHistory();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete Record'),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirmation(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Record?'),
          content: Text(
            'Are you sure you want to delete this ${vital.title} record?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                onDelete();
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final vitalDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (vitalDate == today) {
      return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (vitalDate == yesterday) {
      return 'Yesterday';
    } else {
      return '${vitalDate.day}/${vitalDate.month}';
    }
  }

  IconData _getIconForVital(String title) {
    switch (title) {
      case 'Heart Rate':
        return Icons.favorite;
      case 'Blood Pressure':
        return Icons.compress;
      case 'Blood Oxygen':
        return Icons.opacity;
      case 'Blood Glucose':
        return Icons.water_drop;
      case 'Steps Count':
        return Icons.directions_walk;
      default:
        return Icons.health_and_safety;
    }
  }
}
