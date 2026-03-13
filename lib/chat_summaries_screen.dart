import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ChatSummariesScreen extends StatelessWidget {
  final String elderId;
  final String elderName;

  const ChatSummariesScreen({
    super.key,
    required this.elderId,
    required this.elderName,
  });

  Color _moodColor(String mood) {
    switch (mood.toLowerCase()) {
      case 'happy':
      case 'calm':
        return Colors.green;
      case 'tired':
        return Colors.amber.shade700;
      case 'sad':
      case 'anxious':
        return Colors.red;
      default:
        return Colors.blueGrey;
    }
  }

  IconData _moodIcon(String mood) {
    switch (mood.toLowerCase()) {
      case 'happy':
        return Icons.sentiment_satisfied_alt;
      case 'calm':
        return Icons.self_improvement;
      case 'tired':
        return Icons.bedtime;
      case 'sad':
        return Icons.sentiment_dissatisfied;
      case 'anxious':
        return Icons.psychology_alt;
      default:
        return Icons.mood;
    }
  }

  String _formatDuration(Timestamp? start, Timestamp? end) {
    if (start == null || end == null) return 'Duration unavailable';

    final duration = end.toDate().difference(start.toDate());
    final mins = duration.inMinutes;
    if (mins < 1) return '< 1 min';
    if (mins < 60) return '$mins min';

    final hours = duration.inHours;
    final remainingMins = mins % 60;
    return '${hours}h ${remainingMins}m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$elderName • Chat Summaries'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(elderId)
            .collection('chat_summaries')
            .orderBy('createdAt', descending: true)
            .limit(30)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Failed to load summaries: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No chat summaries available yet.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final createdAt = data['createdAt'] as Timestamp?;
              final sessionStart = data['sessionStart'] as Timestamp?;
              final sessionEnd = data['sessionEnd'] as Timestamp?;
              final mood = (data['mood'] ?? 'unknown').toString();
              final summary = (data['summary'] ?? '').toString();
              final messageCount = (data['messageCount'] ?? 0).toString();

              final dateLabel = createdAt != null
                  ? DateFormat('dd MMM yyyy, hh:mm a').format(createdAt.toDate())
                  : 'Unknown date';

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              dateLabel,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Chip(
                            visualDensity: VisualDensity.compact,
                            avatar: Icon(
                              _moodIcon(mood),
                              size: 16,
                              color: _moodColor(mood),
                            ),
                            label: Text(mood),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${_formatDuration(sessionStart, sessionEnd)} • $messageCount messages',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        summary.isEmpty ? 'No summary generated.' : summary,
                        style: const TextStyle(fontSize: 15, height: 1.35),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
