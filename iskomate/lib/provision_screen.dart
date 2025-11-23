// provision_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Import your theme colors
import 'theme.dart'; // <-- CHANGE THIS from 'main_screen.dart'
import 'start_session.dart'; // <-- ADD THIS IMPORT AT THE TOP

// The IP of the Pi when it's in Hotspot mode
const String piHotspotIp = '10.42.0.1:4000';

class ProvisionScreen extends StatefulWidget {
  const ProvisionScreen({super.key});

  @override
  _ProvisionScreenState createState() => _ProvisionScreenState();
}

// Enum to manage the UI state
enum ProvisionState {
  instructions,
  scanning,
  showNetworks,
  connecting,
  finalInstructions,
  error,
}

class _ProvisionScreenState extends State<ProvisionScreen> {
  ProvisionState _currentState = ProvisionState.instructions;
  List<dynamic> _networks = [];
  String _errorMessage = '';
  String _selectedSsid = '';
  String _finalIp = '';
  final TextEditingController _passwordController = TextEditingController();

  // --- API CALLS ---

  Future<void> _scanForNetworks() async {
    setState(() => _currentState = ProvisionState.scanning);
    try {
      final response = await http
          .get(Uri.parse('http://$piHotspotIp/scan'))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            _networks = data['networks'];
            _currentState = ProvisionState.showNetworks;
          });
        } else {
          _setError(data['message']);
        }
      } else {
        _setError('Failed to contact device. Status code: ${response.statusCode}');
      }
    } catch (e) {
      _setError(
          'Error scanning. Are you connected to the "IskoMate-Setup" WiFi? \n\nError: ${e.toString()}');
    }
  }

  Future<void> _connectToNetwork() async {
    final password = _passwordController.text;
    if (password.isEmpty) return;

    Navigator.of(context).pop();
    setState(() => _currentState = ProvisionState.connecting);

    try {
      final response = await http
          .post(
            Uri.parse('http://$piHotspotIp/connect'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'ssid': _selectedSsid, 'password': password}),
          )
          .timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          _finalIp = data['new_ip'] ?? '';

          // Save device name to SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('selectedDeviceName', '$_selectedSsid@$_finalIp');

          await Future.delayed(const Duration(seconds: 5));

          if (!mounted) return;

          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => SessionSetupScreen(
                selectedDeviceName: '$_selectedSsid@$_finalIp',
              ),
            ),
          );
          return;
        } else {
          // --- REAL ERROR (e.g., wrong password) ---
          // The Pi had time to respond with a failure.
          _setError(data['message'] ??
              'Connection failed. Please check your password and try again.');
        }
      } else {
        // --- REAL HTTP ERROR (e.g., 500 server error) ---
        _setError(
            'The device responded with status ${response.statusCode}. Please try again.');
      }
    } catch (e) {
      // --- THIS IS THE KEY CHANGE ---
      // --- ASSUMED SUCCESS (Timeout/Network Error) ---
      // We *assume* this error (e.g., 'Connection timed out' or 'SocketException')
      // is just the Pi disconnecting its hotspot after a successful connection.
      // We navigate immediately, passing 'null' for the IP.
      
      // Timeout: assume success, wait a moment, then navigate
      setState(() => _currentState = ProvisionState.connecting);
      
      await Future.delayed(const Duration(seconds: 3));
      
      if (!mounted) return;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selectedDeviceName', '$_selectedSsid@$_finalIp');

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => SessionSetupScreen(
            selectedDeviceName: '$_selectedSsid@$_finalIp',
          ),
        ),
      );
    }
  }

  void _setError(String message) {
    setState(() {
      _errorMessage = message;
      _currentState = ProvisionState.error;
    });
  }

  // --- UI WIDGETS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      // Removed the AppBar and the back/close button as requested.
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: _buildCurrentStateWidget(),
        ),
      ),
    );
  }

  Widget _buildCurrentStateWidget() {
    switch (_currentState) {
      case ProvisionState.instructions:
        return _buildInstructionsWidget();
      case ProvisionState.scanning:
        return const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(kAccentColor)),
            SizedBox(height: 20),
            Text('Scanning for networks...',
                style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        );
      case ProvisionState.showNetworks:
        return _buildNetworksList();
      case ProvisionState.connecting:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(kAccentColor)),
            const SizedBox(height: 20),
            Text('Connecting to $_selectedSsid...\n\nThis will take a moment.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16)),
          ],
        );
      case ProvisionState.finalInstructions:
        return _buildFinalInstructionsWidget();
      case ProvisionState.error:
        return _buildErrorWidget();
    }
  }

  Widget _buildInstructionsWidget() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Step 1: Connect to the Pi',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        const Text(
          '1. Go to your phone\'s WiFi Settings.\n'
          '2. Find and connect to the (hidden) network:\n'
          '   - SSID: IskoMate\n'
          '   - Password: qwerty123\n'
          '3. Return to this app and tap "Scan".',
          style: TextStyle(color: Colors.white70, fontSize: 16, height: 1.5),
        ),
        const SizedBox(height: 30),
        TextButton(
          style: TextButton.styleFrom(
              backgroundColor: kAccentColor,
              padding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0))),
          onPressed: _scanForNetworks,
          child: const Text('Scan for Networks',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildNetworksList() {
    return Column(
      children: [
        const Text(
          'Step 2: Select Your Network',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white12),
              borderRadius: BorderRadius.circular(10.0),
            ),
            child: ListView.builder(
              itemCount: _networks.length,
              itemBuilder: (context, index) {
                final network = _networks[index];
                return ListTile(
                  title: Text(network['ssid'],
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  leading: const Icon(Icons.wifi, color: Colors.white70),
                  trailing: Text('${network['signal']}%',
                      style: const TextStyle(color: Colors.white54)),
                  onTap: () => _showPasswordDialog(network['ssid']),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  void _showPasswordDialog(String ssid) {
    _selectedSsid = ssid;
    _passwordController.clear();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF333333),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
          title: Text('Enter Password for\n$ssid',
              style: const TextStyle(color: Colors.white)),
          content: TextField(
            controller: _passwordController,
            obscureText: true,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Password',
              labelStyle: TextStyle(color: Colors.white70),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white54),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: kAccentColor),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: _connectToNetwork,
              child: const Text('Connect', style: TextStyle(color: kAccentColor, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFinalInstructionsWidget() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.check_circle_outline, color: kAccentColor, size: 60),
        const SizedBox(height: 20),
        const Text(
          'Connected Successfully!',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        Text(
          'Device IP: $_finalIp',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 16),
        ),
        const SizedBox(height: 30),
        TextButton(
          style: TextButton.styleFrom(
              backgroundColor: kAccentColor,
              padding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0))),
          onPressed: () {
            // Navigate to StartSessionScreen with the new device
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => SessionSetupScreen(
                  selectedDeviceName: '$_selectedSsid@$_finalIp',
                ),
              ),
            );
          },
          child: const Text('Continue to Session',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildErrorWidget() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.error_outline, color: kAccentColor, size: 60),
        const SizedBox(height: 20),
        const Text(
          'An Error Occurred',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        Text(
          _errorMessage,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.5),
        ),
        const SizedBox(height: 30),
        TextButton(
          style: TextButton.styleFrom(
              backgroundColor: kAccentColor,
              padding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0))),
          onPressed: () {
            setState(() => _currentState = ProvisionState.instructions);
          },
          child: const Text('Try Again',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}