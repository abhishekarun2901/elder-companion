import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CaregiverAdherenceScreen extends StatefulWidget {
  final String elderId;
  final String elderName;

  const CaregiverAdherenceScreen({
    super.key,
    required this.elderId,
    required this.elderName,
  });

  @override
  State<CaregiverAdherenceScreen> createState() =>
      _CaregiverAdherenceScreenState();
}

class _CaregiverAdherenceScreenState extends State<CaregiverAdherenceScreen> {
  late Future<_AdherenceReport> _reportFuture;

  @override
  void initState() {
    super.initState();
    _reportFuture = _loadReport();
  }

  Future<_AdherenceReport> _loadReport() async {
    final medsSnapshot = await FirebaseFirestore.instance
        .collection('medicines')
        .where('elderId', isEqualTo: widget.elderId)
        .get();

    final now = DateTime.now();
    final days = List.generate(
      7,
      (index) => DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: 6 - index)),
    );

    final medicines = <_MedicineAdherence>[];
    int todayTakenTotal = 0;
    int todayScheduledTotal = 0;

    for (final medDoc in medsSnapshot.docs) {
      final data = medDoc.data();
      final selectedDays = List<int>.from(data['selectedDays'] ?? [1, 2, 3, 4, 5, 6, 7]);
      final name = (data['medicineName'] ?? 'Medicine').toString();
      final dosage = (data['dosage'] ?? '').toString();

      final dayStatuses = <_DayStatus>[];
      int takenCount = 0;
      int scheduledCount = 0;
      bool scheduledToday = false;
      bool takenToday = false;

      for (final date in days) {
        final dateKey = DateFormat('yyyy-MM-dd').format(date);
        final isScheduled = selectedDays.contains(date.weekday);

        bool isTaken = false;
        if (isScheduled) {
          scheduledCount++;
          final logDoc = await medDoc.reference
              .collection('adherence_logs')
              .doc(dateKey)
              .get();
          isTaken = logDoc.exists;
          if (isTaken) {
            takenCount++;
          }
        }

        final isToday = date.year == now.year &&
            date.month == now.month &&
            date.day == now.day;

        if (isToday) {
          scheduledToday = isScheduled;
          takenToday = isTaken;
          if (isScheduled) {
            todayScheduledTotal++;
            if (isTaken) {
              todayTakenTotal++;
            }
          }
        }

        dayStatuses.add(
          _DayStatus(
            date: date,
            scheduled: isScheduled,
            taken: isTaken,
          ),
        );
      }

      final percent = scheduledCount == 0
          ? 0.0
          : (takenCount / scheduledCount) * 100;

      medicines.add(
        _MedicineAdherence(
          medicineName: name,
          dosage: dosage,
          takenCount: takenCount,
          scheduledCount: scheduledCount,
          adherencePercent: percent,
          dayStatuses: dayStatuses,
          scheduledToday: scheduledToday,
          takenToday: takenToday,
        ),
      );
    }

    medicines.sort((a, b) => a.medicineName.compareTo(b.medicineName));

    return _AdherenceReport(
      medicines: medicines,
      todayTaken: todayTakenTotal,
      todayScheduled: todayScheduledTotal,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.elderName} • Adherence Report'),
      ),
      body: FutureBuilder<_AdherenceReport>(
        future: _reportFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Failed to load adherence: ${snapshot.error}'));
          }

          final report = snapshot.data;
          if (report == null || report.medicines.isEmpty) {
            return const Center(
              child: Text(
                'No medicines found for this elder.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _reportFuture = _loadReport();
              });
              await _reportFuture;
            },
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Today\'s Summary',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${report.todayTaken} of ${report.todayScheduled} scheduled medicines taken',
                          style: const TextStyle(fontSize: 15),
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          minHeight: 10,
                          value: report.todayScheduled == 0
                              ? 0
                              : report.todayTaken / report.todayScheduled,
                          color: Colors.green,
                          backgroundColor: Colors.grey.shade300,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                ...report.medicines.map((medicine) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            medicine.medicineName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            medicine.dosage,
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '${medicine.takenCount}/${medicine.scheduledCount} days this week (${medicine.adherencePercent.toStringAsFixed(0)}%)',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: medicine.adherencePercent / 100,
                            minHeight: 9,
                            color: medicine.adherencePercent >= 80
                                ? Colors.green
                                : medicine.adherencePercent >= 50
                                    ? Colors.orange
                                    : Colors.red,
                            backgroundColor: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: medicine.dayStatuses.map((d) {
                              String symbol = '•';
                              Color bg = Colors.grey.shade300;
                              Color fg = Colors.grey.shade700;

                              if (d.scheduled && d.taken) {
                                symbol = '✓';
                                bg = Colors.green.shade100;
                                fg = Colors.green.shade800;
                              } else if (d.scheduled && !d.taken) {
                                symbol = '✕';
                                bg = Colors.red.shade100;
                                fg = Colors.red.shade700;
                              }

                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 2),
                                  child: Column(
                                    children: [
                                      Text(
                                        DateFormat('E').format(d.date).substring(0, 1),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Container(
                                        height: 24,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: bg,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          symbol,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: fg,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AdherenceReport {
  final List<_MedicineAdherence> medicines;
  final int todayTaken;
  final int todayScheduled;

  const _AdherenceReport({
    required this.medicines,
    required this.todayTaken,
    required this.todayScheduled,
  });
}

class _MedicineAdherence {
  final String medicineName;
  final String dosage;
  final int takenCount;
  final int scheduledCount;
  final double adherencePercent;
  final List<_DayStatus> dayStatuses;
  final bool scheduledToday;
  final bool takenToday;

  const _MedicineAdherence({
    required this.medicineName,
    required this.dosage,
    required this.takenCount,
    required this.scheduledCount,
    required this.adherencePercent,
    required this.dayStatuses,
    required this.scheduledToday,
    required this.takenToday,
  });
}

class _DayStatus {
  final DateTime date;
  final bool scheduled;
  final bool taken;

  const _DayStatus({
    required this.date,
    required this.scheduled,
    required this.taken,
  });
}
