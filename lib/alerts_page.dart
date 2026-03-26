import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:erpms_app/app_shell.dart';
import 'package:erpms_app/models/alert_model.dart';
import 'package:erpms_app/utils/location_helper.dart';
import 'package:erpms_app/alert_detail_page.dart';

const Color _primaryBlue = Color(0xFF004AAD);

class AlertsPage extends StatefulWidget {
  final bool isSubPage;
  const AlertsPage({super.key, this.isSubPage = false});

  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> {
  String _detectedDistrict = 'loading...';
  Position? _currentPosition;
  bool showLocalOnly = true;
  String? _userRole;
  String? _userCity;
  String? _volunteerGenre;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _resolveLocation();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && mounted) {
        setState(() {
          _userRole = doc.data()?['role'];
          _userCity = doc.data()?['city'];
          _volunteerGenre = doc.data()?['volunteer_genre'];
        });
      }
    }
  }

  Future<void> _resolveLocation() async {
    try {
      final position = await LocationHelper.getCurrentPosition();
      final district = await LocationHelper.getDistrictForPosition(position);
      if (!mounted) return;
      setState(() {
        _currentPosition = position;
        _detectedDistrict = district ?? 'Unknown';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _detectedDistrict = 'Unknown';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    String currentDistrict = _detectedDistrict.trim();
    Widget content = Column(
      children: [
        // 1. Filter Toggle Buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => setState(() => showLocalOnly = true),
              style: ElevatedButton.styleFrom(
                backgroundColor: showLocalOnly ? _primaryBlue : Colors.grey.shade300,
                foregroundColor: showLocalOnly ? Colors.white : Colors.black87,
              ),
              child: Text("Near Me ($currentDistrict)"),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: () => setState(() => showLocalOnly = false),
              style: ElevatedButton.styleFrom(
                backgroundColor: !showLocalOnly ? _primaryBlue : Colors.grey.shade300,
                foregroundColor: !showLocalOnly ? Colors.white : Colors.black87,
              ),
              child: const Text("All India"),
            ),
          ],
        ),

        // 2. The List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _getFilteredStream(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text("Error: ${snapshot.error}"),
                  ),
                );
              }
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              
              final allDocs = snapshot.data!.docs;
              final filteredDocs = allDocs.where((doc) {
                final alert = AlertModel.fromDoc(doc);
                
                // Rule: Resolved alerts should NOT be visible in any alerts page
                if (alert.status == 'resolved') return false;

                // --- Category 1: PUBLIC ALERTS ---
                if (alert.visibility == 'public') {
                  if (showLocalOnly) {
                    return alert.district.trim().toLowerCase() == currentDistrict.toLowerCase();
                  }
                  return true; // All India
                }

                // --- Category 2: PERSONAL SOS (isSOS: true) ---
                if (alert.isSOS) {
                  // Only show if publicized
                  if (alert.isPublicized) {
                    // Visible to Admin or matching Volunteer
                    bool hasPrivilege = _userRole == 'admin' || (_userRole == 'volunteer' && _volunteerGenre == alert.type);
                    if (!hasPrivilege) return false;

                    if (showLocalOnly) {
                      return alert.district.trim().toLowerCase() == currentDistrict.toLowerCase();
                    }
                    return true; // All India
                  }
                  return false; // Initial SOS is private (only victim/emergency contact via hub)
                }

                // --- Category 3: MANUAL PERSONAL ALERTS (visibility: personal, isSOS: false) ---
                if (alert.visibility == 'personal') {
                  // Visible to admin or volunteer of same type
                  bool hasPrivilege = _userRole == 'admin' || (_userRole == 'volunteer' && _volunteerGenre == alert.type);
                  if (!hasPrivilege) return false;

                  if (showLocalOnly) {
                    return alert.district.trim().toLowerCase() == currentDistrict.toLowerCase();
                  }
                  return true;
                }
                
                return false;
              }).toList();

              if (filteredDocs.isEmpty) {
                return Center(child: Text("No alerts found for ${showLocalOnly ? currentDistrict : 'All India'}"));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filteredDocs.length,
                itemBuilder: (context, index) {
                  final model = AlertModel.fromDoc(filteredDocs[index]);
                  return _AlertCard(model: model, userPosition: _currentPosition);
                },
              );
            },
          ),
        ),
      ],
    );

    if (widget.isSubPage) {
      return content;
    }

    return AppShell(
      padBody: true,
      isBodyScrollable: false,
      body: content,
    );
  }

  Stream<QuerySnapshot> _getFilteredStream() {
    return FirebaseFirestore.instance
        .collection('alerts')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }
}

class _AlertCard extends StatelessWidget {
  final AlertModel model;
  final Position? userPosition;

  const _AlertCard({required this.model, this.userPosition});

  Color _severityColor() {
    switch (model.severity.toLowerCase()) {
      case 'critical':
        return Colors.red.shade600;
      case 'warning':
        return Colors.orange.shade600;
      default:
        return _primaryBlue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _severityColor();
    final isCritical = model.severity.toLowerCase() == 'critical';

    double? distance;
    if (userPosition != null) {
      distance = LocationHelper.haversineKm(
        userPosition!.latitude,
        userPosition!.longitude,
        model.location.latitude,
        model.location.longitude,
      );
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AlertDetailPage(alert: model),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCritical ? color : Colors.grey.shade300,
            width: isCritical ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _SeverityChip(severity: model.severity),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            model.title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1D3557),
                            ),
                          ),
                        ),
                        if (model.visibility == 'personal')
                          Icon(model.isSOS ? Icons.sos : Icons.person_outline, size: 14, color: Colors.blue),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _buildSubtitle(),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF4D4C4C),
                      ),
                    ),
                    if (distance != null && distance <= 1.0)
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(
                          'NEAR YOU',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: Colors.grey.shade500,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _buildSubtitle() {
    final timeAgo = _formatTimeAgo(model.timestamp.toDate());
    return '$timeAgo · ${model.district}';
  }

  String _formatTimeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return '${diff.inDays} d ago';
  }
}

class _SeverityChip extends StatelessWidget {
  final String severity;

  const _SeverityChip({required this.severity});

  @override
  Widget build(BuildContext context) {
    late Color color;
    late String label;
    IconData icon;

    switch (severity.toLowerCase()) {
      case 'critical':
        color = Colors.red.shade600;
        label = 'CRITICAL';
        icon = Icons.error_outline;
        break;
      case 'warning':
        color = Colors.orange.shade600;
        label = 'WARNING';
        icon = Icons.warning_amber_outlined;
        break;
      default:
        color = _primaryBlue;
        label = 'INFO';
        icon = Icons.info_outline;
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
