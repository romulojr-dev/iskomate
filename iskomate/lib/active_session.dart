import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'theme.dart'; // Assuming this contains your kAccentColor, kBackgroundColor, etc.

class ActiveSessionScreen extends StatefulWidget {
  final String sessionName;
  final String deviceName;
  final String deviceIp; // This is the Laptop IP
  final bool isSolo;

  const ActiveSessionScreen({
    super.key,
    required this.sessionName,
    required this.deviceName,
    required this.deviceIp,
    this.isSolo = true,
  });

  @override
  State<ActiveSessionScreen> createState() => _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends State<ActiveSessionScreen> {
  // Socket & Data
  WebSocketChannel? _channel;
  
  // Current values for text display
  double _currentEngagedVal = 0.0;
  
  // History lists for the Graph
  final List<double> _engagedHistory = []; 
  final List<double> _notEngagedHistory = [];
  
  final int _maxGraphPoints = 50; // Keep 50 points (approx 5 seconds at 0.1s interval)

  // Timer for duration
  Timer? _timer;
  int _secondsElapsed = 0;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _connectToDataStream();
    _setSystemUIOverlay();
  }

  void _setSystemUIOverlay() {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ));
  }

  // --- 1. CONNECT TO LAPTOP SERVER ---
  void _connectToDataStream() {
    // Updated Port to 8766 to match your laptop_server.py
    final url = 'ws://${widget.deviceIp}:8766'; 
    debugPrint("Connecting to AI Analysis Stream: $url");
    
    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      _channel!.stream.listen((message) {
        try {
          final data = jsonDecode(message);

          // Check status from server
          if (data['status'] == 'ACTIVE') {
            // Parse values (server sends floats like 85.5)
            double engaged = (data['engaged_percent'] as num).toDouble();
            double notEngaged = (data['not_engaged_percent'] as num).toDouble();
            
            _updateGraph(engaged, notEngaged);
          } 
          // You can handle "WAITING_FOR_VIDEO" here if you want specific UI logic
        } catch (e) {
          debugPrint("JSON Parse Error: $e");
        }
      }, onError: (err) {
        debugPrint("Data Stream Error: $err");
      });
    } catch (e) {
      debugPrint("Connection failed: $e");
    }
  }

  // --- 2. UPDATE GRAPH LOGIC ---
  void _updateGraph(double engaged, double notEngaged) {
    if (!mounted) return;
    setState(() {
      _currentEngagedVal = engaged;

      _engagedHistory.add(engaged);
      _notEngagedHistory.add(notEngaged);

      // Keep list size fixed so graph scrolls
      if (_engagedHistory.length > _maxGraphPoints) {
        _engagedHistory.removeAt(0);
        _notEngagedHistory.removeAt(0);
      }
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _secondsElapsed++;
        });
      }
    });
  }

  String _formatDuration(int seconds) {
    final h = (seconds ~/ 3600).toString().padLeft(2, '0');
    final m = ((seconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return "$h:$m:$s";
  }

  @override
  void dispose() {
    _channel?.sink.close();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Round the current value for the big display
    int displayPercentage = _currentEngagedVal.round();

    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: kBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: kWhiteColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: Text(widget.sessionName, style: const TextStyle(color: kWhiteColor, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            children: [
              const SizedBox(height: 18),
              
              // --- DYNAMIC PERCENTAGE (ENGAGED) ---
              Text(
                '$displayPercentage%',
                style: const TextStyle(
                  color: kWhiteColor,
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text('ENGAGEMENT LEVEL', style: TextStyle(color: kWhiteColor, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Duration: ${_formatDuration(_secondsElapsed)}', style: const TextStyle(color: kLightGreyColor, fontSize: 12)),
              const SizedBox(height: 16),

              // --- DUAL LINE GRAPH ---
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F1F1F),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: MultiLineGraphPainter(
                        engagedData: _engagedHistory,
                        notEngagedData: _notEngagedHistory,
                        max: 100,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),
              
              // --- UPDATED LEGEND ---
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  // Engaged = Accent Color
                  _LegendItem(color: kAccentColor, text: 'ENGAGED'),
                  SizedBox(width: 18),
                  // Not Engaged = White (or Red, depending on preference)
                  _LegendItem(color: kWhiteColor, text: 'NOT ENGAGED'),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kAccentColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('END SESSION', style: TextStyle(color: kWhiteColor, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String text;
  const _LegendItem({required this.color, required this.text, super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(color: kWhiteColor, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

// --- UPDATED PAINTER FOR TWO LINES ---
class MultiLineGraphPainter extends CustomPainter {
  final List<double> engagedData;
  final List<double> notEngagedData;
  final double max;

  MultiLineGraphPainter({
    required this.engagedData,
    required this.notEngagedData,
    required this.max,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw Grid
    final gridPaint = Paint()
      ..color = kWhiteColor.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (int i = 0; i <= 4; i++) {
      final y = size.height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (engagedData.isEmpty) return;

    // 2. Draw Engaged Line (Accent Color)
    final engagedPaint = Paint()
      ..color = kAccentColor
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // 3. Draw Not Engaged Line (White Color - to match Legend)
    final notEngagedPaint = Paint()
      ..color = kWhiteColor.withOpacity(0.8)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final stepX = size.width / (engagedData.length > 1 ? engagedData.length - 1 : 1);

    // Helper to draw a path from a list of data
    void drawPath(List<double> data, Paint paint) {
      final path = Path();
      for (int i = 0; i < data.length; i++) {
        final value = (data[i] / max).clamp(0.0, 1.0);
        final y = size.height - (value * size.height);
        final x = i * stepX;

        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, paint);
    }

    // Draw both paths
    drawPath(notEngagedData, notEngagedPaint); // Draw "Not Engaged" behind
    drawPath(engagedData, engagedPaint);       // Draw "Engaged" on top
  }

  @override
  bool shouldRepaint(covariant MultiLineGraphPainter oldDelegate) {
    return oldDelegate.engagedData != engagedData || 
           oldDelegate.notEngagedData != notEngagedData;
  }
}