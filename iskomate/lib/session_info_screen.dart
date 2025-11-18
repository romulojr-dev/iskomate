import 'package:flutter/material.dart';
import 'theme.dart';

class SessionInfoScreen extends StatelessWidget {
  final Map<String, dynamic> session;

  const SessionInfoScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: kAccentColor,
        elevation: 0,
        title: const Text('Session Info'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              session['name'] ?? 'No Name',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Date: ${session['date'] ?? 'No Date'}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 18,
              ),
            ),
            // Add more fields as needed
          ],
        ),
      ),
    );
  }
}