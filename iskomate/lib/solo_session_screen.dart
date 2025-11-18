// solo_session_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for SystemChrome
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore

// Internal imports matching your project structure
import 'theme.dart';
import 'start_session.dart'; // Import the start_session.dart file

// STEP 1: Convert StatelessWidget to StatefulWidget
class SoloSessionScreen extends StatefulWidget {
  final String sessionName;
  final String sessionId;

  const SoloSessionScreen({
    super.key,
    required this.sessionName,
    required this.sessionId,
  });

  @override
  State<SoloSessionScreen> createState() => _SoloSessionScreenState();
}

// STEP 2: Create the State Class to hold the timer logic and duration
class _SoloSessionScreenState extends State<SoloSessionScreen> {
  // Timer variables moved into the State class
  Timer? _timer;
  Duration _duration = Duration.zero;
  DateTime? _startTime; // Track when the session starts

  // STEP 3: Initialize Timer and System UI
  @override
  void initState() {
    super.initState();
    _setSystemUIOverlay();
    _startTimer();
    _startTime = DateTime.now(); // Save when session starts
  }

  // STEP 4: Cancel Timer when the widget is closed
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // Function to start the periodic timer
  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) { // Ensure widget is still active before calling setState
        // STEP 5: Call setState() to trigger UI update
        setState(() {
          _duration = Duration(seconds: _duration.inSeconds + 1);
        });
      }
    });
  }

  // Helper to format duration to HH:MM:SS
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  void _setSystemUIOverlay() {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: kBackgroundColor,
      systemNavigationBarIconBrightness: Brightness.light,
    ));
  }

  void _handleTerminate() {
    _timer?.cancel();
    // Navigate back to the setup screen
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const SessionSetupScreen()),
      (route) => false,
    );
  }

  void _terminateSession() async {
    final endTime = DateTime.now();
    final duration = endTime.difference(_startTime!);

    String formattedDuration = [
      duration.inHours.toString().padLeft(2, '0'),
      (duration.inMinutes % 60).toString().padLeft(2, '0'),
      (duration.inSeconds % 60).toString().padLeft(2, '0'),
    ].join(':');

    await FirebaseFirestore.instance
        .collection('sessions')
        .doc(widget.sessionId) // Use the sessionId from the widget
        .update({'duration': formattedDuration});

    Navigator.pop(context); // Or whatever you do to end the session
  }

  @override
  Widget build(BuildContext context) {
    // Get the formatted time string (will update on every setState call)
    final String formattedDuration = _formatDuration(_duration);

    return Scaffold(
      backgroundColor: kBackgroundColor, // Matches previous page background
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0), // Add side padding
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 60), // Increased height to lower the Session Name down a bit

              // SESSION NAME Header
              Text(
                widget.sessionName.toUpperCase(), // Use widget.sessionName in the State class
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),

              const Spacer(), // Pushes timer to the visual middle

              // Duration Label
              const Text(
                'Duration:',
                style: TextStyle(
                  color: kLightGreyColor,
                  fontSize: 48,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 10),

              // Timer Display (Now dynamic)
              Text(
                formattedDuration, // Use the state variable
                style: const TextStyle(
                  color: kLightGreyColor,
                  fontSize: 80,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 2.0,
                ),
              ),

              const Spacer(), // Pushes button to the bottom

              // TERMINATE SESSION Button
              Padding(
                padding: const EdgeInsets.only(bottom: 40.0), // Bottom spacing
                child: SizedBox(
                  width: double.infinity, // Makes button full width
                  height: 55, // Slightly taller button
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAccentColor, // Use the app's accent color
                      foregroundColor: Colors.white,
                      elevation: 0, // Flat design
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        letterSpacing: 1.0,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      _terminateSession(); // Call the new terminate function
                    },
                    child: const Text('TERMINATE SESSION'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}