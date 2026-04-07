import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:erpms_app/app_shell.dart';
import 'package:erpms_app/models/alert_model.dart';
import 'package:erpms_app/active_assistance_page.dart';

const Color _primaryBlue = Color(0xFF004AAD);
const Color _navyTitle = Color(0xFF1D3557);

class AlertDetailPage extends StatefulWidget {
  final AlertModel alert;

  const AlertDetailPage({super.key, required this.alert});

  @override
  State<AlertDetailPage> createState() => _AlertDetailPageState();
}

class _AlertDetailPageState extends State<AlertDetailPage> {
  String? _userRole;
  String? _volunteerGenre;
  bool _isLoadingUser = true;
  late AlertModel _currentAlert;

  @override
  void initState() {
    super.initState();
    _currentAlert = widget.alert;
    _loadUserData();
    _listenToAlertUpdates();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists && mounted) {
          setState(() {
            _userRole = doc.data()?['role'];
            _volunteerGenre = doc.data()?['volunteer_genre'];
          });
        }
      }
    } finally {
      if (mounted) setState(() => _isLoadingUser = false);
    }
  }

  void _listenToAlertUpdates() {
    FirebaseFirestore.instance.collection('alerts').doc(_currentAlert.id).snapshots().listen((doc) {
      if (doc.exists && mounted) {
        setState(() {
          _currentAlert = AlertModel.fromDoc(doc);
        });
      }
    });
  }

  Future<void> _engageAlert() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userData = userDoc.data();
      final responderName = userData?['full_name'] ?? 'Volunteer';

      // 1. Update the alert
      await FirebaseFirestore.instance.collection('alerts').doc(_currentAlert.id).update({
        'status': 'engaged',
        'engagedBy': user.uid,
      });

      // 2. Ensure corresponding incident exists and update it
      final incidentId = _currentAlert.id; 
      final incidentRef = FirebaseFirestore.instance.collection('incidents').doc(incidentId);
      final incidentDoc = await incidentRef.get();

      if (!incidentDoc.exists) {
        // If for some reason the incident record is missing, reconstruct it from alert data
        await incidentRef.set({
          'userId': _currentAlert.createdBy,
          'status': 'engaged',
          'type': _currentAlert.type,
          'timestamp': _currentAlert.timestamp,
          'location': _currentAlert.location,
          'district': _currentAlert.district,
          'visibility': _currentAlert.visibility,
          'isSOS': _currentAlert.isSOS,
          'engagedBy': user.uid,
          'responderName': responderName,
          'description': _currentAlert.description,
        });
      } else {
        await incidentRef.update({
          'status': 'engaged',
          'engagedBy': user.uid,
          'responderName': responderName,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task Claimed! Navigating to Assistance Hub...')),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => ActiveAssistancePage(incidentId: incidentId)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lat = _currentAlert.location.latitude;
    final lng = _currentAlert.location.longitude;
    final user = FirebaseAuth.instance.currentUser;

    bool isSOS = _currentAlert.isSOS;
    // Rule: Only personal or private alerts (SOS or regular personal alerts) are engageable tasks.
    bool canEngage = (_currentAlert.visibility == 'personal' || _currentAlert.visibility == 'private') &&
                     _userRole == 'volunteer' && 
                     _currentAlert.status == 'active' && 
                     _volunteerGenre == _currentAlert.type;

    return AppShell(
      padBody: true,
      isBodyScrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 4),
              const Text(
                'Incident Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _navyTitle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _currentAlert.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _navyTitle,
                  ),
                ),
              ),
              _buildVisibilityBadge(_currentAlert.visibility),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.35,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(lat, lng),
                  zoom: 15,
                ),
                markers: {
                  Marker(
                    markerId: const MarkerId('alert'),
                    position: LatLng(lat, lng),
                  ),
                },
                circles: {
                  Circle(
                    circleId: const CircleId('impact'),
                    center: LatLng(lat, lng),
                    radius: 500,
                    fillColor: (isSOS ? Colors.red : Colors.blue).withOpacity(0.12),
                    strokeColor: (isSOS ? Colors.red : Colors.blue).withOpacity(0.5),
                    strokeWidth: 1,
                  ),
                },
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          if (_currentAlert.status == 'engaged')
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _currentAlert.engagedBy == user?.uid 
                        ? 'You have claimed this task!' 
                        : 'Help is on the way! (Task Claimed)',
                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

          Row(
            children: [
              _infoTile(Icons.category_outlined, 'Type', _currentAlert.type),
              const SizedBox(width: 16),
              _infoTile(Icons.location_city_outlined, 'City', _currentAlert.district),
            ],
          ),
          const SizedBox(height: 16),
          if (_currentAlert.isOfficial)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.verified, size: 16, color: _primaryBlue),
                  SizedBox(width: 4),
                  Text(
                    'Official Alert',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _primaryBlue,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          const Text(
            'Description',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: _navyTitle,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _currentAlert.description ?? 'No additional details provided.',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF4D4C4C),
              height: 1.4,
            ),
          ),
          
          if (_currentAlert.detailedAddress != null && _currentAlert.detailedAddress!.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Detailed Address / Location Note',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _navyTitle,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade100),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_pin, color: Colors.orange, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _currentAlert.detailedAddress!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF4D4C4C),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          if (_currentAlert.imageBase64 != null) ...[
            const SizedBox(height: 16),
            const Text(
              'Attached Photo',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _navyTitle,
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                base64Decode(_currentAlert.imageBase64!),
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ],
          
          const SizedBox(height: 32),
          
          if (canEngage)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.handshake_outlined),
                label: const Text('CLAIM TASK / I AM RESPONDING', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _engageAlert,
              ),
            ),
          
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.directions_outlined),
              label: const Text('NAVIGATE TO SITE', style: TextStyle(fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                foregroundColor: _primaryBlue,
                side: const BorderSide(color: _primaryBlue),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
                launchUrl(uri, mode: LaunchMode.externalApplication);
              },
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: _primaryBlue),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _navyTitle), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisibilityBadge(String visibility) {
    bool isSOS = _currentAlert.isSOS;
    Color badgeColor;
    if (isSOS) {
      badgeColor = Colors.red;
    } else if (visibility == 'personal') {
      badgeColor = Colors.blue;
    } else if (visibility == 'private') {
      badgeColor = Colors.orange;
    } else {
      badgeColor = Colors.green;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isSOS ? 'EMERGENCY SOS' : visibility.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: badgeColor,
        ),
      ),
    );
  }
}
