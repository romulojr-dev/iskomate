import 'package:flutter/material.dart';
import 'theme.dart';
import 'view_session_screen.dart';
import 'edit_session_screen.dart';
import 'add_session_screen.dart';
import 'active_session_screen.dart'; // Add this import

class ListSessionsScreen extends StatefulWidget {
  const ListSessionsScreen({super.key});

  @override
  State<ListSessionsScreen> createState() => _ListSessionsScreenState();
}

class _ListSessionsScreenState extends State<ListSessionsScreen> {
  final List<Map<String, String>> _sessions = [
    {'name': 'CAO: BSCPE 4-1', 'date': '2025-11-09'},
    {'name': 'LCD: BSCPE 3-3', 'date': '2025-11-09'},
    {'name': 'DSA: BSCPE 2-4', 'date': '2025-11-09'},
    {'name': 'HDL: BSCPE 3-6', 'date': '2025-11-09'},
    {'name': 'FCS: BSCPE 3-7', 'date': '2025-11-09'},
  ];

  void _deleteSession(int index) {
    setState(() {
      _sessions.removeAt(index);
    });
  }

  void _onViewSessionPressed(Map<String, String> session) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ViewSessionScreen(session: session),
      ),
    );
  }

  void _onEditSessionPressed(Map<String, String> session) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditSessionScreen(session: session),
      ),
    );
  }

  void _onAddSessionPressed() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddSessionScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor, // Use your theme background
      appBar: AppBar(
        backgroundColor: kAccentColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'LIST OF SESSIONS',
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
          itemCount: _sessions.length,
          itemBuilder: (context, index) {
            final session = _sessions[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white, // Button is white
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: kAccentColor, width: 2),
                  ),
                ),
                // --- THIS IS THE CHANGE ---
                // Clicking the button now calls _onViewSessionPressed
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ActiveSessionScreen(session: session),
                  ),
                ),
                // --- END OF CHANGE ---
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
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
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_red_eye, color: kAccentColor),
                            onPressed: () => _onViewSessionPressed(session),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, color: kAccentColor),
                            onPressed: () => _onEditSessionPressed(session),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteSession(index),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: kAccentColor,
        onPressed: _onAddSessionPressed,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}