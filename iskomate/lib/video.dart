import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
// 1. ADD THIS IMPORT
import 'package:uuid/uuid.dart'; 
import 'theme.dart';

class VideoStreamPage extends StatefulWidget {
  const VideoStreamPage({super.key});

  @override
  State<VideoStreamPage> createState() => _VideoStreamPageState();
}

class _VideoStreamPageState extends State<VideoStreamPage> {
  final String _webSocketUrl = 'ws://100.105.15.120:9090';
  final RTCVideoRenderer _renderer = RTCVideoRenderer();
  RTCPeerConnection? _pc;
  WebSocketChannel? _channel;
  bool _isLoading = true;
  bool _hasError = false;
  
  // 2. GENERATE UNIQUE ID
  final String _myId = const Uuid().v4(); 

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
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _connectWebRTC() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      _channel = WebSocketChannel.connect(Uri.parse(_webSocketUrl));
      _pc = await createPeerConnection({'iceServers': []});

      _pc!.onTrack = (RTCTrackEvent event) {
        if (event.track.kind == 'video' && event.streams.isNotEmpty) {
          _renderer.srcObject = event.streams[0];
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        }
      };

      await _pc!.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
      );

      final offer = await _pc!.createOffer();
      await _pc!.setLocalDescription(offer);

      debugPrint('Sending offer via WebSocket');
      // 3. SEND ID WITH OFFER
      _channel!.sink.add(jsonEncode({
        'id': _myId, 
        'type': 'offer',
        'sdp': offer.sdp,
      }));

      _channel!.stream.listen((message) async {
        try {
          final data = jsonDecode(message);
          
          // 4. IGNORE MESSAGES NOT FOR US
          if (data['id'] != _myId) return;

          if (data['type'] == 'answer') {
            debugPrint('Received answer');
            final answer = RTCSessionDescription(data['sdp'], 'answer');
            await _pc!.setRemoteDescription(answer);
          } else if (data['type'] == 'ice_candidate') {
            debugPrint('Received ICE candidate');
            final candidate = RTCIceCandidate(
              data['candidate'],
              data['sdpMLineIndex'],
              data['sdpMid'],
            );
            await _pc!.addCandidate(candidate);
          }
        } catch (e) {
          debugPrint('WebSocket message error: $e');
        }
      });

      _pc!.onIceCandidate = (RTCIceCandidate candidate) {
        debugPrint('Sending ICE candidate via WebSocket');
        // 5. SEND ID WITH CANDIDATES
        _channel!.sink.add(jsonEncode({
          'id': _myId,
          'type': 'ice_candidate',
          'candidate': candidate.candidate,
          'sdpMLineIndex': candidate.sdpMLineIndex,
          'sdpMid': candidate.sdpMid,
        }));
      };
    } catch (e) {
      debugPrint('WebRTC connect error: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
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
    // (This build method is fine, keep it as is)
    return Scaffold(
      appBar: AppBar(title: const Text('Pi Video Stream')),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : _hasError
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error, color: Colors.redAccent, size: 40),
                      const SizedBox(height: 8),
                      const Text('Stream error'),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _connectWebRTC,
                        style: ElevatedButton.styleFrom(backgroundColor: kAccentColor),
                        child: const Text('Retry'),
                      ),
                    ],
                  )
                : (_renderer.renderVideo
                    ? RTCVideoView(
                        _renderer,
                        mirror: false,
                        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      )
                    : const Text('Video stream not available')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _connectWebRTC,
        child: const Icon(Icons.refresh),
      ),
    );
  }
}

// WebSocket-based popup dialog for snapshots
class VideoPreviewDialog extends StatefulWidget {
  final String webSocketUrl;
  final double width;
  final double height;

  const VideoPreviewDialog({
    required this.webSocketUrl,
    this.width = 340,
    this.height = 220,
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
  
  // 6. GENERATE ID FOR DIALOG
  final String _myId = const Uuid().v4();

  @override
  void initState() {
    super.initState();
    _initRendererAndConnect();
  }

  Future<void> _initRendererAndConnect() async {
    try {
      await _renderer.initialize();
      await _connect();
    } catch (e) {
      debugPrint('Preview init error: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _connect() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      _channel = WebSocketChannel.connect(Uri.parse(widget.webSocketUrl));
      _pc = await createPeerConnection({'iceServers': []});

      _pc!.onTrack = (RTCTrackEvent event) {
        if (event.track.kind == 'video' && event.streams.isNotEmpty) {
          _renderer.srcObject = event.streams[0];
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        }
      };

      await _pc!.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
      );

      final offer = await _pc!.createOffer();
      await _pc!.setLocalDescription(offer);

      debugPrint('Popup: Sending offer via WebSocket');
      // 7. SEND ID
      _channel!.sink.add(jsonEncode({
        'id': _myId,
        'type': 'offer',
        'sdp': offer.sdp,
      }));

      _channel!.stream.listen((message) async {
        try {
          final data = jsonDecode(message);
          
          // 8. IGNORE MESSAGES NOT FOR US
          if (data['id'] != _myId) return;

          if (data['type'] == 'answer') {
            debugPrint('Popup: Received answer');
            final answer = RTCSessionDescription(data['sdp'], 'answer');
            await _pc!.setRemoteDescription(answer);
          } else if (data['type'] == 'ice_candidate') {
            final candidate = RTCIceCandidate(
              data['candidate'],
              data['sdpMLineIndex'],
              data['sdpMid'],
            );
            await _pc!.addCandidate(candidate);
          }
        } catch (e) {
          debugPrint('Popup WebSocket message error: $e');
        }
      });

      _pc!.onIceCandidate = (RTCIceCandidate candidate) {
        // 9. SEND ID
        _channel!.sink.add(jsonEncode({
          'id': _myId, 
          'type': 'ice_candidate',
          'candidate': candidate.candidate,
          'sdpMLineIndex': candidate.sdpMLineIndex,
          'sdpMid': candidate.sdpMid,
        }));
      };
    } catch (e) {
      debugPrint('Popup connect error: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
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
     // (This build method is fine, keep it as is)
    return Dialog(
      backgroundColor: kBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SizedBox(
        width: widget.width,
        height: widget.height + 64,
        child: Column(
          children: [
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: kBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Camera Preview',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
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
                  child: Center(
                    child: _hasError
                        ? Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.error, color: Colors.redAccent, size: 28),
                                SizedBox(height: 8),
                                Text('Stream error', style: TextStyle(color: Colors.white)),
                              ],
                            ),
                          )
                        : _isLoading
                            ? const CircularProgressIndicator()
                            : (_renderer.renderVideo
                                ? RTCVideoView(
                                    _renderer,
                                    mirror: false,
                                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                                  )
                                : const Text('Video not available', style: TextStyle(color: Colors.white))),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}