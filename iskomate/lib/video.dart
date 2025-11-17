import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'theme.dart';

// !!! REPLACE WITH YOUR LAPTOP IP !!!
const String kLaptopUrl = 'ws://100.74.50.99:8765';

class VideoStreamPage extends StatefulWidget {
  const VideoStreamPage({super.key});

  @override
  State<VideoStreamPage> createState() => _VideoStreamPageState();
}

class _VideoStreamPageState extends State<VideoStreamPage> {
  final RTCVideoRenderer _renderer = RTCVideoRenderer();
  RTCPeerConnection? _pc;
  WebSocketChannel? _channel;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _renderer.initialize();
      await _connectWebRTC();
    } catch (e) {
      debugPrint('Init error: $e');
      if (mounted) setState(() => _hasError = true);
    }
  }

  Future<void> _connectWebRTC() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _hasError = false; });

    try {
      _channel = WebSocketChannel.connect(Uri.parse(kLaptopUrl));
      _pc = await createPeerConnection({'iceServers': []});

      _pc!.onTrack = (RTCTrackEvent event) {
        if (event.track.kind == 'video' && event.streams.isNotEmpty) {
          _renderer.srcObject = event.streams[0];
          if (mounted) setState(() => _isLoading = false);
        }
      };

      await _pc!.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
      );

      final offer = await _pc!.createOffer();
      await _pc!.setLocalDescription(offer);

      _channel!.sink.add(jsonEncode({'type': 'offer', 'sdp': offer.sdp}));

      _channel!.stream.listen((message) async {
        try {
          final data = jsonDecode(message);
          if (data['type'] == 'answer') {
            await _pc!.setRemoteDescription(RTCSessionDescription(data['sdp'], 'answer'));
          }
        } catch (e) { /* Ignore non-signaling messages */ }
      });
    } catch (e) {
      debugPrint('WebRTC error: $e');
      if (mounted) setState(() => _hasError = true);
    }
  }

  @override
  void dispose() {
    _renderer.dispose();
    _pc?.dispose();
    _channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Camera Preview')),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : _hasError
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error, color: Colors.red, size: 40),
                      const SizedBox(height: 10),
                      ElevatedButton(onPressed: _connectWebRTC, child: const Text('Retry'))
                    ],
                  )
                : RTCVideoView(_renderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
      ),
    );
  }
}

// --- PREVIEW DIALOG (Popup) ---
class VideoPreviewDialog extends StatefulWidget {
  final String webSocketUrl;
  final double width;
  final double height;

  const VideoPreviewDialog({
    required this.webSocketUrl,
    this.width = 500,
    this.height = 380,
    super.key,
  });

  @override
  State<VideoPreviewDialog> createState() => _VideoPreviewDialogState();
}

class _VideoPreviewDialogState extends State<VideoPreviewDialog> {
  final RTCVideoRenderer _renderer = RTCVideoRenderer();
  RTCPeerConnection? _pc;
  WebSocketChannel? _channel;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    try {
      await _renderer.initialize();
      _channel = WebSocketChannel.connect(Uri.parse(widget.webSocketUrl));
      _pc = await createPeerConnection({'iceServers': []});

      _pc!.onTrack = (RTCTrackEvent event) {
        if (event.track.kind == 'video' && event.streams.isNotEmpty) {
          _renderer.srcObject = event.streams[0];
          if (mounted) setState(() => _isLoading = false);
        }
      };

      await _pc!.addTransceiver(kind: RTCRtpMediaType.RTCRtpMediaTypeVideo, init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly));
      final offer = await _pc!.createOffer();
      await _pc!.setLocalDescription(offer);

      _channel!.sink.add(jsonEncode({'type': 'offer', 'sdp': offer.sdp}));

      _channel!.stream.listen((message) async {
        final data = jsonDecode(message);
        if (data['type'] == 'answer') {
          await _pc!.setRemoteDescription(RTCSessionDescription(data['sdp'], 'answer'));
        }
      });
    } catch (e) {
      if (mounted) setState(() => _hasError = true);
    }
  }

  @override
  void dispose() {
    _renderer.dispose();
    _pc?.dispose();
    _channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Dialog(
        backgroundColor: kBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
        child: SizedBox(
          width: widget.width,
          height: widget.height + 64,
          child: Column(
            children: [
              // Header
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: kBackgroundColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Row(
                  children: [
                    const Expanded(child: Text('Camera Preview', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                    IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.of(context).pop()),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kAccentColor, width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _hasError 
                        ? const Center(child: Icon(Icons.error, color: Colors.red, size: 40)) 
                        : _isLoading 
                            ? const Center(child: CircularProgressIndicator()) 
                            : RTCVideoView(_renderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}