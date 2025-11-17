// active_session.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';

class ActiveSessionScreen extends StatelessWidget {
  final String sessionName;
  final String deviceName;
  final String deviceIp;
  final bool isSolo;
  final int engagedPercent;

  const ActiveSessionScreen({
    super.key,
    required this.sessionName,
    required this.deviceName,
    this.deviceIp = '',
    this.isSolo = true,
    this.engagedPercent = 92,
  });

  void _setSystemUIOverlay() {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ));
  }

  @override
  Widget build(BuildContext context) {
    _setSystemUIOverlay();

    // <-- REMOVED the unused 'streamUrl' variable
    // We don't need it on this screen.

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
        title: Text(sessionName, style: const TextStyle(color: kWhiteColor, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            children: [
              const SizedBox(height: 18),
              Text(
                '${engagedPercent}%',
                style: const TextStyle(
                  color: kWhiteColor,
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text('ENGAGED', style: TextStyle(color: kWhiteColor, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Duration: 00:00:00', style: TextStyle(color: kLightGreyColor, fontSize: 12)),
              const SizedBox(height: 16),

              // Graph container
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F1F1F),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12.0, bottom: 8.0, left: 12.0, right: 8.0),
                    child: Column(
                      children: [
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Graph drawing area
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 8.0, bottom: 8.0),
                                  child: CustomPaint(
                                    size: Size.infinite,
                                    painter: _ActiveSessionGraphPainter(),
                                  ),
                                ),
                              ),

                              // Percentage column
                              SizedBox(
                                width: 54,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: const [
                                    Text('100%', style: TextStyle(color: kLightGreyColor, fontSize: 12)),
                                    Text('75%', style: TextStyle(color: kLightGreyColor, fontSize: 12)),
                                    Text('50%', style: TextStyle(color: kLightGreyColor, fontSize: 12)),
                                    Text('25%', style: TextStyle(color: kLightGreyColor, fontSize: 12)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // X-axis labels
                        Padding(
                          padding: const EdgeInsets.only(left: 4.0, right: 54.0, top: 6.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Text('Hour', style: TextStyle(color: kLightGreyColor, fontSize: 12)),
                              Text('Hour', style: TextStyle(color: kLightGreyColor, fontSize: 12)),
                              Text('Hour', style: TextStyle(color: kLightGreyColor, fontSize: 12)),
                              Text('Hour', style: TextStyle(color: kLightGreyColor, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Legend only (eye button removed)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  _LegendItem(color: kAccentColor, text: 'ENGAGED'),
                  SizedBox(width: 18),
                  _LegendItem(color: kWhiteColor, text: 'NOT ENGAGED'),
                ],
              ),

              const SizedBox(height: 18),

              // End Session Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kAccentColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
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
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: kWhiteColor.withOpacity(0.12)),
          ),
        ),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(color: kWhiteColor, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _ActiveSessionGraphPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final engagedPaint = Paint()
      ..color = kAccentColor
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    final notEngagedPaint = Paint()
      ..color = kWhiteColor
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    final gridPaint = Paint()..color = kWhiteColor.withOpacity(0.06);
    for (int i = 0; i <= 4; i++) {
      final y = size.height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final engagedPath = Path()
      ..moveTo(0, size.height * 0.75)
      ..cubicTo(size.width * 0.12, size.height * 0.6, size.width * 0.28, size.height * 0.9, size.width * 0.40, size.height * 0.6)
      ..cubicTo(size.width * 0.52, size.height * 0.45, size.width * 0.68, size.height * 0.7, size.width * 0.82, size.height * 0.35)
      ..lineTo(size.width, size.height * 0.2);

    final notEngagedPath = Path()
      ..moveTo(0, size.height * 0.6)
      ..cubicTo(size.width * 0.12, size.height * 0.3, size.width * 0.28, size.height * 0.45, size.width * 0.40, size.height * 0.5)
      ..cubicTo(size.width * 0.52, size.height * 0.55, size.width * 0.68, size.height * 0.35, size.width * 0.82, size.height * 0.7)
      ..lineTo(size.width, size.height * 0.8);

    canvas.drawPath(notEngagedPath, notEngagedPaint);
    canvas.drawPath(engagedPath, engagedPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// --- ALL VIDEOPOPUP WIDGETS REMOVED ---
// They were for a different video player and are not needed here.