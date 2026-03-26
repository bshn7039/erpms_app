import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:erpms_app/app_shell.dart';
import 'package:erpms_app/active_assistance_page.dart';

const Color _primaryBlue = Color(0xFF004AAD);

class AssistantHubPage extends StatelessWidget {
  const AssistantHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const AppShell(body: Center(child: Text('Please log in to access Assistant Hub.')));
    }

    return AppShell(
      title: 'Assistant Hub',
      isBodyScrollable: false, 
      currentIndex: -1, 
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            child: Text(
              'Active & Recent Assistance',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1D3557)),
            ),
          ),
          const Divider(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('incidents')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                final allIncidents = snapshot.data!.docs;
                final myIncidents = allIncidents.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['userId'] == user.uid || 
                         data['engagedBy'] == user.uid || 
                         data['emergency_contact_uid'] == user.uid;
                }).toList();

                if (myIncidents.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  itemCount: myIncidents.length,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  itemBuilder: (context, index) {
                    final data = myIncidents[index].data() as Map<String, dynamic>;
                    final docId = myIncidents[index].id;
                    return _buildIncidentCard(context, docId, data, user.uid);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No active assistance sessions.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            'SOS incidents and Volunteer chats will appear here.',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildIncidentCard(BuildContext context, String docId, Map<String, dynamic> data, String currentUid) {
    final status = data['status'] ?? 'active';
    final type = data['type'] ?? 'Emergency';
    final timestamp = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
    final isResolved = status == 'resolved';
    
    final isVictim = data['userId'] == currentUid;
    final otherPartyName = isVictim ? (data['responderName'] ?? 'Searching for Help...') : (data['userName'] ?? 'User');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12), 
        side: BorderSide(color: isResolved ? Colors.grey.shade200 : (isVictim ? Colors.red.shade200 : Colors.blue.shade200))
      ),
      elevation: isResolved ? 0 : 3,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: isResolved ? Colors.grey : (isVictim ? Colors.red : Colors.blue),
          child: Icon(isVictim ? Icons.emergency : Icons.volunteer_activism, color: Colors.white),
        ),
        title: Text(
          isVictim ? 'My Emergency: $type' : 'Help Request from $otherPartyName',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Contact: $otherPartyName', style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 4),
              Text(
                '${timestamp.day}/${timestamp.month}/${timestamp.year} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isResolved ? Colors.grey.shade100 : (status == 'engaged' ? Colors.green.shade50 : Colors.orange.shade50),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isResolved ? Colors.grey : (status == 'engaged' ? Colors.green : Colors.orange),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Icon(Icons.chevron_right, size: 20),
              ],
            ),
            if (isVictim)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () => _confirmDeletion(context, docId),
              ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ActiveAssistancePage(incidentId: docId)),
          );
        },
      ),
    );
  }

  void _confirmDeletion(BuildContext context, String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Session?'),
        content: const Text('This will permanently delete this assistance session and the connected alert record.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteIncidentAndAlert(docId);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteIncidentAndAlert(String docId) async {
    final firestore = FirebaseFirestore.instance;
    // 1. Delete Incident
    await firestore.collection('incidents').doc(docId).delete();
    // 2. Delete Alert (assuming alertId == docId as per my previous SOS implementation)
    await firestore.collection('alerts').doc(docId).delete();
  }
}
