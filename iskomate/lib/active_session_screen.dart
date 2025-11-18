import 'package:flutter/material.dart';

class ActiveSessionScreen extends StatelessWidget {
  final Map<String, String> session;
  const ActiveSessionScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF332C2B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF332C2B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          Center(
            child: Text(
              'STUDY SESSION 1',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              session['date'] ?? '',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Duration 00:00:00',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Chart placeholder - increased height
          Container(
            height: 320, // Increased from 200 to 320
            margin: const EdgeInsets.symmetric(horizontal: 12),
            color: Colors.black,
            child: Center(
              child: Text(
                'Chart Placeholder',
                style: TextStyle(color: Colors.white54),
              ),
            ),
          ),
          const SizedBox(height: 24), // Space between chart and legends
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                color: const Color(0xFF8B3A3A),
              ),
              const SizedBox(width: 8),
              const Text(
                'ENGAGED',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 32),
              Container(
                width: 32,
                height: 32,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              const Text(
                'NOT ENGAGED',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24), // Add some bottom padding
        ],
      ),
    );
  }
}