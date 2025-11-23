import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:firebase_database/firebase_database.dart'; 
import 'package:firebase_core/firebase_core.dart'; // Needed for Firebase.app()

import 'theme.dart';
import 'start_session.dart';

// --- Define Colors ---
const Color _highlyEngagedColor = Color(0xFFB11212);
const Color _barelyEngagedColor = Color(0xFF8B3A3A);
const Color _engagedColor = Color(0xFFEBE0D2);
const Color _notEngagedColor = Color(0xFFFFFFFF);
const Color _terminateButtonColor = Color(0xFFB11212);
const Color _darkTextColor = Color(0xFF332C2B);

class OnlineSessionScreen extends StatefulWidget {
  final String sessionName;
  final String sessionId;

  const OnlineSessionScreen({
    super.key,
    required this.sessionName,
    required this.sessionId,
  });

  @override
  State<OnlineSessionScreen> createState() => _OnlineSessionScreenState();
}

class _OnlineSessionScreenState extends State<OnlineSessionScreen> {
  Timer? _timer;
  Duration _duration = Duration.zero;
  DateTime? _startTime;

  // 1. Stream Subscription for Realtime Data
  StreamSubscription<DatabaseEvent>? _statsSub;

  // 2. Local State for UI (The Percentages)
  String _highlyText = "0%";
  String _barelyText = "0%";
  String _engagedText = "0%";
  String _notText = "0%";

  // 3. Variables for Saving Graph History
  int _lastSavedSecond = 0;
  final int _saveInterval = 5; // Save to Firestore every 5 seconds

  @override
  void initState() {
    super.initState();
    _setSystemUIOverlay();
    _startTimer();
    _startTime = DateTime.now(); 
    
    // Start listening to the Raspberry Pi data
    _initRealtimeListener();
  }

  void _initRealtimeListener() {
    // Connect explicitly to the Asia Database
    final database = FirebaseDatabase.instanceFor(
      app: Firebase.app(), 
      databaseURL: 'https://iskomate-f149c-default-rtdb.asia-southeast1.firebasedatabase.app/'
    );
    
    // Listen to the correct path
    _statsSub = database.ref('aiResult/engagement_stats').onValue.listen((event) {
      if (event.snapshot.value != null) {
        try {
          final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);

          // Helper to safely parse numbers
          double getVal(dynamic val) {
             if (val == null) return 0.0;
             if (val is int) return val.toDouble();
             if (val is double) return val;
             return double.tryParse(val.toString()) ?? 0.0;
          }

          double highly = getVal(data['highly_engaged']);
          double barely = getVal(data['barely_engaged']);
          double engaged = getVal(data['engaged']);
          double not = getVal(data['not_engaged']);

          // Update the Screen
          if (mounted) {
            setState(() {
              _highlyText = "${highly.round()}%";
              _barelyText = "${barely.round()}%";
              _engagedText = "${engaged.round()}%";
              _notText = "${not.round()}%";
            });
          }

          // Save to Firestore for the Graph
          _saveToGraph(highly, barely, engaged, not);

        } catch (e) {
          debugPrint("❌ PARSING ERROR: $e");
        }
      }
    });
  }

  // Logic to save history for ViewSessionScreen graph
  void _saveToGraph(double h, double b, double e, double n) async {
    final currentSecond = _duration.inSeconds;

    // Throttling: Only save every few seconds to save bandwidth
    if (currentSecond - _lastSavedSecond >= _saveInterval) {
      _lastSavedSecond = currentSecond;

      final graphPoint = {
        "time_index": currentSecond,
        "highly_engaged": h,
        "barely_engaged": b,
        "engaged": e,
        "not_engaged": n,
      };

      try {
        await FirebaseFirestore.instance
            .collection('sessions')
            .doc(widget.sessionId)
            .update({
          "graph_data": FieldValue.arrayUnion([graphPoint]),
          // Also update current values for the list preview
          "engagement": {
            "highly_engaged": h,
            "barely_engaged": b,
            "engaged": e,
            "not_engaged": n,
          }
        });
      } catch (error) {
        debugPrint("⚠️ Graph save error: $error");
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _statsSub?.cancel(); // Stop listening when we leave
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
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
    _statsSub?.cancel(); // Stop recording

    final endTime = DateTime.now();
    
    await FirebaseFirestore.instance
        .collection('sessions')
        .doc(widget.sessionId)
        .update({
          'status': 'ended',
          'duration': _formatDuration(_duration),
          'ended_at': endTime.toIso8601String(),
        });

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const SessionSetupScreen()),
      (route) => false,
    );
  }

  // --- Widget for the percentage tile ---
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

                // HEADER: CAO: BSCPE 4-1
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

                // --- REAL-TIME DATA SECTION (4-Quadrant Grid) ---
                Column(
                  children: [
                    // Top Row
                    Row(
                      children: [
                        _buildPercentageTile(context, _highlyText, _highlyEngagedColor, Colors.white),
                        _buildPercentageTile(context, _barelyText, _barelyEngagedColor, Colors.white),
                      ],
                    ),
                    // Bottom Row
                    Row(
                      children: [
                        _buildPercentageTile(context, _engagedText, _engagedColor, _darkTextColor),
                        _buildPercentageTile(context, _notText, _notEngagedColor, _darkTextColor),
                      ],
                    ),
                  ],
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