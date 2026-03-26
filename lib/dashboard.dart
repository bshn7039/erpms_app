import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'dart:io';

// #region agent log helper
void _agentDebugLogDashboard({
  required String runId,
  required String hypothesisId,
  required String location,
  required String message,
  Map<String, Object?> data = const {},
}) {
  final payload = <String, Object?>{
    'sessionId': 'e62326',
    'runId': runId,
    'hypothesisId': hypothesisId,
    'location': location,
    'message': message,
    'data': data,
    'timestamp': DateTime.now().millisecondsSinceEpoch,
  };
  try {
    final file = File('debug-e62326.log');
    file.writeAsStringSync('${jsonEncode(payload)}\n',
        mode: FileMode.append, flush: true);
  } catch (_) {
    // Swallow any logging errors to avoid impacting app flow
  }
}
// #endregion agent log helper

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    // #region agent log
    _agentDebugLogDashboard(
      runId: 'initial',
      hypothesisId: 'H5',
      location: 'lib/dashboard.dart:DashboardPage.build',
      message: 'DashboardPage build called',
      data: {},
    );
    // #endregion agent log
    return Scaffold(
      appBar: AppBar(
        title: const Text("ERPMS Dashboard"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          // THIS IS YOUR LOGOUT BUTTON
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              // Goes back to Login Screen
              Navigator.of(context).pushReplacementNamed('/');
            },
          )
        ],
      ),
      body: GridView.count(
        padding: const EdgeInsets.all(20),
        crossAxisCount: 2,
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
        children: [
          _menuItem(context, "Students", Icons.people, Colors.blue),
          _menuItem(context, "Attendance", Icons.how_to_reg, Colors.green),
          _menuItem(context, "Resources", Icons.inventory_2, Colors.orange),
          _menuItem(context, "Settings", Icons.settings, Colors.grey),
        ],
      ),
    );
  }

  Widget _menuItem(BuildContext context, String title, IconData icon, Color color) {
    return Card(
      elevation: 4,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 40, color: color),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}