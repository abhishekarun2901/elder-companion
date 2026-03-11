import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'add_medicine_screen.dart';

class MedicineReminder extends StatefulWidget {
  final String? targetElderId;

  const MedicineReminder({super.key, this.targetElderId});

  @override
  State<MedicineReminder> createState() => _MedicineReminderState();
}

class _MedicineReminderState extends State<MedicineReminder> {
  final user = FirebaseAuth.instance.currentUser;
  
  // Get today's date placeholder string (e.g. 2024-03-08)
  String get todayKey {
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  Future<void> _toggleTaken(String medDocId, bool currentlyTaken) async {
    // Caregivers cannot take meds for the elder
    if (widget.targetElderId != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only the Elder can mark medication as taken.')),
      );
      return;
    }

    try {
      final docRef = FirebaseFirestore.instance
          .collection('medicines')
          .doc(medDocId)
          .collection('adherence_logs')
          .doc(todayKey);

      if (currentlyTaken) {
        // Untake (delete the log for today)
        await docRef.delete();
      } else {
        // Take (create the log for today)
        await docRef.set({
          'takenAt': FieldValue.serverTimestamp(),
          'date': todayKey,
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update adherence: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final elderIdToUse = widget.targetElderId ?? user?.uid;

    if (elderIdToUse == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Medicine Reminders')),
        body: const Center(child: Text("Cannot load medications. User not found.")),
      );
    }

    final isCaregiver = widget.targetElderId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isCaregiver ? "Elder's Medications" : "My Medicines"),
        backgroundColor: Colors.teal,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('medicines')
            .where('elderId', isEqualTo: elderIdToUse)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                isCaregiver 
                  ? "No medications added for this elder yet." 
                  : "You have no medicines scheduled.",
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          final docs = snapshot.data!.docs;
          // Sort explicitly by createdAt or by time
           docs.sort((a, b) {
             final aMap = a.data() as Map<String, dynamic>;
             final bMap = b.data() as Map<String, dynamic>;
             final aHour = aMap['hour'] ?? 0;
             final bHour = bMap['hour'] ?? 0;
             final aMin = aMap['minute'] ?? 0;
             final bMin = bMap['minute'] ?? 0;
             if (aHour != bHour) return aHour.compareTo(bHour);
             return aMin.compareTo(bMin);
           });

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80, top: 10),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final medDoc = docs[index];
              final medData = medDoc.data() as Map<String, dynamic>;
              final String medName = medData['medicineName'] ?? 'Unknown Medicine';
              final String medTime = medData['time'] ?? '';
              final String medDosage = medData['dosage'] ?? '';
              final List<int> selectedDays = List<int>.from(medData['selectedDays'] ?? [1,2,3,4,5,6,7]);
              final int currentWeekday = DateTime.now().weekday;
              final bool isScheduledToday = selectedDays.contains(currentWeekday);

              // Use a nested StreamBuilder to check Adherence for TODAY
              return StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('medicines')
                    .doc(medDoc.id)
                    .collection('adherence_logs')
                    .doc(todayKey)
                    .snapshots(),
                builder: (context, adherenceSnapshot) {
                  final bool isTaken = adherenceSnapshot.data?.exists ?? false;

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                      side: BorderSide(
                        color: isTaken ? Colors.green : Colors.grey.shade300,
                        width: isTaken ? 2 : 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isTaken ? Colors.green.shade100 : Colors.teal.shade50,
                          child: Icon(
                            isTaken ? Icons.check_circle : Icons.medical_services,
                            color: isTaken ? Colors.green : Colors.teal,
                            size: 28,
                          ),
                        ),
                        title: Text(
                          medName,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            decoration: isTaken ? TextDecoration.lineThrough : null,
                            color: isTaken ? Colors.grey : Colors.black87,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            "$medDosage  •  $medTime",
                            style: TextStyle(
                              fontSize: 16, 
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        trailing: !isScheduledToday ? 
                            Chip(
                              label: const Text("Not Today", style: TextStyle(color: Colors.white, fontSize: 12)),
                              backgroundColor: Colors.grey.shade400,
                              padding: EdgeInsets.zero,
                            )
                          : isCaregiver 
                          ? (isTaken 
                              ? const Chip(
                                  label: Text("Taken", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  backgroundColor: Colors.green,
                                )
                              : const Chip(
                                  label: Text("Pending", style: TextStyle(color: Colors.white)),
                                  backgroundColor: Colors.orange,
                                ))
                          : ElevatedButton.icon(
                              onPressed: () => _toggleTaken(medDoc.id, isTaken),
                              icon: Icon(isTaken ? Icons.undo : Icons.check, color: Colors.white),
                              label: Text(isTaken ? 'Undo' : 'Take'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isTaken ? Colors.grey : Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              ),
                            ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddMedicineScreen(targetElderId: widget.targetElderId),
            ),
          );
        },
        backgroundColor: Colors.teal,
        icon: const Icon(Icons.edit_calendar, color: Colors.white),
        label: const Text("Manage Meds", style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
