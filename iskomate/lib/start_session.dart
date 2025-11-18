import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:iskomate/video.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore

import 'overlay_logo.dart';
import 'theme.dart';
import 'provision_screen.dart';
import 'solo_session_screen.dart';
import 'classroom_session_screen.dart';
import 'online_session_screen.dart';
import 'select_session_screen.dart';
import 'list_sessions_screen.dart';

enum SessionMode { solo, classroom, online }

class SessionSetupScreen extends StatefulWidget {
  final String? selectedDeviceName;

  const SessionSetupScreen({super.key, this.selectedDeviceName});

  @override
  State<SessionSetupScreen> createState() => _SessionSetupScreenState();
}

class _SessionSetupScreenState extends State<SessionSetupScreen> {
  SessionMode _selectedMode = SessionMode.solo;
  final TextEditingController _sessionNameController = TextEditingController();
  String? _selectedSessionName;
  bool _isLoading = false; // Add loading state

  @override
  void initState() {
    super.initState();
    _setSystemUIOverlay();
  }

  @override
  void dispose() {
    _sessionNameController.dispose();
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

  Future<void> _disconnectDevice() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('selectedDeviceName');
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const ProvisionScreen()),
      (route) => false,
    );
  }

  void _onSelectSessionPressed() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const SelectSessionScreen()),
    );
    if (result != null) {
      setState(() {
        _selectedSessionName = result;
      });
    }
  }

  // --- MODIFIED START LOGIC ---
  Future<void> _onStartPressed() async {
    setState(() => _isLoading = true);

    Widget nextScreen;
    if (_selectedMode == SessionMode.solo) {
      final sessionName = _sessionNameController.text.trim().isEmpty
          ? 'Session ${DateTime.now().millisecondsSinceEpoch}'
          : _sessionNameController.text.trim();

      // Add to Firestore
      final docRef = await FirebaseFirestore.instance.collection('sessions').add({
        'name': sessionName,
        'date': DateTime.now().toIso8601String(),
        'mode': 'solo',
        'students': [],
        'duration': "00:00:00",
        // Add other fields as needed
      });

      nextScreen = SoloSessionScreen(sessionName: sessionName, sessionId: docRef.id);
    } else {
      // Classroom/Online: use the selected session, DO NOT create a new session in Firestore
      if (_selectedSessionName == null) {
        setState(() => _isLoading = false);
        return;
      }

      final query = await FirebaseFirestore.instance
          .collection('sessions')
          .where('name', isEqualTo: _selectedSessionName)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session not found!')),
        );
        return;
      }

      final sessionDoc = query.docs.first;
      final sessionId = sessionDoc.id;

      if (_selectedMode == SessionMode.classroom) {
        nextScreen = ClassroomSessionScreen(
          sessionName: _selectedSessionName!,
          sessionId: sessionId,
        );
      } else {
        nextScreen = OnlineSessionScreen(
          sessionName: _selectedSessionName!,
          sessionId: sessionId,
        );
      }
    }

    setState(() => _isLoading = false);

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => nextScreen),
    );
  }

  Widget _buildToggle() {
    // ... (Keep your existing toggle code exactly as is) ...
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedMode = SessionMode.solo;
                _selectedSessionName = null; // Clear selected session
              });
            },
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: _selectedMode == SessionMode.solo ? kAccentColor : Colors.transparent,
                border: Border.all(color: kAccentColor, width: 2),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  bottomLeft: Radius.circular(8),
                ),
              ),
              child: Center(
                child: Text(
                  'Solo',
                  style: TextStyle(
                    color: _selectedMode == SessionMode.solo ? Colors.white : kLightGreyColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedMode = SessionMode.classroom;
                _selectedSessionName = null; // Clear selected session
              });
            },
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: _selectedMode == SessionMode.classroom ? kAccentColor : Colors.transparent,
                border: Border(
                  top: BorderSide(color: kAccentColor, width: 2),
                  bottom: BorderSide(color: kAccentColor, width: 2),
                ),
              ),
              child: Center(
                child: Text(
                  'Classroom',
                  style: TextStyle(
                    color: _selectedMode == SessionMode.classroom ? Colors.white : kLightGreyColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedMode = SessionMode.online;
                _selectedSessionName = null; // Clear selected session
              });
            },
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: _selectedMode == SessionMode.online ? kAccentColor : Colors.transparent,
                border: Border.all(color: kAccentColor, width: 2),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
              child: Center(
                child: Text(
                  'Online',
                  style: TextStyle(
                    color: _selectedMode == SessionMode.online ? Colors.white : kLightGreyColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isClassOrOnline = _selectedMode == SessionMode.classroom || _selectedMode == SessionMode.online;
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 6),
                    const Text(
                      'ISKOMATE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 24),

                    if (isClassOrOnline) ...[
                      SizedBox(
                        height: 55,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: kAccentColor, width: 2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                            backgroundColor: Colors.transparent,
                          ),
                          onPressed: _onSelectSessionPressed,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _selectedSessionName ?? 'Select Session',
                                style: TextStyle(
                                  color: kLightGreyColor,
                                  fontSize: 18,
                                ),
                              ),
                              Icon(Icons.chevron_right, color: kAccentColor),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ] else ...[
                      TextField(
                        controller: _sessionNameController,
                        decoration: InputDecoration(
                          hintText: 'Session name',
                          hintStyle: const TextStyle(color: kLightGreyColor),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.0),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        ),
                        style: const TextStyle(color: Colors.black, fontSize: 18),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // START Button with Loading Indicator
                    SizedBox(
                      height: 70,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kAccentColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          textStyle: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                        ),
                        onPressed: (isClassOrOnline && _selectedSessionName == null) || _isLoading
                            ? null
                            : _onStartPressed,
                        child: _isLoading 
                          ? const CircularProgressIndicator(color: Colors.white) 
                          : const Text('START'),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ... (Rest of your UI code: SET MODE, Toggle, Camera Preview, List Button) ...
                    const Text(
                      'SET MODE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: kLightGreyColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 20),

                    SizedBox(height: 44, child: _buildToggle()),
                    const SizedBox(height: 24),

                    // Camera Preview Button (always works)
                    SizedBox(
                      height: 44,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kAccentColor,
                          foregroundColor: Colors.white,
                          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.camera_alt, size: 22),
                        label: const Text('Camera Preview'),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => const VideoPreviewDialog(
                              webSocketUrl: 'ws://100.74.50.99:8765',
                              width: 340,
                              height: 220,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),

                    // List of Sessions Button (only for Classroom/Online)
                    if (isClassOrOnline)
                      SizedBox(
                        height: 44,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kAccentColor,
                            foregroundColor: Colors.white,
                            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => ListSessionsScreen()),
                            );
                          },
                          child: const Text('List of Sessions'),
                        ),
                      ),
                     const SizedBox(height: 100),
                  ],
                ),
              ),
            ),

            Align(
              alignment: Alignment.bottomLeft,
              child: SafeArea(
                left: true,
                top: false,
                right: false,
                bottom: true,
                minimum: const EdgeInsets.all(12),
                child: SizedBox(
                  width: 48,
                  height: 100,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    splashRadius: 24,
                    icon: SizedBox(
                      width: 28,
                      height: 28,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Icon(Icons.wifi, color: Colors.white, size: 28),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(0),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                              child: const Center(
                                child: Text('!',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    onPressed: _disconnectDevice,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: const OverlayLogoButton(),
    );
  }
}