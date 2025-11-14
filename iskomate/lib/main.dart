import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart'; // <-- ADD THIS IMPORT
import 'package:shared_preferences/shared_preferences.dart';
import 'provision_screen.dart';
import 'start_session.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF232323),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String? _savedDeviceName;

  @override
  void initState() {
    super.initState();
    _checkSavedDevice();
  }

  Future<void> _checkSavedDevice() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceName = prefs.getString('selectedDeviceName');
    setState(() => _savedDeviceName = deviceName);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ISKOMATE App',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: kAccentColor,
        scaffoldBackgroundColor: kBackgroundColor,
      ),
      home: _savedDeviceName != null
          ? SessionSetupScreen(selectedDeviceName: _savedDeviceName)
          : const ProvisionScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}