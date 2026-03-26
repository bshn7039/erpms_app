import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:erpms_app/app_shell.dart';
import 'package:erpms_app/utils/location_helper.dart';

const Color _primaryBlue = Color(0xFF004AAD);

class ActiveAssistancePage extends StatefulWidget {
  final String incidentId;
  const ActiveAssistancePage({super.key, required this.incidentId});

  @override
  State<ActiveAssistancePage> createState() => _ActiveAssistancePageState();
}

class _ActiveAssistancePageState extends State<ActiveAssistancePage> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  
  StreamSubscription<Position>? _locationSubscription;
  GoogleMapController? _mapController;
  
  Map<String, dynamic>? _incidentData;
  Map<String, dynamic>? _responderData;
  GeoPoint? _userLocation;
  GeoPoint? _responderLocation;

  @override
  void initState() {
    super.initState();
    _startLocationUpdates();
    _listenToIncident();
  }

  void _listenToIncident() {
    _firestore.collection('incidents').doc(widget.incidentId).snapshots().listen((doc) async {
      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _incidentData = data;
          _userLocation = data['location'] as GeoPoint?;
        });

        // If a responder has engaged
        if (data['engagedBy'] != null && _responderData == null) {
          final respDoc = await _firestore.collection('users').doc(data['engagedBy']).get();
          if (mounted) {
            setState(() {
              _responderData = respDoc.data();
            });
          }
        }

        // Listen for responder's live location if they are engaged
        if (data['engagedBy'] != null) {
          _firestore.collection('users').doc(data['engagedBy']).snapshots().listen((userDoc) {
            if (userDoc.exists && mounted) {
              setState(() {
                _responderLocation = userDoc.data()?['current_location'] as GeoPoint?;
              });
              _updateMapBounds();
            }
          });
        }
      }
    });
  }

  void _startLocationUpdates() {
    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
    ).listen((Position position) {
      final user = _auth.currentUser;
      if (user != null) {
        // Update both the specific incident and the user's global live location
        _firestore.collection('incidents').doc(widget.incidentId).update({
          'location': GeoPoint(position.latitude, position.longitude),
          'last_update': FieldValue.serverTimestamp(),
        });
        _firestore.collection('users').doc(user.uid).update({
          'current_location': GeoPoint(position.latitude, position.longitude),
        });
      }
    });
  }

  void _updateMapBounds() {
    if (_mapController == null || _userLocation == null || _responderLocation == null) return;

    LatLngBounds bounds;
    if (_userLocation!.latitude > _responderLocation!.latitude) {
      bounds = LatLngBounds(
        southwest: LatLng(_responderLocation!.latitude, _responderLocation!.longitude < _userLocation!.longitude ? _responderLocation!.longitude : _userLocation!.longitude),
        northeast: LatLng(_userLocation!.latitude, _responderLocation!.longitude > _userLocation!.longitude ? _responderLocation!.longitude : _userLocation!.longitude),
      );
    } else {
      bounds = LatLngBounds(
        southwest: LatLng(_userLocation!.latitude, _userLocation!.longitude < _responderLocation!.longitude ? _userLocation!.longitude : _responderLocation!.longitude),
        northeast: LatLng(_responderLocation!.latitude, _userLocation!.longitude > _responderLocation!.longitude ? _responderLocation!.longitude : _userLocation!.longitude),
      );
    }
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    final user = _auth.currentUser;
    if (user == null) return;

    final text = _messageController.text.trim();
    _messageController.clear();

    await _firestore.collection('incidents').doc(widget.incidentId).collection('messages').add({
      'senderId': user.uid,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    });
    
    _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assistance Hub', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: _primaryBlue,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: () => _confirmResolve(),
            child: const Text('RESOLVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      ),
      body: Column(
        children: [
          // 1. Live Map Tracker
          _buildMapSection(),
          
          // 2. Responder Status
          _buildResponderStatus(),

          // 3. Chat Messages
          Expanded(child: _buildChatSection()),

          // 4. Input Area
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMapSection() {
    return SizedBox(
      height: 200,
      child: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(_userLocation?.latitude ?? 0, _userLocation?.longitude ?? 0),
          zoom: 14,
        ),
        onMapCreated: (controller) => _mapController = controller,
        markers: {
          if (_userLocation != null)
            Marker(
              markerId: const MarkerId('me'),
              position: LatLng(_userLocation!.latitude, _userLocation!.longitude),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
              infoWindow: const InfoWindow(title: 'You'),
            ),
          if (_responderLocation != null)
            Marker(
              markerId: const MarkerId('responder'),
              position: LatLng(_responderLocation!.latitude, _responderLocation!.longitude),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
              infoWindow: InfoWindow(title: _responderData?['full_name'] ?? 'Responder'),
            ),
        },
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
      ),
    );
  }

  Widget _buildResponderStatus() {
    if (_responderData == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        color: Colors.orange.shade50,
        child: Row(
          children: const [
            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 12),
            Text('Waiting for a responder to engage...', style: TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }

    double? distance;
    if (_userLocation != null && _responderLocation != null) {
      distance = LocationHelper.haversineKm(
        _userLocation!.latitude, _userLocation!.longitude,
        _responderLocation!.latitude, _responderLocation!.longitude
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: _primaryBlue,
            child: Text(_responderData!['full_name'][0], style: const TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_responderData!['full_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(distance != null ? '${distance.toStringAsFixed(1)} km away' : 'Calculating distance...', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.phone, color: Colors.green),
            onPressed: () => _launchCaller(_responderData!['phone'] ?? ''),
          ),
        ],
      ),
    );
  }

  Widget _buildChatSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('incidents').doc(widget.incidentId).collection('messages').orderBy('timestamp', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final docs = snapshot.data!.docs;
        return ListView.builder(
          reverse: true,
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final isMe = data['senderId'] == _auth.currentUser?.uid;
            
            return Align(
              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isMe ? _primaryBlue : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(15).copyWith(
                    bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(15),
                    bottomLeft: isMe ? const Radius.circular(15) : const Radius.circular(0),
                  ),
                ),
                child: Text(
                  data['text'] ?? '',
                  style: TextStyle(color: isMe ? Colors.white : Colors.black87),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInputArea() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: _primaryBlue,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchCaller(String number) async {
    final Uri url = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  void _confirmResolve() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Assistance?'),
        content: const Text('This will resolve the incident and stop all location tracking.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await _firestore.collection('incidents').doc(widget.incidentId).update({'status': 'resolved'});
              if (mounted) {
                Navigator.pop(context); // Dialog
                Navigator.pop(context); // This Page
              }
            },
            child: const Text('RESOLVE', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
