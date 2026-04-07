import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:erpms_app/app_shell.dart';
import 'package:erpms_app/models/alert_model.dart';
import 'package:erpms_app/create_alert_page.dart';
import 'package:geolocator/geolocator.dart';
import 'package:erpms_app/utils/location_helper.dart';

const Color _primaryBlue = Color(0xFF004AAD);

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  LatLng _initialPosition = const LatLng(19.0760, 72.8777); // Mumbai default
  Map<MarkerId, Marker> _markers = {};
  String? _userCity;
  String? _userRole;
  String? _volunteerGenre;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final data = userDoc.data()!;
          _userRole = data['role'] ?? 'user';
          _userCity = data['city'];
          _volunteerGenre = data['volunteer_genre'];
        }
      }

      Position position = await LocationHelper.getCurrentPosition();
      final detectedCity = await LocationHelper.getDistrictForPosition(position);
      
      setState(() {
        _userCity ??= detectedCity;
        _initialPosition = LatLng(position.latitude, position.longitude);
        _isLoading = false;
      });
      _fetchAlerts();
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _fetchAlerts() {
    FirebaseFirestore.instance.collection('alerts').where('status', isNotEqualTo: 'resolved').snapshots().listen((snapshot) {
      Map<MarkerId, Marker> newMarkers = {};
      for (var doc in snapshot.docs) {
        final alert = AlertModel.fromDoc(doc);
        final data = doc.data();
        bool isPublicized = data['isPublicized'] ?? false;
        
        bool isVisible = false;
        
        // 1. Admin sees EVERYTHING across all cities, but only publicized personal alerts.
        if (_userRole == 'admin') {
          if (alert.visibility == 'public' || isPublicized) {
            isVisible = true;
          }
        } 
        // 2. Volunteers see public alerts OR publicized personal alerts matching their genre.
        else if (_userRole == 'volunteer') {
          bool cityMatches = alert.district.trim().toLowerCase() == _userCity?.trim().toLowerCase();
          if (cityMatches) {
            if (alert.visibility == 'public') {
              isVisible = true;
            } else if (alert.visibility == 'personal' && isPublicized && _volunteerGenre == alert.type) {
              isVisible = true;
            }
          }
        }
        // 3. Regular users only see public alerts in their city.
        else {
          bool cityMatches = alert.district.trim().toLowerCase() == _userCity?.trim().toLowerCase();
          if (cityMatches && alert.visibility == 'public') {
            isVisible = true;
          }
        }

        if (isVisible) {
          final markerId = MarkerId(alert.id);
          final marker = Marker(
            markerId: markerId,
            position: LatLng(alert.location.latitude, alert.location.longitude),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              alert.visibility == 'public' ? BitmapDescriptor.hueRed : BitmapDescriptor.hueBlue
            ),
            infoWindow: InfoWindow(
              title: alert.title,
              snippet: '${alert.type} • Tap for details',
              onTap: () => _showAlertDetails(alert),
            ),
          );
          newMarkers[markerId] = marker;
        }
      }
      if (mounted) {
        setState(() {
          _markers = newMarkers;
        });
      }
    });
  }

  void _showAlertDetails(AlertModel alert) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(alert.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                _buildVisibilityBadge(alert.visibility),
              ],
            ),
            const SizedBox(height: 8),
            Text('Type: ${alert.type} • City: ${alert.district}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 12),
            Text(alert.description ?? 'No description provided'),
            const SizedBox(height: 20),
            
            if (alert.visibility == 'personal' && _userRole == 'volunteer' && alert.status == 'active' && _volunteerGenre == alert.type)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _engageAlert(alert.id),
                  style: ElevatedButton.styleFrom(backgroundColor: _primaryBlue, foregroundColor: Colors.white),
                  child: const Text('Claim Task / Responding'),
                ),
              ),
            
            if (alert.status == 'engaged')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                child: Text(
                  alert.engagedBy == FirebaseAuth.instance.currentUser?.uid 
                    ? 'You have claimed this task!' 
                    : 'Help is on the way! (Task Claimed)', 
                  textAlign: TextAlign.center, 
                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)
                ),
              ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildVisibilityBadge(String visibility) {
    bool isPublic = visibility == 'public';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: isPublic ? Colors.red.shade50 : Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
      child: Text(visibility.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isPublic ? Colors.red : Colors.blue)),
    );
  }

  Future<void> _engageAlert(String alertId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('alerts').doc(alertId).update({
        'status': 'engaged',
        'engagedBy': user?.uid,
      });
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task Claimed! Coordinate via rescue chat.')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Emergency Map',
      currentIndex: 2,
      isBodyScrollable: false,
      showAuxiliaryButtons: false,
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(target: _initialPosition, zoom: 12),
                onMapCreated: (controller) => _mapController = controller,
                markers: Set<Marker>.of(_markers.values),
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                zoomControlsEnabled: false,
              ),
              Positioned(
                bottom: 20,
                right: 16,
                child: FloatingActionButton(
                  onPressed: () => Navigator.push(
                    context, 
                    MaterialPageRoute(builder: (context) => CreateAlertPage(isAdminOrVolunteer: _userRole != 'user'))
                  ),
                  backgroundColor: _primaryBlue,
                  child: const Icon(Icons.add_alert, color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }
}
