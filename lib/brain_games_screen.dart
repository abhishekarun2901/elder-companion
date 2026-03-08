import 'package:flutter/material.dart';
import 'sudoku.dart'; // import the Sudoku screen
import 'memory_game.dart'; // import your Memory Card Game screen

class BrainGamesScreen extends StatelessWidget {
  const BrainGamesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Brain Games'),
        backgroundColor: Colors.teal,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            BrainGameCard(
              title: 'Sudoku',
              description: 'Solve Sudoku puzzles to train your brain.',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SudokuGameScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            BrainGameCard(
              title: 'Memory Card Game',
              description: 'Match pairs of cards to improve memory.',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MemoryGameScreen(), // make const if possible
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class BrainGameCard extends StatelessWidget {
  final String title;
  final String description;
  final VoidCallback onTap;

  const BrainGameCard({
    super.key,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
