import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'theme.dart'; // <-- use your app colors

class VideoStreamPage extends StatefulWidget {
  const VideoStreamPage({super.key});

  @override
  State<VideoStreamPage> createState() => _VideoStreamPageState();
}

class _VideoStreamPageState extends State<VideoStreamPage> {
  final String _whepUrl = 'http://100.74.50.99:8889/cam/whep';
  final RTCVideoRenderer _renderer = RTCVideoRenderer();
  RTCPeerConnection? _pc;
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
      await _connect();
    } catch (e) {
      debugPrint('Init error: $e');
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _renderer.dispose();
    _pc?.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      _pc = await createPeerConnection({
        'iceServers': [],
      });

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

      final response = await http.post(
        Uri.parse(_whepUrl),
        headers: {'Content-Type': 'application/sdp'},
        body: offer.sdp,
      );

      if (response.statusCode != 201) {
        throw Exception('WHEP responded ${response.statusCode}');
      }

      final answerSdp = response.body;
      final answer = RTCSessionDescription(answerSdp, 'answer');
      await _pc!.setRemoteDescription(answer);
    } catch (e) {
      debugPrint('Connect error: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                        onPressed: _connect,
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
        onPressed: _connect,
        child: const Icon(Icons.refresh),
      ),
    );
  }
}

// Small pop-up preview - NOW FIXED
class VideoPreviewDialog extends StatefulWidget {
  final String streamUrl; // <-- Renamed from whepUrl
  final double width;
  final double height;

  const VideoPreviewDialog({
    required this.streamUrl, // <-- Renamed
    this.width = 340,
    this.height = 220,
    super.key,
  });

  @override
  State<VideoPreviewDialog> createState() => _VideoPreviewDialogState();
}

class _VideoPreviewDialogState extends State<VideoPreviewDialog> {
  late final VlcPlayerController _vlcController;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _vlcController = VlcPlayerController.network(
      widget.streamUrl,
      hwAcc: HwAcc.full,
      autoPlay: true,
    );
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      debugPrint('VLC: Starting initialization...');
      await _vlcController.initialize();
      debugPrint('VLC: Initialization complete');
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _hasError = false;
        });
      }
    } catch (e) {
      debugPrint('VLC Init Error: $e');
      if (mounted) {
        setState(() {
          _isInitialized = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _vlcController.stop();
    _vlcController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: kBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
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

            // Body: VLC player
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
                              children: [
                                Icon(Icons.error, color: Colors.redAccent, size: 28),
                                SizedBox(height: 8),
                                Text('Stream error', style: TextStyle(color: Colors.white)),
                              ],
                            ),
                          )
                        : !_isInitialized
                            ? const CircularProgressIndicator()
                            : VlcPlayer(
                                controller: _vlcController,
                                aspectRatio: widget.width / widget.height,
                                placeholder: const Center(child: CircularProgressIndicator()),
                              ),
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