import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CaregiverNotesScreen extends StatefulWidget {
  final String elderId;
  final String elderName;

  const CaregiverNotesScreen({
    super.key,
    required this.elderId,
    required this.elderName,
  });

  @override
  State<CaregiverNotesScreen> createState() => _CaregiverNotesScreenState();
}

class _CaregiverNotesScreenState extends State<CaregiverNotesScreen> {
  Future<void> _addNote() async {
    final controller = TextEditingController();

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Caregiver Note'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          minLines: 3,
          decoration: const InputDecoration(
            hintText: 'Write context about this elder…',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (shouldSave != true) return;

    final text = controller.text.trim();
    if (text.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.elderId)
        .collection('caregiver_notes')
        .add({
          'text': text,
          'active': true,
          'createdBy': user?.phoneNumber ?? user?.uid ?? 'unknown',
          'createdAt': FieldValue.serverTimestamp(),
        });
  }

  Future<void> _toggleActive(String noteId, bool current) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.elderId)
        .collection('caregiver_notes')
        .doc(noteId)
        .update({'active': !current});
  }

  Future<void> _deleteNote(String noteId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.elderId)
        .collection('caregiver_notes')
        .doc(noteId)
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.elderName} • Caregiver Notes'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.elderId)
            .collection('caregiver_notes')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Failed to load notes: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No caregiver notes yet.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final text = (data['text'] ?? '').toString();
              final active = data['active'] == true;
              final createdAt = data['createdAt'] as Timestamp?;
              final when = createdAt != null
                  ? DateFormat('dd MMM yyyy, hh:mm a').format(createdAt.toDate())
                  : 'Unknown date';

              return Dismissible(
                key: ValueKey(doc.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  color: Colors.red,
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (_) => _deleteNote(doc.id),
                child: Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(text),
                    subtitle: Text(when),
                    trailing: Switch(
                      value: active,
                      onChanged: (_) => _toggleActive(doc.id, active),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNote,
        child: const Icon(Icons.add),
      ),
    );
  }
}
