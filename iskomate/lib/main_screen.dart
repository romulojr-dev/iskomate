import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// app screens
import 'start_session.dart';

// theme colors
const Color kBackgroundColor = Color(0xFF232323);
const Color kAccentColor = Color(0xFFB71C1C);

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin {
  // First device is the RasPi we want to connect directly to
  final String _iskoName = 'IskoMate';
  final String _iskoIp = '100.74.50.99';

  // placeholders (disabled)
  final List<Map<String, String>> _placeholders = [
    {'name': 'Raspberry Pi 4', 'ip': '192.168.0.10'},
    {'name': 'Raspberry Pi 5', 'ip': '192.168.0.11'},
  ];

  bool _refreshing = false;
  Timer? _refreshTimer;
  late final AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _spinController.dispose();
    super.dispose();
  }

  Future<void> _onRefreshPressed() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    _spinController.repeat();

    // simulate network refresh animation for 1.2s
    _refreshTimer = Timer(const Duration(milliseconds: 1200), () {
      _spinController.stop();
      setState(() => _refreshing = false);
    });
  }

  void _openSessionFor(String name, String ip) {
    final sel = '$name@$ip';
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SessionSetupScreen(selectedDeviceName: sel)),
    );
  }

  @override
  Widget build(BuildContext context) {
    // system UI
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: kBackgroundColor,
      systemNavigationBarIconBrightness: Brightness.light,
    ));

    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SizedBox(height: 6),
              const Text(
                'CONNECT TO\nISKOMATE',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 24),

              // Device list
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(top: 10.0),
                  children: [
                    // First tile: direct RasPi connection (IskoMate) - enabled
                    DeviceTile(
                      deviceName: _iskoName,
                      deviceIp: _iskoIp,
                      onTap: () => _openSessionFor(_iskoName, _iskoIp),
                    ),
                    const SizedBox(height: 12),

                    // Placeholder devices - disabled (no navigation)
                    for (final p in _placeholders) ...[
                      DeviceTile(
                        deviceName: p['name']!,
                        deviceIp: p['ip']!,
                        onTap: null, // disabled
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Refresh button with animation
              SizedBox(
                height: 55,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    backgroundColor: kAccentColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                  ),
                  onPressed: _onRefreshPressed,
                  icon: AnimatedBuilder(
                    animation: _spinController,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _refreshing ? _spinController.value * 6.28318 : 0,
                        child: child,
                      );
                    },
                    child: const Icon(Icons.refresh, color: Colors.white, size: 24),
                  ),
                  label: Text(
                    _refreshing ? 'Refreshing...' : 'Refresh Devices',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              const SizedBox(height: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class DeviceTile extends StatelessWidget {
  final String deviceName;
  final String deviceIp;
  final VoidCallback? onTap;

  const DeviceTile({super.key, required this.deviceName, required this.deviceIp, this.onTap});

  @override
  Widget build(BuildContext context) {
    final bool disabled = onTap == null;
    final borderColor = disabled ? Colors.white12 : kAccentColor;
    final iconColor = disabled ? Colors.white24 : kAccentColor;
    final nameColor = disabled ? Colors.white54 : Colors.white;
    final ipColor = disabled ? Colors.white30 : Colors.white70;

    return Opacity(
      opacity: disabled ? 0.85 : 1.0,
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: kBackgroundColor,
          borderRadius: BorderRadius.circular(10.0),
          border: Border.all(color: borderColor, width: 2.0),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8.0),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: <Widget>[
                  // left avatar / icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: borderColor),
                    ),
                    child: Icon(Icons.computer, color: iconColor),
                  ),
                  const SizedBox(width: 14),
                  // name + ip
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(deviceName, style: TextStyle(color: nameColor, fontSize: 16, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(deviceIp, style: TextStyle(color: ipColor, fontSize: 13)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: disabled ? Colors.white24 : Colors.white70),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}