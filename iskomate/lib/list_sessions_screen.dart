import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'theme.dart';
import 'view_session_screen.dart';
import 'edit_session_screen.dart';
import 'add_session_screen.dart';
import 'session_info_screen.dart';

class ListSessionsScreen extends StatefulWidget {
  const ListSessionsScreen({super.key});

  @override
  State<ListSessionsScreen> createState() => _ListSessionsScreenState();
}

class _ListSessionsScreenState extends State<ListSessionsScreen> {
  // 1. Create a reference to your "sessions" collection in Firebase
  final CollectionReference _sessionsCollection = 
      FirebaseFirestore.instance.collection('sessions');

  // Function to delete a session from Firebase
  Future<void> _deleteSession(String id) async {
    await _sessionsCollection.doc(id).delete();
  }

  // Navigate to View Screen passing the ID so it can listen to live updates/history
  void _onViewSessionPressed(Map<String, dynamic> sessionData, String id) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ViewSessionScreen(
          sessionData: sessionData,
          sessionId: id, 
        ),
      ),
    );
  }

  // Navigate to Edit Screen
  void _onEditSessionPressed(Map<String, dynamic> sessionData, String id) {
    Navigator.push(
      context,
      MaterialPageRoute(
        // You can modify EditSessionScreen later to accept 'id' if needed for saving
        builder: (context) => EditSessionScreen(session: {
          'name': sessionData['name'] ?? '', 
          'date': sessionData['date'] ?? ''
        }), 
      ),
    );
  }

  void _onAddSessionPressed() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddSessionScreen(),
      ),
    );
  }

  void _confirmDeleteSession(String id) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Session'),
        content: const Text('Are you sure you want to delete this session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (shouldDelete == true) {
      await _deleteSession(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: kAccentColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'LIST OF SESSIONS',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        
        // 2. StreamBuilder listens to the database in real-time
        child: StreamBuilder<QuerySnapshot>(
          stream: _sessionsCollection.orderBy('date', descending: true).snapshots(),
          builder: (context, snapshot) {
            // Handle Loading State
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            // Handle Error State
            if (snapshot.hasError) {
              return const Center(child: Text('Something went wrong', style: TextStyle(color: Colors.white)));
            }

            // Handle Empty State
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(
                child: Text(
                  'No sessions found in database.\nAdd them in Firebase Console or click +', 
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              );
            }

            final data = snapshot.requireData;

            return ListView.builder(
              itemCount: data.size,
              itemBuilder: (context, index) {
                // 3. Get the individual document data
                var doc = data.docs[index];
                var session = doc.data() as Map<String, dynamic>;
                String id = doc.id; // The unique ID from Firebase

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: kAccentColor, width: 2),
                      ),
                    ),
                    // Clicking the main card body opens the View Screen (Graph)
                    onPressed: () => _onViewSessionPressed(session, id),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                session['name'] ?? 'No Name',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                session['date'] ?? 'No Date',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_red_eye, color: Colors.grey),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => SessionInfoScreen(
                                        session: session,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, color: kAccentColor),
                                onPressed: () => _onEditSessionPressed(session, id),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _confirmDeleteSession(id),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: kAccentColor,
        onPressed: _onAddSessionPressed,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}