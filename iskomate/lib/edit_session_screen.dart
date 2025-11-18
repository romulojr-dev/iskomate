import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'theme.dart';

class EditSessionScreen extends StatefulWidget {
  final Map<String, dynamic> sessionData;
  final String sessionId;

  const EditSessionScreen({super.key, required this.sessionData, required this.sessionId});

  @override
  State<EditSessionScreen> createState() => _EditSessionScreenState();
}

class _EditSessionScreenState extends State<EditSessionScreen> {
  late TextEditingController _nameController;
  final TextEditingController _studentNoController = TextEditingController();
  final TextEditingController _studentNameController = TextEditingController();
  final TextEditingController _studentIdController = TextEditingController();

  late List<Map<String, String>> students;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.sessionData['name']);
    students = (widget.sessionData['students'] as List<dynamic>? ?? [])
        .map((e) => {
              'name': e['name']?.toString() ?? '',
              'id': e['id']?.toString() ?? '',
            })
        .toList();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _studentNameController.dispose();
    _studentIdController.dispose();
    super.dispose();
  }

  void _addStudent() {
    final studentNo = _studentNoController.text.trim();
    if (studentNo.isNotEmpty) {
      setState(() {
        students.add({
          'name': studentNo,
          'id': '2022-09934-MN-0', // You can change this logic as needed
        });
        _studentNoController.clear();
      });
    }
  }

  Future<void> _saveChanges() async {
    await FirebaseFirestore.instance.collection('sessions').doc(widget.sessionId).update({
      'name': _nameController.text.trim(),
      'students': students,
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: kAccentColor,
        elevation: 0,
        title: const Text(
          'EDIT SESSION',
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
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.transparent,
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white, width: 1.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: kAccentColor, width: 2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kAccentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _saveChanges,
                  child: const Text('Save'),
                ),
              ],
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
              child: Scrollbar(
                thumbVisibility: true,
                child: ListView.separated(
                  itemCount: students.length,
                  separatorBuilder: (context, index) => Divider(
                    color: Colors.white.withOpacity(0.5),
                    thickness: 1,
                    height: 18,
                  ),
                  itemBuilder: (context, index) {
                    final student = students[index];
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
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
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              students.removeAt(index);
                            });
                          },
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Add Student:',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _studentNameController,
                    style: const TextStyle(
                      color: Colors.white,
                      fontStyle: FontStyle.italic,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Name',
                      hintStyle: const TextStyle(
                        color: Colors.white70,
                        fontStyle: FontStyle.italic,
                      ),
                      filled: true,
                      fillColor: Colors.transparent,
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white, width: 1.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: kAccentColor, width: 2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _studentIdController,
                    style: const TextStyle(
                      color: Colors.white,
                      fontStyle: FontStyle.italic,
                    ),
                    decoration: InputDecoration(
                      hintText: 'ID',
                      hintStyle: const TextStyle(
                        color: Colors.white70,
                        fontStyle: FontStyle.italic,
                      ),
                      filled: true,
                      fillColor: Colors.transparent,
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white, width: 1.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: kAccentColor, width: 2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kAccentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    final studentName = _studentNameController.text.trim();
                    final studentId = _studentIdController.text.trim();
                    if (studentName.isNotEmpty && studentId.isNotEmpty) {
                      setState(() {
                        students.add({'name': studentName, 'id': studentId});
                      });
                      _studentNameController.clear();
                      _studentIdController.clear();
                    }
                  },
                  child: const Text('Enter'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}