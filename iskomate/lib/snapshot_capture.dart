import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'theme.dart'; // use your app colors (kBackgroundColor, kAccentColor)

class SnapshotCaptureDialog extends StatefulWidget {
  final String snapshotUrl; // URL that returns a single JPEG/PNG image
  final double width;
  final double height;

  const SnapshotCaptureDialog({
    required this.snapshotUrl,
    this.width = 340,
    this.height = 260,
    super.key,
  });

  @override
  State<SnapshotCaptureDialog> createState() => _SnapshotCaptureDialogState();
}

class _SnapshotCaptureDialogState extends State<SnapshotCaptureDialog> {
  Uint8List? _imageBytes;
  bool _isLoading = false;
  String? _error;

  Future<void> _fetchSnapshot() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final resp = await http.get(Uri.parse(widget.snapshotUrl)).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
        setState(() {
          _imageBytes = resp.bodyBytes;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Snapshot failed (status ${resp.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Snapshot error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    // Optionally fetch initial snapshot when dialog opens:
    // _fetchSnapshot();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: kBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SizedBox(
        width: widget.width,
        height: widget.height,
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
                      'Take Snapshot',
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

            // Body
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kAccentColor, width: 2),
                ),
                child: Center(
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : _imageBytes != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                _imageBytes!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              ),
                            )
                          : _error != null
                              ? Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Text(
                                    _error!,
                                    style: const TextStyle(color: Colors.white),
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              : const Padding(
                                  padding: EdgeInsets.all(12.0),
                                  child: Text(
                                    'No snapshot yet.\nTap Capture to fetch current frame.',
                                    style: TextStyle(color: Colors.white),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                ),
              ),
            ),

            // Footer: Capture / Close
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: kAccentColor),
                    onPressed: _isLoading ? null : _fetchSnapshot,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Capture'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[700]),
                    onPressed: () => Navigator.of(context).pop(_imageBytes),
                    child: const Text('Close'),
                  ),
                  const Spacer(),
                  if (_imageBytes != null)
                    TextButton(
                      onPressed: () {
                        // return captured bytes to caller immediately
                        Navigator.of(context).pop(_imageBytes);
                      },
                      child: const Text('Use Snapshot', style: TextStyle(color: Colors.white)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}