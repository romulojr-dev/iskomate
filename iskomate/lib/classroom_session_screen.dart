import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for SystemChrome

// Internal imports matching your project structure
import 'theme.dart';
import 'start_session.dart'; // Import for navigation back

class ClassroomSessionScreen extends StatefulWidget {
  final String sessionName;

  const ClassroomSessionScreen({super.key, required this.sessionName});

  @override
  State<ClassroomSessionScreen> createState() => _ClassroomSessionScreenState();
}

class _ClassroomSessionScreenState extends State<ClassroomSessionScreen> {
  // Timer variables
  Timer? _timer;
  Duration _duration = Duration.zero;

  // Specific color from the design image (Maroon/Red)
  final Color _terminateColor = const Color(0xFF8D333C);
  
  // TODO: Replace these hardcoded values with real data
  final String _engagedPercent = '75%';
  final String _notEngagedPercent = '25%';

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
          padding: const EdgeInsets.symmetric(horizontal: 20.0), // Side padding
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 60), // Top spacing

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
              const SizedBox(height: 24),

              // Engaged Box
              _buildEngagementBox(
                _engagedPercent, 
                kAccentColor, // Maroon color from theme
                Colors.white,
              ),
              const SizedBox(height: 16),

              // Not Engaged Box
              _buildEngagementBox(
                _notEngagedPercent,
                kLightGreyColor, // Light grey from theme
                kBackgroundColor, // Dark text
              ),

              const Spacer(), // Pushes content to the bottom

              // Duration Timer
              Text(
                'Duration: ${_formatDuration(_duration)}',
                style: const TextStyle(
                  color: kLightGreyColor,
                  fontSize: 28, // Was 24
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 20),

              // Legend
              _buildLegend(),
              const SizedBox(height: 20),

              // TERMINATE SESSION Button
              Padding(
                padding: const EdgeInsets.only(bottom: 40.0), // Bottom spacing
                child: SizedBox(
                  width: double.infinity, // Full width
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _terminateColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
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

  /// Helper widget to build the large percentage boxes
  Widget _buildEngagementBox(String percentage, Color backgroundColor, Color textColor) {
    return Container(
      height: 200, // Was 180
      width: double.infinity,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Center(
        child: Text(
          percentage,
          style: TextStyle(
            color: textColor,
            fontSize: 80,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  /// Helper widget to build the legend
  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLegendItem(kAccentColor, 'ENGAGED'),
        const SizedBox(width: 24),
        _buildLegendItem(kLightGreyColor, 'NOT ENGAGED'),
      ],
    );
  }

  /// Helper for individual legend items
  Widget _buildLegendItem(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4), // Slightly rounded square
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            color: kLightGreyColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }
}