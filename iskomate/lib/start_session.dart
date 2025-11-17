// start_session.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for SystemChrome
import 'package:shared_preferences/shared_preferences.dart';
import 'package:iskomate/video.dart';

// open sessions screen
import 'session.dart';
import 'active_session.dart'; // ensure this import exists so VideoPopupScreen is available
import 'session_store.dart' as session_store;
import 'overlay_logo.dart';
import 'theme.dart'; // <-- add this import to get colors from theme
import 'provision_screen.dart';

class SessionSetupScreen extends StatefulWidget {
  final String? selectedDeviceName;

  const SessionSetupScreen({super.key, this.selectedDeviceName});

  @override
  State<SessionSetupScreen> createState() => _SessionSetupScreenState();
}

class _SessionSetupScreenState extends State<SessionSetupScreen> {
  bool _isSoloMode = true; // State for the Solo/Classroom toggle
  final TextEditingController _sessionNameController = TextEditingController();

  // Drag state for holdable toggle
  bool _isDraggingToggle = false;
  double _dragLeft = 0.0;

  @override
  void initState() {
    super.initState();
    _setSystemUIOverlay();
  }

  @override
  void dispose() {
    _sessionNameController.dispose(); // Clean up the controller when the widget is removed
    super.dispose();
  }

  // Set system UI (status bar and navigation bar) colors
  void _setSystemUIOverlay() {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, // Making status bar transparent
      statusBarIconBrightness: Brightness.light, // For dark background
      systemNavigationBarColor: kBackgroundColor, // Matching app background
      systemNavigationBarIconBrightness: Brightness.light, // For dark background
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            // Main scrollable content (existing)
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const SizedBox(height: 6),
                    const Text(
                      'CREATE SESSION',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Session Name Input
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
                      style: const TextStyle(color: Colors.black, fontSize: 18), // Text input color
                    ),
                    const SizedBox(height: 30),

                    // START Button
                    SizedBox(
                      height: 70,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kAccentColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () async {
                          // prepare session name
                          final sessionName = _sessionNameController.text.trim().isEmpty
                              ? 'Session ${DateTime.now().millisecondsSinceEpoch}'
                              : _sessionNameController.text.trim();

                          String deviceName = '';
                          if (widget.selectedDeviceName != null && widget.selectedDeviceName!.contains('@')) {
                            deviceName = widget.selectedDeviceName!.split('@')[0];
                          }

                          // create session object
                          final id = DateTime.now().millisecondsSinceEpoch.toString();
                          
                          const String currentPiIp = '100.74.50.99';
                          
                          final session = session_store.Session(
                            id: id,
                            name: sessionName,
                            deviceName: deviceName, // The Wi-Fi name
                            deviceIp: currentPiIp, // The static Tailscale IP
                            createdAt: DateTime.now().millisecondsSinceEpoch,
                          );

                          // save persistently and update in-memory notifier
                          try {
                            await session_store.SessionStore.addSession(session);
                          } catch (_) {
                            // ignore persistence errors for now
                          }

                          // clear input and dismiss keyboard
                          _sessionNameController.clear();
                          FocusScope.of(context).unfocus();

                          // navigate directly to ActiveSessionScreen
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ActiveSessionScreen(
                                sessionName: session.name,
                                deviceName: session.deviceName,
                                deviceIp: session.deviceIp, // <-- This passes the Tailscale IP
                                isSolo: _isSoloMode,
                              ),
                            ),
                          );
                        },
                        child: const Text('START'),
                      ),
                    ),
                    const SizedBox(height: 50),

                    // SET MODE Title
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

                    // Solo / Classroom Toggle
                    // ... (no changes in this large widget) ...
                    LayoutBuilder(builder: (context, constraints) {
                      final totalW = constraints.maxWidth;
                      final innerW = (totalW - 6).clamp(0.0, totalW);
                      final halfInner = innerW / 2;
                      const double edgeGap = 6.0;
                      final indicatorW = (halfInner - edgeGap * 2).clamp(0.0, halfInner);
                      final minLeft = edgeGap;
                      final maxLeft = halfInner + edgeGap;
                      final computedLeft = _isDraggingToggle
                          ? _dragLeft.clamp(minLeft, maxLeft)
                          : (_isSoloMode ? minLeft : maxLeft);
                      final indicatorCenter = computedLeft + (indicatorW / 2);
                      final leftLabelActive = _isDraggingToggle
                          ? (indicatorCenter < (innerW / 2))
                          : _isSoloMode;

                      return GestureDetector(
                        onTapUp: (details) {
                          setState(() => _isSoloMode = details.localPosition.dx < (totalW / 2));
                        },
                        onPanStart: (details) {
                          setState(() {
                            _isDraggingToggle = true;
                            _dragLeft = (details.localPosition.dx - indicatorW / 2).clamp(minLeft, maxLeft);
                          });
                        },
                        onPanUpdate: (details) {
                          setState(() {
                            _dragLeft = (details.localPosition.dx - indicatorW / 2).clamp(minLeft, maxLeft);
                          });
                        },
                        onPanEnd: (_) {
                          setState(() {
                            _isDraggingToggle = false;
                            final center = (_dragLeft + (indicatorW / 2)).clamp(minLeft, maxLeft);
                            _isSoloMode = center < (innerW / 2);
                            _dragLeft = 0.0;
                          });
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(30.0),
                          child: Container(
                            height: 50,
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: kBackgroundColor,
                              borderRadius: BorderRadius.circular(30.0),
                              border: Border.all(color: kAccentColor, width: 2),
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                AnimatedPositioned(
                                  duration: const Duration(milliseconds: 180),
                                  left: computedLeft,
                                  width: indicatorW,
                                  curve: Curves.easeOut,
                                  child: Container(
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: kAccentColor,
                                      borderRadius: BorderRadius.circular(25),
                                    ),
                                  ),
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Center(
                                        child: Text(
                                          'Solo',
                                          style: TextStyle(
                                            color: leftLabelActive ? Colors.white : kLightGreyColor,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Center(
                                        child: Text(
                                          'Classroom',
                                          style: TextStyle(
                                            color: leftLabelActive ? kLightGreyColor : Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 50),

                    // Camera Preview Button (open small popup)
                    GestureDetector(
                      // <-- MODIFIED THIS ONTAP
                      onTap: () {
                        // This now calls the VideoPreviewDialog from your video.dart file
                        showDialog(
                          context: context,
                          builder: (context) => const VideoPreviewDialog(
                            webSocketUrl: 'ws://100.74.50.99:8765',
                            width: 340,
                            height: 220,
                          ),
                        );
                      },
                      // <-- END OF MODIFICATION
                      child: Container(
                        height: 55,
                        decoration: BoxDecoration(
                          color: kAccentColor,
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 24,
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Camera Preview',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20), // Spacing at the bottom
                  ],
                ),
              ),
            ),

            // ... (rest of the file is unchanged) ...
            
            // Overlay: three-line list button in top-right
            Positioned(
              top: 12,
              right: 12,
              child: Material(
                color: Colors.transparent,
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    splashRadius: 24,
                    icon: const Icon(Icons.menu, color: Colors.white),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SessionScreen()),
                      );
                    },
                  ),
                ),
              ),
            ),

            // Disconnect button bottom-left
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