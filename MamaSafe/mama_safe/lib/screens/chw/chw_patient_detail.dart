import 'package:flutter/material.dart';

class CHWPatientDetail extends StatelessWidget {
  final Map<String, String> patient;

  const CHWPatientDetail({super.key, required this.patient});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Patient Details")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Name: ${patient["name"]}"),
            Text("Risk: ${patient["risk"]}"),
            SizedBox(height: 20),
            Text("History (Dummy):"),
            Text("2025-09-01: BP 120/80, BS 95 mg/dL"),
            Text("2025-09-15: BP 130/85, BS 110 mg/dL"),
          ],
        ),
      ),
    );
  }
}
