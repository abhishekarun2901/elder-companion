// lib/log_vitals_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LogVitalsScreen extends StatefulWidget {
  const LogVitalsScreen({super.key});

  @override
  _LogVitalsScreenState createState() => _LogVitalsScreenState();
}

class _LogVitalsScreenState extends State<LogVitalsScreen> {
  // Controllers for each text field
  final _heartRateController = TextEditingController();
  final _systolicBPController = TextEditingController(); // Top number
  final _diastolicBPController = TextEditingController(); // Bottom number
  final _bloodOxygenController = TextEditingController();
  final _bloodGlucoseController = TextEditingController();
  final _stepsController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _heartRateController.dispose();
    _systolicBPController.dispose();
    _diastolicBPController.dispose();
    _bloodOxygenController.dispose();
    _bloodGlucoseController.dispose();
    _stepsController.dispose();
    super.dispose();
  }

  // Save the data to Firestore
  Future<void> _saveVitals() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: You are not logged in.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();
      final timestamp = FieldValue.serverTimestamp();

      // Add Heart Rate
      if (_heartRateController.text.isNotEmpty) {
        final docRef = firestore
            .collection('users')
            .doc(user.uid)
            .collection('health_vitals')
            .doc();
        batch.set(docRef, {
          'title': 'Heart Rate',
          'value': _heartRateController.text,
          'unit': 'BPM',
          'timestamp': timestamp,
        });
      }

      // Add Blood Pressure
      if (_systolicBPController.text.isNotEmpty &&
          _diastolicBPController.text.isNotEmpty) {
        final docRef = firestore
            .collection('users')
            .doc(user.uid)
            .collection('health_vitals')
            .doc();
        batch.set(docRef, {
          'title': 'Blood Pressure',
          'value':
              '${_systolicBPController.text}/${_diastolicBPController.text}',
          'unit': 'mmHg',
          'timestamp': timestamp,
        });
      }

      // Add Blood Oxygen
      if (_bloodOxygenController.text.isNotEmpty) {
        final docRef = firestore
            .collection('users')
            .doc(user.uid)
            .collection('health_vitals')
            .doc();
        batch.set(docRef, {
          'title': 'Blood Oxygen',
          'value': _bloodOxygenController.text,
          'unit': '%SpO2',
          'timestamp': timestamp,
        });
      }

      // Add Blood Glucose
      if (_bloodGlucoseController.text.isNotEmpty) {
        final docRef = firestore
            .collection('users')
            .doc(user.uid)
            .collection('health_vitals')
            .doc();
        batch.set(docRef, {
          'title': 'Blood Glucose',
          'value': _bloodGlucoseController.text,
          'unit': 'mg/dL',
          'timestamp': timestamp,
        });
      }

      // Add Steps Count
      if (_stepsController.text.isNotEmpty) {
        final docRef = firestore
            .collection('users')
            .doc(user.uid)
            .collection('health_vitals')
            .doc();
        batch.set(docRef, {
          'title': 'Steps Count',
          'value': _stepsController.text,
          'unit': 'steps',
          'timestamp': timestamp,
        });
      }

      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vitals saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save vitals: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log New Vitals'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            _buildTextField(
              controller: _heartRateController,
              label: 'Heart Rate',
              hint: 'e.g., 72',
              icon: Icons.favorite,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _systolicBPController,
                    label: 'Systolic BP',
                    hint: 'e.g., 120',
                    icon: Icons.compress,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text('/', style: TextStyle(fontSize: 24)),
                ),
                Expanded(
                  child: _buildTextField(
                    controller: _diastolicBPController,
                    label: 'Diastolic BP',
                    hint: 'e.g., 80',
                    icon: null,
                  ), // No icon for the second part
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _bloodOxygenController,
              label: 'Blood Oxygen (SpO2)',
              hint: 'e.g., 98',
              icon: Icons.opacity,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _bloodGlucoseController,
              label: 'Blood Glucose',
              hint: 'e.g., 110',
              icon: Icons.water_drop,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _stepsController,
              label: 'Steps Today',
              hint: 'e.g., 3500',
              icon: Icons.directions_walk,
            ),
            const SizedBox(height: 30),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton.icon(
                    onPressed: _saveVitals,
                    icon: const Icon(Icons.save, color: Colors.white),
                    label: const Text(
                      'Save Vitals',
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade600,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    IconData? icon,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon != null ? Icon(icon, color: Colors.teal) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.teal, width: 2),
        ),
      ),
    );
  }
}
