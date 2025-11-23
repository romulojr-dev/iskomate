import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:firebase_database/firebase_database.dart'; 
import 'package:firebase_core/firebase_core.dart'; // Needed for Firebase.app()

import 'theme.dart';
import 'start_session.dart';

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

class _SoloSessionScreenState extends State<SoloSessionScreen> {
  Timer? _timer;
  Duration _duration = Duration.zero;
  DateTime? _startTime; 

  // 1. Background Stream Subscription (No UI variables needed since we hide them)
  StreamSubscription<DatabaseEvent>? _statsSub;

  // 2. Variables for Saving Graph History
  int _lastSavedSecond = 0;
  final int _saveInterval = 5; // Save to Firestore every 5 seconds

  @override
  void initState() {
    super.initState();
    _setSystemUIOverlay();
    _startTimer();
    _startTime = DateTime.now();
    
    // Start collecting data for the graph (Invisible to user)
    _initRealtimeListener();
  }

  void _initRealtimeListener() {
    // Connect explicitly to the Asia Database
    final database = FirebaseDatabase.instanceFor(
      app: Firebase.app(), 
      databaseURL: 'https://iskomate-f149c-default-rtdb.asia-southeast1.firebasedatabase.app/'
    );
    
    // Listen to the data path
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

          // We DO NOT call setState here because we aren't updating the UI.
          // We just silently save the data for the graph.
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

    // Throttling: Only save every 5 seconds
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
          // We also update the "current" state, even if not shown here, 
          // so the session list shows the last known state.
          "engagement": {
            "highly_engaged": h,
            "barely_engaged": b,
            "engaged": e,
            "not_engaged": n,
          }
        });
        // debugPrint("Background Graph Point Saved: $currentSecond");
      } catch (error) {
        debugPrint("⚠️ Graph save error: $error");
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _statsSub?.cancel(); // Important: Stop listening
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _duration = Duration(seconds: _duration.inSeconds + 1);
        });
      }
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

  void _terminateSession() async {
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

  @override
  Widget build(BuildContext context) {
    final String formattedDuration = _formatDuration(_duration);

    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 60),

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

              const Spacer(),

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

              // Timer Display
              Text(
                formattedDuration,
                style: const TextStyle(
                  color: kLightGreyColor,
                  fontSize: 80,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 2.0,
                ),
              ),

              const Spacer(),

              // TERMINATE SESSION Button
              Padding(
                padding: const EdgeInsets.only(bottom: 40.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAccentColor, 
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
                    onPressed: _terminateSession,
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