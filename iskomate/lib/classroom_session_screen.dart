import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:firebase_database/firebase_database.dart'; 
import 'package:firebase_core/firebase_core.dart'; 

import 'theme.dart';
import 'start_session.dart';

// --- Colors ---
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
  
  // Stream Subscription to handle data and saving logic
  StreamSubscription<DatabaseEvent>? _statsSub;

  // Local state for UI
  String _highlyText = "0%";
  String _barelyText = "0%";
  String _engagedText = "0%";
  String _notText = "0%";

  // Variables for Graph Saving
  int _lastSavedSecond = 0;
  final int _saveInterval = 5; // Save to graph every 5 seconds

  @override
  void initState() {
    super.initState();
    _setSystemUIOverlay();
    _startTimer();
    _startTime = DateTime.now(); 
    
    _initRealtimeListener();
  }

  void _initRealtimeListener() {
    // 1. Connect to Asia Database
    final database = FirebaseDatabase.instanceFor(
      app: Firebase.app(), 
      databaseURL: 'https://iskomate-f149c-default-rtdb.asia-southeast1.firebasedatabase.app/'
    );
    
    // 2. Listen to the stream
    _statsSub = database.ref('aiResult/engagement_stats').onValue.listen((event) {
      if (event.snapshot.value != null) {
        try {
          final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);

          // Helper to get double values safely
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

          // 3. Update UI (setState is safe here)
          if (mounted) {
            setState(() {
              _highlyText = "${highly.round()}%";
              _barelyText = "${barely.round()}%";
              _engagedText = "${engaged.round()}%";
              _notText = "${not.round()}%";
            });
          }

          // 4. Save to Firestore Graph (Throttled)
          _saveToGraph(highly, barely, engaged, not);

        } catch (e) {
          debugPrint("❌ PARSING ERROR: $e");
        }
      }
    });
  }

  // 💡 This function saves points for the graph
  void _saveToGraph(double h, double b, double e, double n) async {
    final currentSecond = _duration.inSeconds;

    // Only save if enough time has passed (e.g., every 5 seconds)
    if (currentSecond - _lastSavedSecond >= _saveInterval) {
      _lastSavedSecond = currentSecond;

      // Create the graph point
      final graphPoint = {
        "time_index": currentSecond, // X-Axis
        "highly_engaged": h,
        "barely_engaged": b,
        "engaged": e,
        "not_engaged": n,
      };

      // Append to Firestore 'graph_data' array
      try {
        await FirebaseFirestore.instance
            .collection('sessions')
            .doc(widget.sessionId)
            .update({
          "graph_data": FieldValue.arrayUnion([graphPoint]),
          // Also update current snapshot for session list previews
          "engagement": {
            "highly_engaged": h,
            "barely_engaged": b,
            "engaged": e,
            "not_engaged": n,
          }
        });
        debugPrint("📈 Graph point saved at ${currentSecond}s");
      } catch (error) {
        debugPrint("⚠️ Failed to save graph point: $error");
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _statsSub?.cancel(); // Important: Stop listening when screen closes
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
    _statsSub?.cancel(); // Stop recording

    final endTime = DateTime.now();
    String formattedDuration = _formatDuration(_duration);

    await FirebaseFirestore.instance
        .collection('sessions')
        .doc(widget.sessionId)
        .update({
          'status': 'ended',
          'duration': formattedDuration,
          'ended_at': endTime.toIso8601String(),
        });

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const SessionSetupScreen()),
      (route) => false,
    );
  }

  // --- Widget for Percentage Tile ---
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
              fontSize: 50, 
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  // --- Widget for Legend Item ---
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
                Text(
                  widget.sessionName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 24),

                // 4-Quadrant Grid (Uses local state variables updated by listener)
                Column(
                  children: [
                    Row(
                      children: [
                        _buildPercentageTile(context, _highlyText, _highlyEngagedColor, Colors.white),
                        _buildPercentageTile(context, _barelyText, _barelyEngagedColor, Colors.white),
                      ],
                    ),
                    Row(
                      children: [
                        _buildPercentageTile(context, _engagedText, _engagedColor, _darkTextColor),
                        _buildPercentageTile(context, _notText, _notEngagedColor, _darkTextColor),
                      ],
                    ),
                  ],
                ),
                
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