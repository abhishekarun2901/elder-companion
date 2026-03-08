// lib/profile_check_wrapper.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_screen.dart';
import 'profile_details_screen.dart';

class ProfileCheckWrapper extends StatelessWidget {
  const ProfileCheckWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // This should not happen, but as a safeguard
    if (user == null) {
      return const Scaffold(body: Center(child: Text("Error: Not logged in.")));
    }

    return FutureBuilder<DocumentSnapshot>(
      // Check if a document with the user's UID exists in the 'users' collection
      future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
      builder: (context, snapshot) {
        // 1. While waiting for the data, show a loading indicator
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 2. If there's an error
        if (snapshot.hasError) {
          return Scaffold(body: Center(child: Text("Error: ${snapshot.error}")));
        }

        // 3. If the document exists, the user has a profile -> Go to HomeScreen
        if (snapshot.hasData && snapshot.data!.exists) {
          return const HomeScreen();
        }

        // 4. If the document does NOT exist, the user is new -> Go to ProfileDetailsScreen
        else {
          return const ProfileDetailsScreen();
        }
      },
    );
  }
}