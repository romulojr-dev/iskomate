import 'package:flutter/material.dart';
import 'theme.dart';

class SelectSessionScreen extends StatelessWidget {
  const SelectSessionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Example session data
    final sessions = [
      {'name': 'CAO: BSCPE 4-1', 'date': '2025-11-09'},
      {'name': 'LCD: BSCPE 3-3', 'date': '2025-11-09'},
      {'name': 'DSA: BSCPE 2-4', 'date': '2025-11-09'},
      {'name': 'HDL: BSCPE 3-6', 'date': '2025-11-09'},
      {'name': 'FCS: BSCPE 3-7', 'date': '2025-11-09'},
    ];

    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: kBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'SELECT SESSION',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        child: ListView.builder(
          itemCount: sessions.length,
          itemBuilder: (context, index) {
            final session = sessions[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white, // White background
                  foregroundColor: Colors.black, // Black text
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: kAccentColor, width: 2), // Accent-colored border
                  ),
                ),
                onPressed: () {
                  // Return the selected session name to the previous screen
                  Navigator.pop(context, session['name']);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0), // Add padding for text and icon
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session['name']!,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            session['date']!,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                      Icon(Icons.chevron_right, size: 28, color: kAccentColor), // Accent-colored icon
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}