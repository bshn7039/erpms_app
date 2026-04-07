import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:erpms_app/app_shell.dart';
import 'package:erpms_app/utils/location_helper.dart';
import 'package:erpms_app/models/alert_model.dart';

const Color _primaryBlue = Color(0xFF004AAD);
const Color _navyTitle = Color(0xFF1D3557);
const Color _textDark = Color(0xFF4D4C4C);

class CreateAlertPage extends StatefulWidget {
  final bool isAdminOrVolunteer;
  const CreateAlertPage({super.key, this.isAdminOrVolunteer = false});

  @override
  State<CreateAlertPage> createState() => _CreateAlertPageState();
}

class _CreateAlertPageState extends State<CreateAlertPage> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  String _selectedSeverity = 'Info';
  String _selectedType = 'General';
  String _visibility = 'personal';
  String _city = 'Detecting...';
  GeoPoint? _currentLocation;
  bool _isLoading = false;

  final List<String> _severities = ['Info', 'Warning', 'Critical'];
  final List<String> _types = ['General', 'Medical', 'Physical', 'Rescue', 'Logistics', 'Tech', 'Fire', 'Flood'];

  @override
  void initState() {
    super.initState();
    _fetchLocation();
    if (widget.isAdminOrVolunteer) {
      _visibility = 'public';
    }
  }

  Future<void> _fetchLocation() async {
    try {
      final pos = await LocationHelper.getCurrentPosition();
      final district = await LocationHelper.getDistrictForPosition(pos);
      if (mounted) {
        setState(() {
          _city = district ?? 'Unknown City';
          _currentLocation = GeoPoint(pos.latitude, pos.longitude);
        });
      }
    } catch (e) {
      if (mounted) setState(() => _city = 'Error detecting location');
    }
  }

  Future<void> _submitAlert() async {
    if (_titleController.text.isEmpty || _currentLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a title and ensure location is detected')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userData = userDoc.data();
      final userName = userData?['full_name'] ?? 'Unknown User';
      final userPhone = userData?['phone'] ?? '';

      final alertRef = FirebaseFirestore.instance.collection('alerts').doc();
      final alertId = alertRef.id;

      final alertMap = {
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'district': _city,
        'location': _currentLocation!,
        'isOfficial': widget.isAdminOrVolunteer,
        'severity': _selectedSeverity,
        'status': 'active',
        'visibility': _visibility,
        'type': _selectedType,
        'createdBy': user.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'isSOS': false,
      };

      // 1. Create the Alert
      await alertRef.set(alertMap);

      // 2. Create corresponding Incident for Assistant Hub tracking
      await FirebaseFirestore.instance.collection('incidents').doc(alertId).set({
        'userId': user.uid,
        'userName': userName,
        'userPhone': userPhone,
        'status': 'active',
        'type': _selectedType,
        'timestamp': FieldValue.serverTimestamp(),
        'location': _currentLocation!,
        'district': _city,
        'visibility': _visibility,
        'isPublicized': _visibility == 'public',
        'isSOS': false,
        'description': _descController.text.trim(),
      });

      // 3. System message
      await FirebaseFirestore.instance.collection('incidents').doc(alertId).collection('messages').add({
        'senderId': 'system',
        'text': 'Alert created. Responders will see this in their feeds.',
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${_visibility.toUpperCase()} Alert Created Successfully')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Create Alert',
      showAuxiliaryButtons: false,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLocationBanner(),
              const SizedBox(height: 24),
              _buildTextField('Alert Title', _titleController, Icons.title),
              const SizedBox(height: 16),
              _buildTextField('Description (Optional)', _descController, Icons.description, maxLines: 3),
              const SizedBox(height: 16),
              _buildDropdown('Emergency Type', _selectedType, _types, (val) => setState(() => _selectedType = val!)),
              const SizedBox(height: 16),
              _buildDropdown('Severity Level', _selectedSeverity, _severities, (val) => setState(() => _selectedSeverity = val!)),
              const SizedBox(height: 24),
              if (widget.isAdminOrVolunteer)
                _buildVisibilityToggle(),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitAlert,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Broadcast Alert', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.shade100)),
      child: Row(
        children: [
          const Icon(Icons.location_on, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Detected City', style: TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold)),
                Text(_city, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _navyTitle)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisibilityToggle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Target Audience', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _primaryBlue)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: const Center(child: Text('Public (Everyone)')),
                selected: _visibility == 'public',
                onSelected: (val) => setState(() => _visibility = 'public'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ChoiceChip(
                label: const Center(child: Text('Personal (Responders)')),
                selected: _visibility == 'personal',
                onSelected: (val) => setState(() => _visibility = 'personal'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _primaryBlue)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: _primaryBlue, size: 20),
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            hintText: 'Enter $label',
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _primaryBlue)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              items: items.map((String item) => DropdownMenuItem<String>(value: item, child: Text(item))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
