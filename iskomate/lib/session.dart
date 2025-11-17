import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'session_store.dart' as session_store;
import 'active_session.dart';
import 'overlay_logo.dart';
import 'theme.dart';

class SessionScreen extends StatefulWidget {
  const SessionScreen({super.key});
  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  final store = session_store.SessionStore();

  void _setSystemUIOverlay() {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      systemNavigationBarIconBrightness: Brightness.light,
    ));
  }

  Future<void> _confirmAndDelete(int index) async {
    final sessions = store.sessions.value;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kBackgroundColor,
        title: const Text('Delete session', style: TextStyle(color: Colors.white)),
        content: Text('Delete "${sessions[index].name}"?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('DELETE', style: TextStyle(color: kAccentColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await store.removeAt(index);
    }
  }

  String _formatDate(int epochMs) {
    final dt = DateTime.fromMillisecondsSinceEpoch(epochMs);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    _setSystemUIOverlay();

    return Scaffold(
      backgroundColor: kBackgroundColor,
      floatingActionButton: const OverlayLogoButton(),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            // --- Header Section ---
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 15.0),
              decoration: const BoxDecoration(
                // Small maroon accent line at the bottom of the header
                border: Border(
                  bottom: BorderSide(color: kAccentColor, width: 3.0),
                ),
              ),
              child: Row(
                children: <Widget>[
                  // Back Arrow
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 24),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                  const SizedBox(width: 20),
                  // Title Text
                  const Expanded(
                    child: Text(
                      'SESSIONS',
                      textAlign: TextAlign.left, // Left-aligned to balance the back button
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // --- Session List (reads from store) ---
            Expanded(
              child: ValueListenableBuilder<List<session_store.Session>>(
                valueListenable: store.sessions,
                builder: (context, sessions, _) {
                  if (sessions.isEmpty) {
                    return const Center(
                      child: Text('No sessions', style: TextStyle(color: Colors.white70)),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(25.0),
                    itemCount: sessions.length,
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      final dateStr = _formatDate(session.createdAt);
                      return SessionTile(
                        key: ValueKey(session.id),
                        sessionName: session.name,
                        sessionDate: dateStr,
                        isHighlighted: index == 0,
                        onDelete: () => _confirmAndDelete(index),
                        onTap: () {
                          // Open corresponding active session page
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ActiveSessionScreen(
                                sessionName: session.name,
                                deviceName: session.deviceName,
                                deviceIp: session.deviceIp,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Custom Widget for a Single Session Tile ---
class SessionTile extends StatelessWidget {
  final String sessionName;
  final String sessionDate;
  final bool isHighlighted;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  const SessionTile({
    super.key,
    required this.sessionName,
    required this.sessionDate,
    this.isHighlighted = false,
    this.onDelete,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12.0),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: isHighlighted ? kAccentColor : Colors.transparent,
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(
                color: isHighlighted ? kAccentColor : Colors.white24,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sessionName,
                        style: TextStyle(
                          color: isHighlighted ? Colors.white : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        sessionDate,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                if (onDelete != null)
                  IconButton(
                    icon: Icon(
                      Icons.delete,
                      color: isHighlighted ? Colors.white : Colors.white70,
                    ),
                    onPressed: onDelete,
                    tooltip: 'Delete session',
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}