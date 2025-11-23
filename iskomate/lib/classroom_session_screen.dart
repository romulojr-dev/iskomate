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

  // --- ADDED: cached percentage strings + numeric values + subscription
  String _highlyPct = '0%';
  String _barelyPct  = '0%';
  String _engagedPct = '0%';
  String _notPct     = '0%';
  double _highlyVal = 0.0;
  double _barelyVal = 0.0;
  double _engagedVal = 0.0;
  double _notVal = 0.0;
  StreamSubscription<DatabaseEvent>? _aiSub;

  @override
  void initState() {
    super.initState();
    _setSystemUIOverlay();
    _startTimer();
    _startTime = DateTime.now();

    // ADDED: listen RTDB, update UI and Firestore (merge)
    _aiSub = _aiRef.onValue.listen((DatabaseEvent event) {
      final raw = event.snapshot.value;
      debugPrint('RTDB event raw: $raw');
      if (raw != null && raw is Map) {
        double toDouble(dynamic v) {
          if (v == null) return 0.0;
          if (v is num) return v.toDouble();
          return double.tryParse(v.toString()) ?? 0.0;
        }

        final he = toDouble(raw['highly_engaged']);
        final be = toDouble(raw['barely_engaged']);
        final e  = toDouble(raw['engaged']);
        final ne = toDouble(raw['not_engaged']);

        setState(() {
          _highlyVal = he;
          _barelyVal = be;
          _engagedVal = e;
          _notVal = ne;
          _highlyPct = '${he.round()}%';
          _barelyPct = '${be.round()}%';
          _engagedPct = '${e.round()}%';
          _notPct = '${ne.round()}%';
        });

        // write engagement snapshot into the session document (merge so it doesn't overwrite other fields)
        FirebaseFirestore.instance
            .collection('sessions')
            .doc(widget.sessionId)
            .set({
              'engagement': {
                'highly_engaged': he,
                'barely_engaged': be,
                'engaged': e,
                'not_engaged': ne,
              },
              'last_update': DateTime.now().toIso8601String(),
              'status': 'ongoing',
            }, SetOptions(merge: true)).catchError((err) {
              debugPrint('Firestore write error: $err');
            });
      } else {
        debugPrint('RTDB payload null or not a Map');
      }
    }, onError: (err) {
      debugPrint('RTDB listen error: $err');
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _aiSub?.cancel(); // ADDED
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

    // compute formatted duration and save to Firestore along with final engagement snapshot
    final endTime = DateTime.now();
    final duration = endTime.difference(_startTime ?? endTime);
    String formattedDuration = [
      duration.inHours.toString().padLeft(2, '0'),
      (duration.inMinutes % 60).toString().padLeft(2, '0'),
      (duration.inSeconds % 60).toString().padLeft(2, '0'),
    ].join(':');

    await FirebaseFirestore.instance
        .collection('sessions')
        .doc(widget.sessionId)
        .set({
          'status': 'ended',
          'duration': formattedDuration,
          'engagement': {
            'highly_engaged': _highlyVal,
            'barely_engaged': _barelyVal,
            'engaged': _engagedVal,
            'not_engaged': _notVal,
          },
          'ended_at': endTime.toIso8601String(),
        }, SetOptions(merge: true));

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
                
                // HEADER - show the session name passed from start screen
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

                // --- REAL-TIME DATA STREAM ---
                // REPLACED StreamBuilder with cached values driven by listener
                Column(
                  children: [
                    Row(
                      children: [
                        _buildPercentageTile(context, _highlyPct, _highlyEngagedColor, Colors.white),
                        _buildPercentageTile(context, _barelyPct, _barelyEngagedColor, Colors.white),
                      ],
                    ),
                    Row(
                      children: [
                        _buildPercentageTile(context, _engagedPct, _engagedColor, _darkTextColor),
                        _buildPercentageTile(context, _notPct, _notEngagedColor, _darkTextColor),
                      ],
                    ),
                  ],
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