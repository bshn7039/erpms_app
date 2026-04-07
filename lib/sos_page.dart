import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:erpms_app/active_assistance_page.dart';
import 'package:erpms_app/utils/location_helper.dart';

class SosPage extends StatefulWidget {
  const SosPage({super.key});

  @override
  State<SosPage> createState() => _SosPageState();
}

class _SosPageState extends State<SosPage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  StreamSubscription<Position>? _positionStream;
  String? _selectedDistressType;
  bool _isLocating = true;
  String? _incidentId;
  String? _emergencyContactPhone;
  bool _isVerified = false;
  bool _isPublicized = false;
  bool _isPublicizing = false;
  String? _resolvedDistrict;
  bool _isCheckingExisting = true;

  // Standardized Alert Types mapping to authority contacts
  final Map<String, List<Map<String, String>>> _authorityContacts = {
    'Medical': [
      {'name': 'Ambulance', 'number': '108', 'desc': 'Emergency medical services'},
      {'name': 'National Health Helpline', 'number': '1075', 'desc': 'Health related queries'},
    ],
    'Physical': [
      {'name': 'Police', 'number': '100', 'desc': 'Emergency police assistance'},
      {'name': 'Emergency Response', 'number': '112', 'desc': 'Single emergency number'},
      {'name': 'Women Helpline', 'number': '1091', 'desc': 'Domestic violence or assault'},
    ],
    'Fire': [
      {'name': 'Fire Brigade', 'number': '101', 'desc': 'Fire emergency services'},
      {'name': 'Disaster Management', 'number': '108', 'desc': 'Floods, earthquakes, etc.'},
    ],
    'Rescue': [
      {'name': 'Disaster Management', 'number': '108', 'desc': 'Search and Rescue operations'},
      {'name': 'NDRF', 'number': '011-24363260', 'desc': 'National Disaster Response Force'},
    ],
    'Logistics': [
      {'name': 'Emergency Response', 'number': '112', 'desc': 'Supply chain and shelter aid'},
    ],
    'Tech': [
      {'name': 'Cyber Crime', 'number': '1930', 'desc': 'Report financial/cyber fraud'},
    ],
    'Flood': [
      {'name': 'Flood Control Room', 'number': '1070', 'desc': 'State level flood relief'},
    ],
    'General': [
      {'name': 'Emergency Response', 'number': '112', 'desc': 'All-in-one emergency number'},
    ],
  };

  @override
  void initState() {
    super.initState();
    _checkAndInitialize();
  }

  Future<void> _checkAndInitialize() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userData = userDoc.data();
    
    _isVerified = userData?['phone_verified'] as bool? ?? false;
    _emergencyContactPhone = userData?['emergency_contact_phone'];

    if (!_isVerified) {
      setState(() => _isCheckingExisting = false);
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Action Required'),
            content: const Text('You must connect and verify your mobile number in your Profile before using SOS features.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Go Back')),
            ],
          ),
        ).then((_) => Navigator.pop(context));
      }
      return;
    }

    // Check for existing active SOS incident
    final existingIncident = await _firestore.collection('incidents')
        .where('userId', isEqualTo: user.uid)
        .where('isSOS', isEqualTo: true)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();

    if (existingIncident.docs.isNotEmpty) {
      final doc = existingIncident.docs.first;
      final data = doc.data();
      setState(() {
        _incidentId = doc.id;
        _isPublicized = data['isPublicized'] ?? false;
        _selectedDistressType = data['type'] == 'Pending Selection' ? null : data['type'];
        _resolvedDistrict = data['district'] == 'Locating...' ? null : data['district'];
        _isCheckingExisting = false;
      });
      _startLocationStream();
    } else {
      setState(() => _isCheckingExisting = false);
      _initializeSOS(userDoc);
    }
  }

  Future<void> _initializeSOS(DocumentSnapshot userDoc) async {
    final user = _auth.currentUser!;
    _startLocationStream();

    // Create Incident - Initially private
    final newIncident = await _firestore.collection('incidents').add({
      'userId': user.uid,
      'userName': userDoc.get('full_name') ?? 'Unknown User',
      'userPhone': userDoc.get('phone'),
      'status': 'active',
      'type': 'Pending Selection',
      'timestamp': FieldValue.serverTimestamp(),
      'emergency_contact': _emergencyContactPhone,
      'location': null,
      'district': 'Locating...',
      'visibility': 'personal',
      'isPublicized': false,
      'isSOS': true,
    });
    _incidentId = newIncident.id;

    // Create a record in 'alerts' - Initially NOT publicized
    await _firestore.collection('alerts').doc(_incidentId).set({
      'title': 'SOS: ${userDoc.get('full_name') ?? 'User'}',
      'district': 'Locating...',
      'location': null, 
      'isOfficial': false,
      'severity': 'Critical',
      'status': 'active',
      'visibility': 'personal',
      'isPublicized': false,
      'isSOS': true,
      'type': 'General',
      'createdBy': user.uid,
      'timestamp': FieldValue.serverTimestamp(),
      'description': 'Emergency SOS triggered. User needs immediate assistance.',
      'incidentId': _incidentId,
    });
    
    await _firestore.collection('incidents').doc(_incidentId).collection('messages').add({
      'senderId': 'system',
      'text': 'SOS Triggered. Sharing live location with emergency contacts.',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  void _startLocationStream() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position position) async {
        if (mounted) setState(() => _isLocating = false);
        final geoPoint = GeoPoint(position.latitude, position.longitude);
        
        // Resolve district name from coordinates if not already done
        if (_resolvedDistrict == null || _resolvedDistrict == 'Locating...') {
          try {
            final district = await LocationHelper.getDistrictForPosition(position);
            if (district != null) {
              setState(() => _resolvedDistrict = district);
            }
          } catch (e) {
            debugPrint("Reverse geocoding failed: $e");
          }
        }

        if (_incidentId != null) {
          final Map<String, dynamic> updates = {
            'location': geoPoint,
            'last_update': FieldValue.serverTimestamp(),
          };
          if (_resolvedDistrict != null) {
            updates['district'] = _resolvedDistrict;
          }

          await _firestore.collection('incidents').doc(_incidentId).update(updates);
          
          final Map<String, dynamic> alertUpdates = {
            'location': geoPoint,
          };
          if (_resolvedDistrict != null) {
            alertUpdates['district'] = _resolvedDistrict;
          }
          await _firestore.collection('alerts').doc(_incidentId).update(alertUpdates);
          
          // Update user's global location for tracking
          await _firestore.collection('users').doc(_auth.currentUser?.uid).update({
            'current_location': geoPoint,
          });
        }
      },
    );
  }

  Future<void> _updateDistressType(String? type) async {
    if (type == null || _incidentId == null) return;
    setState(() => _selectedDistressType = type);
    await _firestore.collection('incidents').doc(_incidentId).update({'type': type});
    await _firestore.collection('alerts').doc(_incidentId).update({'type': type});
    
    await _firestore.collection('incidents').doc(_incidentId).collection('messages').add({
      'senderId': 'system',
      'text': 'Distress Type Selected: $type. Relevant authorities have been notified.',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _publicizeAlert() async {
    if (_selectedDistressType == null || _incidentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an emergency type first!'))
      );
      return;
    }

    setState(() => _isPublicizing = true);

    try {
      await _firestore.collection('incidents').doc(_incidentId).update({'isPublicized': true});
      await _firestore.collection('alerts').doc(_incidentId).update({'isPublicized': true});
      
      await _firestore.collection('incidents').doc(_incidentId).collection('messages').add({
        'senderId': 'system',
        'text': 'Alert publicized! Admins and volunteers have been notified.',
        'timestamp': FieldValue.serverTimestamp(),
      });

      setState(() {
        _isPublicized = true;
        _isPublicizing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alert publicized to all volunteers and admins!'))
        );
      }
    } catch (e) {
      setState(() => _isPublicizing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to publicize: $e'))
        );
      }
    }
  }

  Future<void> _launchCaller(String number) async {
    final Uri url = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingExisting) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFDF2F2),
      appBar: AppBar(
        title: const Text('SOS - EMERGENCY', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.red.shade800,
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStatusIndicator(),
            const SizedBox(height: 24),
            const Text(
              "What is the nature of your emergency?",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            _buildDistressDropdown(),
            const SizedBox(height: 16),
            
            ElevatedButton.icon(
              onPressed: (_isPublicized || _isPublicizing || _selectedDistressType == null) 
                ? null 
                : _publicizeAlert,
              icon: _isPublicizing 
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.public),
              label: Text(_isPublicized ? "ALREADY PUBLICIZED" : "PUBLICIZE (Alert Volunteers)"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade800,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),

            const SizedBox(height: 24),
            if (_selectedDistressType != null) ...[
              Text(
                "Recommended Authorities for $_selectedDistressType",
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              Expanded(child: _buildAuthorityList()),
            ] else 
              const Expanded(child: Center(child: Text("Please select a distress type to see help numbers", style: TextStyle(fontStyle: FontStyle.italic)))),
            
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                if (_incidentId != null) {
                  Navigator.push(
                    context, 
                    MaterialPageRoute(builder: (context) => ActiveAssistancePage(incidentId: _incidentId!))
                  );
                }
              },
              icon: const Icon(Icons.chat_bubble),
              label: const Text("Open Assistance Hub / Chat"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Row(
        children: [
          _isLocating 
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red))
            : const Icon(Icons.location_on, color: Colors.green, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isLocating ? "Fetching Live Location..." : "Sharing Live Location",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  _resolvedDistrict != null && _resolvedDistrict != 'Locating...'
                    ? "Region: $_resolvedDistrict"
                    : "Identifying your region...",
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistressDropdown() {
    return DropdownSearch<String>(
      items: (filter, loadProps) => _authorityContacts.keys.toList(),
      decoratorProps: const DropDownDecoratorProps(
        decoration: InputDecoration(
          labelText: "Select Emergency Type",
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.search),
        ),
      ),
      onChanged: (String? newValue) {
        _updateDistressType(newValue);
      },
      selectedItem: _selectedDistressType,
      popupProps: const PopupProps.menu(
        showSearchBox: true,
        searchFieldProps: TextFieldProps(
          decoration: InputDecoration(
            hintText: "Search categories...",
            prefixIcon: Icon(Icons.search),
          ),
        ),
      ),
    );
  }

  Widget _buildAuthorityList() {
    final contacts = _authorityContacts[_selectedDistressType] ?? [];
    return ListView.builder(
      itemCount: contacts.length,
      itemBuilder: (context, index) {
        final contact = contacts[index];
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.red.shade100)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Text(contact['name']!, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(contact['desc']!),
            trailing: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
              child: const Icon(Icons.phone, color: Colors.green),
            ),
            onTap: () => _launchCaller(contact['number']!),
          ),
        );
      },
    );
  }
}
