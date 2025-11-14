import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Define the custom dark background and accent color
const Color kBackgroundColor = Color(0xFF232323);
const Color kAccentColor = Color(0xFFB71C1C); // A deep maroon/red
const Color kWhiteColor = Colors.white;

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  // Utility to set system UI colors
  void _setSystemUIOverlay() {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ));
  }

  @override
  Widget build(BuildContext context) {
    _setSystemUIOverlay(); // Apply the system UI styling

    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: SingleChildScrollView(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              // Logo above title
              Padding(
                padding: const EdgeInsets.only(top: 24.0, bottom: 12.0),
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/iskomate_logo.png',
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Title centered
              const Text(
                'About Us',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: kAccentColor,
                  fontSize: 50,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  shadows: [
                    Shadow(
                      color: kWhiteColor,
                      offset: Offset(0, 0),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Main Text Content (centered)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28.0),
                child: Column(
                  children: const [
                    Text(
                      'At IskoMate, we believe that every student\'s focus and well-being matter. Born from a vision to support learners in their academic journey, IskoMate uses intelligent technology to monitor engagement and promote a more attentive, meaningful learning experience.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: kWhiteColor,
                        fontSize: 16,
                        height: 1.6,
                      ),
                    ),
                    SizedBox(height: 18),
                    Text(
                      'Our system bridges innovation and education — analyzing real-time behavior through AI to help teachers understand when students are engaged or disengaged. By transforming data into insights, IskoMate empowers educators to adapt, improve, and create learning environments where no student is left behind.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: kWhiteColor,
                        fontSize: 16,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // Scrolling Image Placeholders (PageView)
              SizedBox(
                height: 200,
                child: PageView.builder(
                  controller: PageController(
                    viewportFraction: 0.7,
                    initialPage: 1000, // loopable
                  ),
                  itemBuilder: (context, index) {
                    final realIndex = index % 4;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0),
                      child: PlaceholderCard(index: realIndex),
                    );
                  },
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Custom Widget for the Image Placeholder Cards ---
class PlaceholderCard extends StatelessWidget {
  final int index;

  const PlaceholderCard({super.key, required this.index});

  @override
  Widget build(BuildContext context) {
    final Color cardColor = index % 2 == 0 ? kWhiteColor : kAccentColor;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Text(
          'Image $index',
          style: TextStyle(
            color: index % 2 == 0 ? Colors.black : kWhiteColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}