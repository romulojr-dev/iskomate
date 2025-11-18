// solo_session_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for SystemChrome

// Internal imports matching your project structure
import 'theme.dart';
import 'start_session.dart'; // Import the start_session.dart file

class SoloSessionScreen extends StatefulWidget {
  final String sessionName;

  const SoloSessionScreen({super.key, required this.sessionName});

  @override
  State<SoloSessionScreen> createState() => _SoloSessionScreenState();
}

class _SoloSessionScreenState extends State<SoloSessionScreen> {
  // Timer variables
  Timer? _timer;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _setSystemUIOverlay();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _duration = Duration(seconds: _duration.inSeconds + 1);
      });
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

  @override
  Widget build(BuildContext context) {
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
                widget.sessionName.toUpperCase(),
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
                  fontWeight: FontWeight.w300, // Thin weight to match design
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 10),

              // Timer Display
              Text(
                _formatDuration(_duration),
                style: const TextStyle(
                  color: kLightGreyColor,
                  fontSize: 80,
                  fontWeight: FontWeight.w300, // Thin weight to match design
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
                    onPressed: _handleTerminate,
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