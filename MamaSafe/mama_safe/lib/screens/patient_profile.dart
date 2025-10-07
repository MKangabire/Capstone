import 'package:flutter/material.dart';
import '../models/user.dart';

class PatientProfile extends StatefulWidget {
  final User user;
  const PatientProfile({super.key, required this.user});

  @override
  State<PatientProfile> createState() => _PatientProfileState();
}

class _PatientProfileState extends State<PatientProfile> {
  final TextEditingController _visitController = TextEditingController();

  void _addVisit() {
    if (_visitController.text.isNotEmpty) {
      setState(() {
        widget.user.visits.add(_visitController.text);
        _visitController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Patient Profile")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Text("Patient: ${widget.user.email}",
                style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 20),
            TextField(
              controller: _visitController,
              decoration: const InputDecoration(
                  labelText: "Add Visit", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            ElevatedButton(onPressed: _addVisit, child: const Text("Add Visit")),
            const SizedBox(height: 20),
            const Text("Visits:"),
            Expanded(
              child: ListView.builder(
                itemCount: widget.user.visits.length,
                itemBuilder: (context, index) {
                  return ListTile(title: Text(widget.user.visits[index]));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
