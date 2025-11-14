import 'package:flutter/material.dart';
import 'about_us.dart';

class OverlayLogoButton extends StatelessWidget {
  const OverlayLogoButton({super.key});

  @override
  Widget build(BuildContext context) {
    // if we're already inside the AboutUsScreen, disable navigation
    final bool isOnAbout = context.findAncestorWidgetOfExactType<AboutUsScreen>() != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0, right: 16.0),
      child: SizedBox(
        width: 52,
        height: 52,
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            borderRadius: BorderRadius.circular(26),
            onTap: isOnAbout
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AboutUsScreen()),
                    );
                  },
            child: ClipOval(
              child: Image.asset(
                'assets/iskomate_logo.png',
                fit: BoxFit.cover,
                width: 52,
                height: 52,
              ),
            ),
          ),
        ),
      ),
    );
  }
}