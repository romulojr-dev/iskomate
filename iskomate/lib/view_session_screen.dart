import 'package:flutter/material.dart';
import 'theme.dart';

class ViewSessionScreen extends StatelessWidget {
  final Map<String, String> session;

  const ViewSessionScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    // Example student data
    final students = [
      {'name': 'AUSTRIA, John Gwen Isaac', 'id': '2022-09934-MN-0'},
      {'name': 'RAMOS JR., Romulo D.', 'id': '2022-09934-MN-0'},
      {'name': 'TUAZON, Ivan Lawrence', 'id': '2022-09934-MN-0'},
      {'name': 'Sutelleza, John Keybird', 'id': '2022-09934-MN-0'},
      {'name': 'Yambot, Cedric', 'id': '2022-09934-MN-0'},
    ];

    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: kAccentColor,
        elevation: 0,
        title: const Text(
          'VIEW SESSION',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 18.0),
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
            Text(
              session['name'] ?? '',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
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
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                itemCount: students.length,
                separatorBuilder: (context, index) => Divider(
                  color: Colors.white.withOpacity(0.5),
                  thickness: 1,
                  height: 18,
                ),
                itemBuilder: (context, index) {
                  final student = students[index];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student['name']!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        student['id']!,
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