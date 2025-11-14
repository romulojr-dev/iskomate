import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

// 1. IMPORT the screen you want to navigate to
import 'provision_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _letterTimer;
  int _activeLetterIndex = -1;
  final String _title = 'ISKOMATE';
  late final List<String> _letters;

  @override
  void initState() {
    super.initState();
    _letters = _title.split('');
    _setSystemUIOverlay();
    _startLetterAnimation();
    _navigateToHome();
  }

  // Sets the status bar/navigation bar color to match the splash background
  void _setSystemUIOverlay() {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF232323),
      systemNavigationBarIconBrightness: Brightness.light,
    ));
  }

  void _startLetterAnimation() {
    // change active letter every 250ms
    _letterTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;
      setState(() {
        _activeLetterIndex = (_activeLetterIndex + 1) % _letters.length;
      });
    });
  }

  _navigateToHome() async {
    // Wait for 8 seconds before navigating
    await Future.delayed(const Duration(milliseconds: 8000));
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ProvisionScreen()),
      );
    }
  }

  @override
  void dispose() {
    _letterTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const baseStyle = TextStyle(
      color: Colors.white,
      fontSize: 32,
      fontWeight: FontWeight.bold,
      letterSpacing: 2,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF232323),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // 5. Display the logo image
            Image(
              image: const AssetImage('assets/iskomate_logo.png'),
              width: 300,
              height: 300,
            ),
            const SizedBox(height: 8), // reduced gap to move text upward
            // Animated title where letters highlight one-by-one
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(_letters.length, (i) {
                final bool active = i == _activeLetterIndex;
                return AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: active ? 1.0 : 0.6,
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 200),
                    scale: active ? 1.05 : 1.0,
                    child: Text(
                      _letters[i],
                      style: baseStyle.copyWith(
                        color: active ? Colors.white : Colors.white70,
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),
            // optional subtle subtitle or empty spacer (removed dots)
          ],
        ),
      ),
    );
  }
}
