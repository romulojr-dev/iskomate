import 'package:flutter/material.dart';
import 'theme.dart';

class SessionInfoScreen extends StatelessWidget {
  final Map<String, dynamic> session;

  const SessionInfoScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final List<dynamic> students = session['students'] as List<dynamic>? ?? [];

    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: kAccentColor,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'SESSION INFO',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
            letterSpacing: 1.5,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Name of Session:',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 1.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                session['name'] ?? 'No Name',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'List of Students Enrolled:',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            if (students.isEmpty)
              const Text(
                'No students enrolled.',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: students.length,
                  separatorBuilder: (context, idx) => Divider(
                    color: Colors.white.withOpacity(0.5),
                    thickness: 1,
                    height: 18,
                  ),
                  itemBuilder: (context, idx) {
                    final student = students[idx];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          student['name'] ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          student['id'] ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
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