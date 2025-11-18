import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore

import 'theme.dart';
import 'start_session.dart';

// --- Define Colors for the 4-Quadrant UI (Based on the image) ---
// Note: Assuming kBackgroundColor is defined in theme.dart
const Color _highlyEngagedColor = Color(0xFFB11212); // Deep Red (Top Left)
const Color _barelyEngagedColor = Color(0xFF8B3A3A); // Darker Red (Top Right)
const Color _engagedColor = Color(0xFFEBE0D2); // Cream/Beige (Bottom Left)
const Color _notEngagedColor = Color(0xFFFFFFFF); // White (Bottom Right)
const Color _terminateButtonColor = Color(0xFFB11212); // Termination button color from the image
const Color _darkTextColor = Color(0xFF332C2B); // Dark text color for light tiles


class ClassroomSessionScreen extends StatefulWidget {
  final String sessionName;
  final String sessionId; // Required to listen to the specific database entry

  const ClassroomSessionScreen({
    super.key,
    required this.sessionName,
    required this.sessionId,
  });

  @override
  State<ClassroomSessionScreen> createState() => _ClassroomSessionScreenState();
}

class _ClassroomSessionScreenState extends State<ClassroomSessionScreen> {
  Timer? _timer;
  Duration _duration = Duration.zero;
  final Color _terminateColor = const Color(0xFF8D333C); // Keeping your original terminate color definition

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

  void _handleTerminate() async {
    _timer?.cancel();

    // Update status to 'ended' in Firebase so the laptop knows to stop
    await FirebaseFirestore.instance
        .collection('sessions')
        .doc(widget.sessionId)
        .update({'status': 'ended'});

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const SessionSetupScreen()),
      (route) => false,
    );
  }

  // --- Widget for the individual percentage tile (2x2 grid) ---
  Widget _buildPercentageTile(BuildContext context, String percentage, Color color, Color textColor) {
    return Expanded(
      child: Container(
        // Set height to be roughly square
        height: MediaQuery.of(context).size.width / 2 - 30,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
          // Add border for light tiles
          border: color == _engagedColor || color == _notEngagedColor
              ? Border.all(color: Colors.white10, width: 1.0)
              : null,
        ),
        child: Center(
          child: Text(
            percentage,
            style: TextStyle(
              color: textColor,
              fontSize: 60,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  // --- Widget for a single legend item ---
  Widget _buildLegendItem(Color color, String label, {bool hasBorder = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            border: hasBorder
                ? Border.all(color: Colors.white, width: 1.0)
                : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
          ),
        ),
      ],
    );
  }


  @override
  Widget build(BuildContext context) {
    // This is the combined legend logic for the 4 items, now aligned
    Widget buildLegend() {
      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Left column of legends
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: IntrinsicWidth(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, // Align text to the start
                      children: [
                        _buildLegendItem(_highlyEngagedColor, 'HIGHLY ENGAGED'),
                        const SizedBox(height: 8),
                        _buildLegendItem(_engagedColor, 'ENGAGED', hasBorder: true),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20), // Space between the two legend columns
              // Right column of legends
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: IntrinsicWidth(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, // Align text to the start
                      children: [
                        _buildLegendItem(_barelyEngagedColor, 'BARELY ENGAGED'),
                        const SizedBox(height: 8),
                        _buildLegendItem(_notEngagedColor, 'NOT ENGAGED', hasBorder: true),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: kBackgroundColor, // Set background color using kBackgroundColor
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 40),

                // HEADER: CAO: BSCPE 4-1
                const Text(
                  'CAO: BSCPE 4-1', // Hardcoded as per the image
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 24),

                // --- REAL-TIME DATA SECTION (4-Quadrant Grid) ---
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('sessions')
                      .doc(widget.sessionId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    // Default values
                    String highlyEngagedText = "0%";
                    String barelyEngagedText = "0%";
                    String engagedText = "0%";
                    String notEngagedText = "0%";

                    if (snapshot.hasData && snapshot.data!.exists) {
                      var data = snapshot.data!.data() as Map<String, dynamic>;

                      if (data['graph_data'] != null && (data['graph_data'] as List).isNotEmpty) {
                        List<dynamic> graphList = data['graph_data'];
                        var latestPoint = graphList.last;

                        // Assumed structure: Read the four percentages from the latest point
                        int highlyEngaged = (latestPoint['highly_engaged'] as num?)?.toInt() ?? 0;
                        int barelyEngaged = (latestPoint['barely_engaged'] as num?)?.toInt() ?? 0;
                        int engaged = (latestPoint['engaged'] as num?)?.toInt() ?? 0;
                        int notEngaged = (latestPoint['not_engaged'] as num?)?.toInt() ?? 0;

                        highlyEngagedText = "$highlyEngaged%";
                        barelyEngagedText = "$barelyEngaged%";
                        engagedText = "$engaged%";
                        notEngagedText = "$notEngaged%";
                      }
                    }

                    return Column(
                      children: [
                        // Top Row: Highly Engaged & Barely Engaged
                        Row(
                          children: [
                            _buildPercentageTile(context, highlyEngagedText, _highlyEngagedColor, Colors.white),
                            _buildPercentageTile(context, barelyEngagedText, _barelyEngagedColor, Colors.white),
                          ],
                        ),
                        // Bottom Row: Engaged & Not Engaged
                        Row(
                          children: [
                            _buildPercentageTile(context, engagedText, _engagedColor, _darkTextColor),
                            _buildPercentageTile(context, notEngagedText, _notEngagedColor, _darkTextColor),
                          ],
                        ),
                      ],
                    );
                  },
                ),
                // --- END REAL-TIME DATA ---

                const SizedBox(height: 24),

                // Duration Timer
                Text(
                  'Duration: ${_formatDuration(_duration)}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 24),

                // Legends
                buildLegend(),

                const SizedBox(height: 32),

                // Terminate Button
                Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _terminateButtonColor,
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
      ),
    );
  }
}