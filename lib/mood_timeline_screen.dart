import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MoodTimelineScreen extends StatelessWidget {
  final String elderId;
  final String elderName;

  const MoodTimelineScreen({
    super.key,
    required this.elderId,
    required this.elderName,
  });

  Color _moodColor(String mood) {
    switch (mood.toLowerCase()) {
      case 'happy':
        return Colors.green;
      case 'calm':
        return Colors.teal;
      case 'tired':
        return Colors.amber.shade700;
      case 'sad':
        return Colors.red;
      case 'anxious':
        return Colors.orange;
      default:
        return Colors.blueGrey;
    }
  }

  String _dominantMood(Map<String, int> counts) {
    if (counts.isEmpty) return 'unknown';
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('$elderName • Mood Timeline')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(elderId)
            .collection('mood_logs')
            .orderBy('timestamp', descending: true)
            .limit(30)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Failed to load mood timeline: ${snapshot.error}'));
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'No mood history available yet.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          final today = DateTime.now();
          final dayKeys = List.generate(7, (i) {
            final d = DateTime(today.year, today.month, today.day)
                .subtract(Duration(days: 6 - i));
            return DateFormat('yyyy-MM-dd').format(d);
          });

          final perDayMoodCounts = <String, Map<String, int>>{};
          for (final key in dayKeys) {
            perDayMoodCounts[key] = {};
          }

          final recentEvents = <Map<String, dynamic>>[];

          for (final doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final ts = data['timestamp'] as Timestamp?;
            if (ts == null) continue;
            final dt = ts.toDate();
            final mood = (data['mood'] ?? 'unknown').toString().toLowerCase();
            final key = DateFormat('yyyy-MM-dd').format(dt);

            if (perDayMoodCounts.containsKey(key)) {
              perDayMoodCounts[key]![mood] = (perDayMoodCounts[key]![mood] ?? 0) + 1;
            }

            recentEvents.add({
              'mood': mood,
              'snippet': (data['messageSnippet'] ?? '').toString(),
              'timestamp': dt,
            });
          }

          final bars = <BarChartGroupData>[];
          for (int i = 0; i < dayKeys.length; i++) {
            final dayCountMap = perDayMoodCounts[dayKeys[i]]!;
            final dominant = _dominantMood(dayCountMap);
            final total = dayCountMap.values.fold<int>(0, (a, b) => a + b);
            bars.add(
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: total == 0 ? 0.5 : total.toDouble(),
                    color: _moodColor(dominant),
                    width: 18,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            );
          }

          recentEvents.sort(
            (a, b) => (b['timestamp'] as DateTime)
                .compareTo(a['timestamp'] as DateTime),
          );

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Last 7 days mood activity',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 250,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: BarChart(
                    BarChartData(
                      borderData: FlBorderData(show: false),
                      gridData: const FlGridData(show: true),
                      barGroups: bars,
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: true, reservedSize: 28),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 || index >= dayKeys.length) {
                                return const SizedBox.shrink();
                              }
                              final d = DateTime.parse(dayKeys[index]);
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  DateFormat('E').format(d),
                                  style: const TextStyle(fontSize: 11),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                child: Row(
                  children: const [
                    _MoodLegendDot(label: 'Happy', color: Colors.green),
                    SizedBox(width: 8),
                    _MoodLegendDot(label: 'Calm', color: Colors.teal),
                    SizedBox(width: 8),
                    _MoodLegendDot(label: 'Tired', color: Colors.amber),
                    SizedBox(width: 8),
                    _MoodLegendDot(label: 'Sad', color: Colors.red),
                    SizedBox(width: 8),
                    _MoodLegendDot(label: 'Anxious', color: Colors.orange),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(elderId)
                      .collection('wellness_logs')
                      .orderBy('timestamp', descending: true)
                      .limit(7)
                      .get(),
                  builder: (context, wellnessSnapshot) {
                    if (wellnessSnapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox.shrink();
                    }

                    final wDocs = wellnessSnapshot.data?.docs ?? [];
                    if (wDocs.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    final scores = wDocs
                        .map((d) => (d.data() as Map<String, dynamic>)['score'])
                        .whereType<num>()
                        .map((n) => n.toInt())
                        .toList();

                    if (scores.isEmpty) return const SizedBox.shrink();

                    final avg = scores.reduce((a, b) => a + b) / scores.length;

                    Color colorForScore(int score) {
                      if (score >= 7) return Colors.green;
                      if (score >= 4) return Colors.amber.shade700;
                      return Colors.red;
                    }

                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Wellness scores (last 7 days) • Avg ${avg.toStringAsFixed(1)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: scores.map((s) {
                              return Container(
                                width: 30,
                                height: 30,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: colorForScore(s).withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '$s',
                                  style: TextStyle(
                                    color: colorForScore(s),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: recentEvents.length > 5 ? 5 : recentEvents.length,
                  itemBuilder: (context, index) {
                    final event = recentEvents[index];
                    final mood = (event['mood'] as String);
                    final when = event['timestamp'] as DateTime;
                    final snippet = (event['snippet'] as String);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Row(
                          children: [
                            Chip(
                              label: Text(mood),
                              backgroundColor: _moodColor(mood).withOpacity(0.15),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              DateFormat('dd MMM, hh:mm a').format(when),
                              style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          snippet.isEmpty ? 'No snippet available' : snippet,
                        ),
                      ),
                    );
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

class _MoodLegendDot extends StatelessWidget {
  final String label;
  final Color color;

  const _MoodLegendDot({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}
