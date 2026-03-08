import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';

class MemoryGameScreen extends StatefulWidget {
  const MemoryGameScreen({super.key});

  @override
  State<MemoryGameScreen> createState() => _MemoryGameScreenState();
}

class _MemoryGameScreenState extends State<MemoryGameScreen> {
  final int _gridSize = 4; // 4x4 grid = 16 cards
  late List<_CardModel> _cards;
  _CardModel? _firstFlipped;
  _CardModel? _secondFlipped;
  bool _wait = false;

  @override
  void initState() {
    super.initState();
    _initCards();
  }

  void _initCards() {
    List<int> numbers = List.generate(
      (_gridSize * _gridSize) ~/ 2,
      (i) => i + 1,
    );
    numbers = [...numbers, ...numbers]; // duplicate for pairs
    numbers.shuffle(Random());

    _cards = numbers.map((num) => _CardModel(number: num)).toList();
  }

  void _flipCard(int index) async {
    if (_wait || _cards[index].isMatched || _cards[index].isFlipped) return;

    setState(() {
      _cards[index].isFlipped = true;
    });

    if (_firstFlipped == null) {
      _firstFlipped = _cards[index];
    } else {
      _secondFlipped = _cards[index];
      _wait = true;

      if (_firstFlipped!.number == _secondFlipped!.number) {
        // Match found
        setState(() {
          _firstFlipped!.isMatched = true;
          _secondFlipped!.isMatched = true;
        });
      } else {
        // Not a match, flip back after delay
        await Future.delayed(const Duration(seconds: 1));
        setState(() {
          _firstFlipped!.isFlipped = false;
          _secondFlipped!.isFlipped = false;
        });
      }

      _firstFlipped = null;
      _secondFlipped = null;
      _wait = false;

      if (_cards.every((card) => card.isMatched)) {
        _showWinDialog();
      }
    }
  }

  void _showWinDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('🎉 You Won!'),
        content: const Text('Congratulations, you matched all pairs!'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _initCards();
              });
            },
            child: const Text('Play Again'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Memory Card Game'),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _initCards();
              });
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            double spacing = 6.0;
            // Cap tile size at 60 so grid stays small
            double tileSize = min(
              (constraints.maxWidth - spacing * (_gridSize - 1)) / _gridSize,
              60,
            );

            return Center(
              child: Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: List.generate(_cards.length, (index) {
                  final card = _cards[index];
                  return GestureDetector(
                    onTap: () => _flipCard(index),
                    child: Container(
                      width: tileSize,
                      height: tileSize,
                      decoration: BoxDecoration(
                        color: card.isFlipped || card.isMatched
                            ? Colors.deepPurple
                            : Colors.grey,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          card.isFlipped || card.isMatched
                              ? '${card.number}'
                              : '',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CardModel {
  final int number;
  bool isFlipped;
  bool isMatched;

  _CardModel({
    required this.number,
    this.isFlipped = false,
    this.isMatched = false,
  });
}
