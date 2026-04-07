import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:erpms_app/app_shell.dart';
import 'package:erpms_app/models/alert_model.dart';

const Color _primaryBlue = Color(0xFF004AAD);
const Color _navyTitle = Color(0xFF1D3557);
const Color _textDark = Color(0xFF4D4C4C);

class AdminIncidentsPage extends StatefulWidget {
  const AdminIncidentsPage({super.key});

  @override
  State<AdminIncidentsPage> createState() => _AdminIncidentsPageState();
}

class _AdminIncidentsPageState extends State<AdminIncidentsPage> {
  String _searchCity = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Active Incidents',
      isBodyScrollable: false,
      showAuxiliaryButtons: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          _buildSearchBar(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No active or engaged incidents found.'));
                }

                // Convert docs to models and filter by city in memory for flexible search
                final allAlerts = snapshot.data!.docs.map((doc) => AlertModel.fromDoc(doc)).toList();
                
                // Extra safety: Filter out any 'resolved' status alerts that might have slipped through
                final activeAlerts = allAlerts.where((a) => a.status != 'resolved').toList();

                final filteredAlerts = _searchCity.isEmpty
                    ? activeAlerts
                    : activeAlerts.where((alert) => 
                        alert.district.toLowerCase().contains(_searchCity.toLowerCase())
                      ).toList();

                if (filteredAlerts.isEmpty) {
                  return const Center(child: Text('No matching incidents found.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredAlerts.length,
                  itemBuilder: (context, index) {
                    return _IncidentCard(alert: filteredAlerts[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _getStream() {
    // Show both active and engaged incidents only. 
    // This query explicitly excludes 'resolved' status.
    return FirebaseFirestore.instance
        .collection('alerts')
        .where('status', whereIn: ['active', 'engaged'])
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('Back to Command Center'),
          ),
          const SizedBox(height: 8),
          const Text(
            'Incident Management (Nationwide)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _navyTitle),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Filter by City',
          prefixIcon: const Icon(Icons.search, color: _primaryBlue),
          suffixIcon: _searchCity.isNotEmpty 
            ? IconButton(
                icon: const Icon(Icons.clear), 
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchCity = '');
                }
              ) 
            : null,
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
        onChanged: (val) {
          setState(() => _searchCity = val.trim());
        },
      ),
    );
  }
}

class _IncidentCard extends StatelessWidget {
  final AlertModel alert;
  const _IncidentCard({required this.alert});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    alert.title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _navyTitle),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Row(
                  children: [
                    _buildStatusBadge(alert.status),
                    const SizedBox(width: 4),
                    _buildSeverityBadge(alert.severity),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(alert.district, style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500)),
              ],
            ),
            if (alert.description != null && alert.description!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                alert.description!, 
                style: const TextStyle(fontSize: 13, color: _textDark),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _resolveIncident(context, alert.id),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Resolve Incident', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = status.toLowerCase() == 'engaged' ? Colors.orange : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Text(status.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
    );
  }

  Widget _buildSeverityBadge(String severity) {
    Color color;
    switch (severity.toLowerCase()) {
      case 'critical': color = Colors.red; break;
      case 'warning': color = Colors.orange; break;
      case 'high': color = Colors.redAccent; break;
      default: color = Colors.blue;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Text(severity.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
    );
  }

  Future<void> _resolveIncident(BuildContext context, String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Resolve Incident?'),
        content: const Text('This will mark the incident as completed and remove it from the active list.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Resolve both Alert and Incident (they share ID)
      await FirebaseFirestore.instance.collection('alerts').doc(id).update({'status': 'resolved'});
      await FirebaseFirestore.instance.collection('incidents').doc(id).update({'status': 'resolved'}).catchError((_) => null);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Incident marked as Resolved')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error resolving incident: $e')));
      }
    }
  }
}
