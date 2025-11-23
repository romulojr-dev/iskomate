import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:firebase_database/firebase_database.dart'; // Required for Realtime DB

import 'theme.dart';
import 'start_session.dart';

// --- Colors (Kept the same) ---
const Color _highlyEngagedColor = Color(0xFFB11212);
const Color _barelyEngagedColor = Color(0xFF8B3A3A);
const Color _engagedColor = Color(0xFFEBE0D2);
const Color _notEngagedColor = Color(0xFFFFFFFF);
const Color _terminateButtonColor = Color(0xFFB11212);
const Color _darkTextColor = Color(0xFF332C2B);

class ClassroomSessionScreen extends StatefulWidget {
  final String sessionName;
  final String sessionId;

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
  DateTime? _startTime;
  
  // 💡 Reference to Realtime Database where Pi sends data
  final DatabaseReference _aiRef = FirebaseDatabase.instance.ref('aiResult/engagement_stats');

  @override
  void initState() {
    super.initState();
    _setSystemUIOverlay();
    _startTimer();
    _startTime = DateTime.now(); 
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
  
  void _setSystemUIOverlay() {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: kBackgroundColor,
      systemNavigationBarIconBrightness: Brightness.light,
    ));
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_startTime != null) {
          _duration = DateTime.now().difference(_startTime!);
        } else {
          _duration = _duration + const Duration(seconds: 1);
        }
      });
    });
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  void _handleTerminate() async {
    _timer?.cancel();
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

  // --- Widget for the individual percentage tile (Unchanged) ---
  Widget _buildPercentageTile(BuildContext context, String percentage, Color color, Color textColor) {
    return Expanded(
      child: Container(
        height: MediaQuery.of(context).size.width / 2 - 30,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
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

  // --- Widget for a single legend item (Unchanged) ---
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
    Widget buildLegend() {
      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: IntrinsicWidth(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLegendItem(_highlyEngagedColor, 'HIGHLY ENGAGED'),
                        const SizedBox(height: 8),
                        _buildLegendItem(_engagedColor, 'ENGAGED', hasBorder: true),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: IntrinsicWidth(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
      backgroundColor: kBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                
                // HEADER
                const Text(
                  'CAO: BSCPE 4-1',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 24),

                // --- REAL-TIME DATA STREAM ---
                // This widget listens to Firebase changes automatically
                StreamBuilder<DatabaseEvent>(
                  stream: _aiRef.onValue, 
                  builder: (context, snapshot) {
                    
                    // Default values (0%)
                    String highly = "0%";
                    String barely = "0%";
                    String engaged = "0%";
                    String notEngaged = "0%";

                    // If we have data from the Pi
                    if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
                      try {
                        final data = Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);
                        
                        // Get values and round them to whole numbers
                        highly = "${(data['highly_engaged'] ?? 0).round()}%";
                        barely = "${(data['barely_engaged'] ?? 0).round()}%";
                        engaged = "${(data['engaged'] ?? 0).round()}%";
                        notEngaged = "${(data['not_engaged'] ?? 0).round()}%";
                        
                      } catch (e) {
                        debugPrint("Data Parse Error: $e");
                      }
                    }

                    // Build the 4-Quadrant Grid with real values
                    return Column(
                      children: [
                        Row(
                          children: [
                            _buildPercentageTile(context, highly, _highlyEngagedColor, Colors.white),
                            _buildPercentageTile(context, barely, _barelyEngagedColor, Colors.white),
                          ],
                        ),
                        Row(
                          children: [
                            _buildPercentageTile(context, engaged, _engagedColor, _darkTextColor),
                            _buildPercentageTile(context, notEngaged, _notEngagedColor, _darkTextColor),
                          ],
                        ),
                      ],
                    );
                  },
                ),
                // --- END STREAM ---

                const SizedBox(height: 24),
                Text(
                  'Duration: ${_formatDuration(_duration)}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 24),
                buildLegend(),
                const SizedBox(height: 32),
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