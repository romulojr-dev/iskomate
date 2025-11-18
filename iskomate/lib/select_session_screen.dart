import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'theme.dart';

class SelectSessionScreen extends StatelessWidget {
  const SelectSessionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: kBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'SELECT SESSION',
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
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('sessions').snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final sessions = snapshot.data!.docs;
            if (sessions.isEmpty) {
              return const Center(child: Text('No sessions available.', style: TextStyle(color: Colors.white)));
            }
            return ListView.builder(
              itemCount: sessions.length,
              itemBuilder: (context, index) {
                final session = sessions[index].data() as Map<String, dynamic>;
                final sessionName = session['name'] ?? 'No Name';
                final sessionDateRaw = session['date'] ?? '';
                String sessionDate = sessionDateRaw;
                if (sessionDateRaw.isNotEmpty) {
                  try {
                    final dt = DateTime.parse(sessionDateRaw);
                    sessionDate = "${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
                  } catch (_) {
                    sessionDate = sessionDateRaw.split('T').first;
                  }
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: kAccentColor, width: 2),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      Navigator.pop(context, session['name']);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                sessionName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                sessionDate,
                                style: const TextStyle(
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const Icon(Icons.chevron_right, color: kAccentColor, size: 32),
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
    );
  }
}