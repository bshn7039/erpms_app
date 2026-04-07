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
  StreamSubscription<DocumentSnapshot>? _incidentSubscription;
  StreamSubscription<DocumentSnapshot>? _responderLocationSubscription;
  
  GoogleMapController? _mapController;
  
  Map<String, dynamic>? _incidentData;
  Map<String, dynamic>? _responderData;
  GeoPoint? _victimLocation;
  GeoPoint? _helperLocation;
  
  bool _isVictim = false;
  String? _helperUid;

  @override
  void initState() {
    super.initState();
    _initSession();
  }

  Future<void> _initSession() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // 1. Get initial incident data
    final doc = await _firestore.collection('incidents').doc(widget.incidentId).get();
    if (!doc.exists) return;

    final data = doc.data()!;
    _isVictim = data['userId'] == user.uid;
    
    // 2. Identify who the "Helper" is (Volunteer or Emergency Contact)
    // If current user is victim, helper is engagedBy or emergency_contact_uid
    // If current user is helper, they are engagedBy or emergency_contact_uid
    if (_isVictim) {
      _helperUid = data['engagedBy'] ?? data['emergency_contact_uid'];
    } else {
      _helperUid = user.uid;
      // If I'm the helper and not yet "engaged", set me as engaged if I'm the emergency contact
      if (data['engagedBy'] == null && data['emergency_contact_uid'] == user.uid) {
        final userData = (await _firestore.collection('users').doc(user.uid).get()).data();
        await _firestore.collection('incidents').doc(widget.incidentId).update({
          'engagedBy': user.uid,
          'responderName': userData?['full_name'] ?? 'Emergency Contact',
          'status': 'engaged'
        });
        // Also update alert if it exists
        await _firestore.collection('alerts').doc(widget.incidentId).update({
          'status': 'engaged',
          'engagedBy': user.uid
        }).catchError((_) => null);
      }
    }

    if (mounted) {
      setState(() {
        _incidentData = data;
        _victimLocation = data['location'] as GeoPoint?;
      });
    }

    _startLocationUpdates();
    _listenToIncident();
    _listenToHelperLocation();
  }

  void _listenToIncident() {
    _incidentSubscription = _firestore.collection('incidents').doc(widget.incidentId).snapshots().listen((doc) async {
      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _incidentData = data;
          _victimLocation = data['location'] as GeoPoint?;
          // Update helper UID if it changes (e.g. someone engages)
          if (_isVictim) {
             _helperUid = data['engagedBy'] ?? data['emergency_contact_uid'];
          }
        });

        // Load helper's info (name, etc.)
        if (_helperUid != null && _responderData == null) {
          final respDoc = await _firestore.collection('users').doc(_helperUid).get();
          if (mounted) {
            setState(() {
              _responderData = respDoc.data();
            });
          }
        }
        
        if (_helperUid != null && _responderLocationSubscription == null) {
          _listenToHelperLocation();
        }
      }
    });
  }

  void _listenToHelperLocation() {
    if (_helperUid == null) return;
    
    _responderLocationSubscription = _firestore.collection('users').doc(_helperUid).snapshots().listen((userDoc) {
      if (userDoc.exists && mounted) {
        setState(() {
          _helperLocation = userDoc.data()?['current_location'] as GeoPoint?;
        });
        _updateMapBounds();
      }
    });
  }

  void _startLocationUpdates() {
    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
    ).listen((Position position) {
      final user = _auth.currentUser;
      if (user != null) {
        final geoPoint = GeoPoint(position.latitude, position.longitude);
        
        // Update user's global live location (important for others to see them)
        _firestore.collection('users').doc(user.uid).update({
          'current_location': geoPoint,
        });

        // If current user is the victim, update the incident's primary location
        if (_isVictim) {
          _firestore.collection('incidents').doc(widget.incidentId).update({
            'location': geoPoint,
            'last_update': FieldValue.serverTimestamp(),
          });
          // Also update alert location
          _firestore.collection('alerts').doc(widget.incidentId).update({
            'location': geoPoint,
          }).catchError((_) => null);
        }
      }
    });
  }

  void _updateMapBounds() {
    if (_mapController == null || _victimLocation == null || _helperLocation == null) return;

    LatLngBounds bounds;
    if (_victimLocation!.latitude > _helperLocation!.latitude) {
      bounds = LatLngBounds(
        southwest: LatLng(_helperLocation!.latitude, _helperLocation!.longitude < _victimLocation!.longitude ? _helperLocation!.longitude : _victimLocation!.longitude),
        northeast: LatLng(_victimLocation!.latitude, _helperLocation!.longitude > _victimLocation!.longitude ? _helperLocation!.longitude : _victimLocation!.longitude),
      );
    } else {
      bounds = LatLngBounds(
        southwest: LatLng(_victimLocation!.latitude, _victimLocation!.longitude < _helperLocation!.longitude ? _victimLocation!.longitude : _helperLocation!.longitude),
        northeast: LatLng(_helperLocation!.latitude, _victimLocation!.longitude > _helperLocation!.longitude ? _helperLocation!.longitude : _helperLocation!.longitude),
      );
    }
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 70));
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
    _incidentSubscription?.cancel();
    _responderLocationSubscription?.cancel();
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
          
          // 2. Responder/User Status
          _buildStatusBanner(),

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
      height: 250,
      child: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(_victimLocation?.latitude ?? 18.99, _victimLocation?.longitude ?? 73.12),
          zoom: 14,
        ),
        onMapCreated: (controller) => _mapController = controller,
        markers: {
          if (_victimLocation != null)
            Marker(
              markerId: const MarkerId('victim'),
              position: LatLng(_victimLocation!.latitude, _victimLocation!.longitude),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
              infoWindow: InfoWindow(title: _isVictim ? 'You' : (_incidentData?['userName'] ?? 'Victim')),
            ),
          if (_helperLocation != null)
            Marker(
              markerId: const MarkerId('helper'),
              position: LatLng(_helperLocation!.latitude, _helperLocation!.longitude),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
              infoWindow: InfoWindow(title: !_isVictim ? 'You' : (_responderData?['full_name'] ?? 'Responder')),
            ),
        },
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
      ),
    );
  }

  Widget _buildStatusBanner() {
    final status = _incidentData?['status'] ?? 'active';
    final isEngaged = status == 'engaged' || _helperUid != null;

    if (!isEngaged) {
      return Container(
        padding: const EdgeInsets.all(12),
        width: double.infinity,
        color: Colors.orange.shade50,
        child: Row(
          children: const [
            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange)),
            SizedBox(width: 12),
            Text('Searching for nearby responders...', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.orange)),
          ],
        ),
      );
    }

    double? distance;
    if (_victimLocation != null && _helperLocation != null) {
      distance = LocationHelper.haversineKm(
        _victimLocation!.latitude, _victimLocation!.longitude,
        _helperLocation!.latitude, _helperLocation!.longitude
      );
    }

    final displayName = _isVictim 
        ? (_responderData?['full_name'] ?? 'Emergency Contact') 
        : (_incidentData?['userName'] ?? 'Victim');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: _isVictim ? Colors.blue : Colors.red,
            child: Icon(_isVictim ? Icons.person : Icons.emergency, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(
                  _isVictim ? 'is responding to your SOS' : 'is the person in distress',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                if (distance != null)
                  Text('${distance.toStringAsFixed(1)} km away', style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          if (_isVictim && _responderData != null)
            IconButton(
              icon: const Icon(Icons.phone, color: Colors.green),
              onPressed: () => _launchCaller(_responderData!['phone'] ?? ''),
            ),
          if (!_isVictim && _incidentData != null)
            IconButton(
              icon: const Icon(Icons.phone, color: Colors.green),
              onPressed: () => _launchCaller(_incidentData!['userPhone'] ?? ''),
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
            final isSystem = data['senderId'] == 'system';

            if (isSystem) {
              return Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                  child: Text(data['text'] ?? '', style: const TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic)),
                ),
              );
            }
            
            return Align(
              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
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
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade200))),
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
              icon: const Icon(Icons.send, color: Colors.white, size: 20),
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
              await _firestore.collection('alerts').doc(widget.incidentId).update({'status': 'resolved'}).catchError((_) => null);
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
