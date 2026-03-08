import 'package:flutter/material.dart';
import 'dart:math';

class SudokuGameScreen extends StatefulWidget {
  const SudokuGameScreen({super.key});

  @override
  State<SudokuGameScreen> createState() => _SudokuGameScreen();
}

class _SudokuGameScreen extends State<SudokuGameScreen> {
  late SudokuGame _game;
  int? _selectedRow;
  int? _selectedCol;
  bool _showErrors = false;

  @override
  void initState() {
    super.initState();
    _game = SudokuGame();
    _game.generatePuzzle(
      difficulty: 40,
    ); // 40 cells removed = medium difficulty
  }

  void _selectCell(int row, int col) {
    if (!_game.isFixed[row][col]) {
      setState(() {
        _selectedRow = row;
        _selectedCol = col;
      });
    }
  }

  void _enterNumber(int number) {
    if (_selectedRow != null && _selectedCol != null) {
      setState(() {
        _game.board[_selectedRow!][_selectedCol!] = number;
        _showErrors = false;
      });

      // Check if puzzle is complete
      if (_game.isPuzzleComplete()) {
        if (_game.isValid()) {
          _showWinDialog();
        }
      }
    }
  }

  void _clearCell() {
    if (_selectedRow != null && _selectedCol != null) {
      setState(() {
        _game.board[_selectedRow!][_selectedCol!] = 0;
        _showErrors = false;
      });
    }
  }

  void _checkAnswers() {
    setState(() {
      _showErrors = true;
    });

    if (_game.isValid() && _game.isPuzzleComplete()) {
      _showWinDialog();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Some answers are incorrect. Keep trying!'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _showWinDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🎉 Congratulations!'),
        content: const Text('You solved the Sudoku puzzle!'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _newGame();
            },
            child: const Text('New Game'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }

  void _newGame() {
    setState(() {
      _game = SudokuGame();
      _game.generatePuzzle(difficulty: 40);
      _selectedRow = null;
      _selectedCol = null;
      _showErrors = false;
    });
  }

  void _showHint() {
    // Find an empty cell and fill it with the correct answer
    for (int i = 0; i < 9; i++) {
      for (int j = 0; j < 9; j++) {
        if (_game.board[i][j] == 0 && !_game.isFixed[i][j]) {
          setState(() {
            _game.board[i][j] = _game.solution[i][j];
            _selectedRow = i;
            _selectedCol = j;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Hint: Cell filled with correct answer'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sudoku Game'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.lightbulb_outline),
            onPressed: _showHint,
            tooltip: 'Get Hint',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('New Game'),
                  content: const Text('Start a new Sudoku puzzle?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _newGame();
                      },
                      child: const Text('New Game'),
                    ),
                  ],
                ),
              );
            },
            tooltip: 'New Game',
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          // Sudoku Board
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black, width: 3),
                    color: Colors.white,
                  ),
                  child: _buildSudokuGrid(),
                ),
              ),
            ),
          ),

          // Action Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _checkAnswers,
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Check'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _clearCell,
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Number Input Pad
          Container(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: List.generate(9, (index) {
                final number = index + 1;
                return SizedBox(
                  width: 50,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => _enterNumber(number),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      '$number',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSudokuGrid() {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 9,
        childAspectRatio: 1,
      ),
      itemCount: 81,
      itemBuilder: (context, index) {
        final row = index ~/ 9;
        final col = index % 9;
        final value = _game.board[row][col];
        final isFixed = _game.isFixed[row][col];
        final isSelected = _selectedRow == row && _selectedCol == col;
        final isInSameRow = _selectedRow == row;
        final isInSameCol = _selectedCol == col;
        final isInSameBox =
            _selectedRow != null &&
            _selectedCol != null &&
            (row ~/ 3 == _selectedRow! ~/ 3) &&
            (col ~/ 3 == _selectedCol! ~/ 3);

        // Check if this cell has an error
        final hasError =
            _showErrors && value != 0 && value != _game.solution[row][col];

        return GestureDetector(
          onTap: () => _selectCell(row, col),
          child: Container(
            decoration: BoxDecoration(
              color: hasError
                  ? Colors.red.shade100
                  : isSelected
                  ? Colors.teal.shade200
                  : isInSameRow || isInSameCol || isInSameBox
                  ? Colors.teal.shade50
                  : Colors.white,
              border: Border(
                top: BorderSide(
                  color: row % 3 == 0 ? Colors.black : Colors.grey.shade400,
                  width: row % 3 == 0 ? 2 : 0.5,
                ),
                left: BorderSide(
                  color: col % 3 == 0 ? Colors.black : Colors.grey.shade400,
                  width: col % 3 == 0 ? 2 : 0.5,
                ),
                right: BorderSide(
                  color: col == 8 || (col + 1) % 3 == 0
                      ? Colors.black
                      : Colors.grey.shade400,
                  width: col == 8 || (col + 1) % 3 == 0 ? 2 : 0.5,
                ),
                bottom: BorderSide(
                  color: row == 8 || (row + 1) % 3 == 0
                      ? Colors.black
                      : Colors.grey.shade400,
                  width: row == 8 || (row + 1) % 3 == 0 ? 2 : 0.5,
                ),
              ),
            ),
            child: Center(
              child: value != 0
                  ? Text(
                      '$value',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: isFixed
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isFixed
                            ? Colors.black
                            : hasError
                            ? Colors.red
                            : Colors.teal.shade700,
                      ),
                    )
                  : null,
            ),
          ),
        );
      },
    );
  }
}

// Sudoku Game Logic
class SudokuGame {
  List<List<int>> board = List.generate(9, (_) => List.filled(9, 0));
  List<List<int>> solution = List.generate(9, (_) => List.filled(9, 0));
  List<List<bool>> isFixed = List.generate(9, (_) => List.filled(9, false));
  final Random _random = Random();

  void generatePuzzle({int difficulty = 40}) {
    // Generate a complete valid Sudoku
    _generateCompleteSudoku();

    // Copy solution
    for (int i = 0; i < 9; i++) {
      for (int j = 0; j < 9; j++) {
        solution[i][j] = board[i][j];
      }
    }

    // Remove cells to create puzzle
    _removeNumbers(difficulty);
  }

  void _generateCompleteSudoku() {
    // Fill diagonal 3x3 boxes first (they're independent)
    for (int box = 0; box < 9; box += 3) {
      _fillBox(box, box);
    }

    // Fill remaining cells
    _fillRemaining(0, 3);
  }

  void _fillBox(int row, int col) {
    List<int> numbers = List.generate(9, (i) => i + 1)..shuffle(_random);
    int index = 0;

    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 3; j++) {
        board[row + i][col + j] = numbers[index++];
      }
    }
  }

  bool _fillRemaining(int row, int col) {
    if (col >= 9 && row < 8) {
      row++;
      col = 0;
    }
    if (row >= 9 && col >= 9) {
      return true;
    }

    if (row < 3) {
      if (col < 3) col = 3;
    } else if (row < 6) {
      if (col == (row ~/ 3) * 3) col += 3;
    } else {
      if (col == 6) {
        row++;
        col = 0;
        if (row >= 9) return true;
      }
    }

    for (int num = 1; num <= 9; num++) {
      if (_isSafe(row, col, num)) {
        board[row][col] = num;
        if (_fillRemaining(row, col + 1)) {
          return true;
        }
        board[row][col] = 0;
      }
    }
    return false;
  }

  bool _isSafe(int row, int col, int num) {
    return !_usedInRow(row, num) &&
        !_usedInCol(col, num) &&
        !_usedInBox(row - row % 3, col - col % 3, num);
  }

  bool _usedInRow(int row, int num) {
    return board[row].contains(num);
  }

  bool _usedInCol(int col, int num) {
    for (int i = 0; i < 9; i++) {
      if (board[i][col] == num) return true;
    }
    return false;
  }

  bool _usedInBox(int boxStartRow, int boxStartCol, int num) {
    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 3; j++) {
        if (board[boxStartRow + i][boxStartCol + j] == num) return true;
      }
    }
    return false;
  }

  void _removeNumbers(int count) {
    List<int> positions = List.generate(81, (i) => i)..shuffle(_random);

    for (int i = 0; i < count && i < positions.length; i++) {
      int pos = positions[i];
      int row = pos ~/ 9;
      int col = pos % 9;
      board[row][col] = 0;
    }

    // Mark non-zero cells as fixed
    for (int i = 0; i < 9; i++) {
      for (int j = 0; j < 9; j++) {
        isFixed[i][j] = board[i][j] != 0;
      }
    }
  }

  bool isValid() {
    for (int i = 0; i < 9; i++) {
      for (int j = 0; j < 9; j++) {
        if (board[i][j] != 0 && board[i][j] != solution[i][j]) {
          return false;
        }
      }
    }
    return true;
  }

  bool isPuzzleComplete() {
    for (int i = 0; i < 9; i++) {
      for (int j = 0; j < 9; j++) {
        if (board[i][j] == 0) return false;
      }
    }
    return true;
  }
}
