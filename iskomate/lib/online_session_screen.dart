import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore

import 'theme.dart';
import 'start_session.dart';

class OnlineSessionScreen extends StatefulWidget {
  final String sessionName;
  final String sessionId; // Required to listen to the specific database entry

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
  final Color _terminateColor = const Color(0xFF8D333C);

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

    // Update status to 'ended'
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 60),

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

              // --- REAL-TIME DATA SECTION ---
              Expanded(
                child: StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('sessions')
                      .doc(widget.sessionId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    String engagedText = "0%";
                    String notEngagedText = "0%";

                    if (snapshot.hasData && snapshot.data!.exists) {
                      var data = snapshot.data!.data() as Map<String, dynamic>;

                      if (data['graph_data'] != null && (data['graph_data'] as List).isNotEmpty) {
                        List<dynamic> graphList = data['graph_data'];
                        var latestPoint = graphList.last;

                        int engaged = (latestPoint['engaged'] as num).toInt();
                        int notEngaged = latestPoint['not_engaged'] != null 
                            ? (latestPoint['not_engaged'] as num).toInt() 
                            : (100 - engaged);

                        engagedText = "$engaged%";
                        notEngagedText = "$notEngaged%";
                      }
                    }

                    return Column(
                      children: [
                        _buildEngagementBox(
                          engagedText,
                          kAccentColor,
                          Colors.white,
                        ),
                        const SizedBox(height: 16),
                        _buildEngagementBox(
                          notEngagedText,
                          kLightGreyColor,
                          kBackgroundColor,
                        ),
                      ],
                    );
                  },
                ),
              ),
              // --- END REAL-TIME DATA ---

              Text(
                'Duration: ${_formatDuration(_duration)}',
                style: const TextStyle(
                  color: kLightGreyColor,
                  fontSize: 28,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 20),

              _buildLegend(),
              const SizedBox(height: 20),

              Padding(
                padding: const EdgeInsets.only(bottom: 40.0),
                child: SizedBox(
                  width: double.infinity,
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

  Widget _buildEngagementBox(String percentage, Color backgroundColor, Color textColor) {
    return Container(
      height: 200,
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

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
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