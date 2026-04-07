import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:erpms_app/app_shell.dart';
import 'package:erpms_app/utils/location_helper.dart';

const Color _primaryBlue = Color(0xFF004AAD);
const Color _navyTitle = Color(0xFF1D3557);

class MedicalPage extends StatefulWidget {
  const MedicalPage({super.key});

  @override
  State<MedicalPage> createState() => _MedicalPageState();
}

class _MedicalPageState extends State<MedicalPage> {
  String _selectedCategory = "Cardiac";
  final List<String> _selectedTags = [];
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  String? _imageBase64;
  bool _isBroadcasting = false;

  final List<Map<String, dynamic>> _categories = [
    {'name': 'Cardiac', 'icon': Icons.favorite},
    {'name': 'Respiratory', 'icon': Icons.air},
    {'name': 'Trauma', 'icon': Icons.warning},
    {'name': 'Bleeding', 'icon': Icons.bloodtype},
    {'name': 'Animal/Snake', 'icon': Icons.bug_report},
    {'name': 'Seizure', 'icon': Icons.psychology},
    {'name': 'Maternity', 'icon': Icons.child_care},
    {'name': 'Burns', 'icon': Icons.local_fire_department},
    {'name': 'Poisoning', 'icon': Icons.science},
    {'name': 'Stroke', 'icon': Icons.biotech},
    {'name': 'Heatstroke', 'icon': Icons.wb_sunny},
    {'name': 'Allergic', 'icon': Icons.coronavirus},
  ];

  final List<String> _tags = [
    'Unconscious', 'Chest Pain', 'No Pulse', 'Pale Skin',
    'Bleeding Heavily', 'Child Victim', 'Elderly Victim', 'Multiple Victims'
  ];

  Future<void> _makeCall(String number) async {
    final Uri launchUri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera, imageQuality: 50);

    if (image != null) {
      final Uint8List bytes = await image.readAsBytes();
      final compressedBytes = await FlutterImageCompress.compressWithList(
        bytes,
        minHeight: 480,
        minWidth: 640,
        quality: 70,
      );
      setState(() {
        _imageBase64 = base64Encode(compressedBytes);
      });
    }
  }

  Future<void> _broadcastAlert() async {
    setState(() => _isBroadcasting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final pos = await LocationHelper.getCurrentPosition();
      final district = await LocationHelper.getDistrictForPosition(pos) ?? "Unknown";

      String finalDescription = "TAGS: ${_selectedTags.isEmpty ? 'None' : _selectedTags.join(', ')} | NOTE: ${_noteController.text.trim()}";

      await FirebaseFirestore.instance.collection('alerts').add({
        'title': 'MEDICAL: $_selectedCategory',
        'type': 'Medical',
        'description': finalDescription,
        'detailedAddress': _addressController.text.trim(),
        'visibility': 'personal',
        'status': 'active',
        'severity': 'Critical',
        'isOfficial': false,
        'location': GeoPoint(pos.latitude, pos.longitude),
        'district': district,
        'imageBase64': _imageBase64,
        'timestamp': FieldValue.serverTimestamp(),
        'createdBy': user.uid,
        'isSOS': false,
        'engagedBy': null,
        'ai_actions': null,
        'isPublicized': false,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Medical Alert Broadcasted to Volunteers!')),
        );
        _noteController.clear();
        _addressController.clear();
        setState(() {
          _selectedTags.clear();
          _imageBase64 = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isBroadcasting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Medical Help',
      padBody: true,
      isBodyScrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildEmergencyButtons(),
          const SizedBox(height: 24),
          const Text(
            'QUICK MEDICAL ALERT BROADCAST',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold, color: _primaryBlue, fontSize: 16),
          ),
          const SizedBox(height: 16),
          _buildCategoryGrid(),
          const SizedBox(height: 24),
          _buildQuickDetails(),
          const SizedBox(height: 24),
          _buildNoteAndPhotoSection(),
          const SizedBox(height: 32),
          _buildBroadcastButton(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildEmergencyButtons() {
    return Row(
      children: [
        Expanded(
          child: _emergencyCallButton(
            'CALL 108',
            'AMBULANCE',
            Colors.red,
            () => _makeCall('108'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _emergencyCallButton(
            'CALL 112',
            'ALL-IN-ONE',
            _navyTitle,
            () => _makeCall('112'),
          ),
        ),
      ],
    );
  }

  Widget _emergencyCallButton(String title, String subtitle, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: Column(
          children: [
            const Icon(Icons.phone_in_talk, color: Colors.white, size: 28),
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('SELECT EMERGENCY TYPE (TAP ONE)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.85,
          ),
          itemCount: _categories.length,
          itemBuilder: (context, index) {
            final cat = _categories[index];
            final isSelected = _selectedCategory == cat['name'];
            return InkWell(
              onTap: () => setState(() => _selectedCategory = cat['name']),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? Colors.red : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isSelected ? Colors.red : Colors.grey.shade300),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(cat['icon'], color: isSelected ? Colors.white : Colors.black87, size: 24),
                    const SizedBox(height: 4),
                    Text(
                      cat['name'],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildQuickDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('QUICK DETAILS (TAP STATUS TAGS)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _tags.map((tag) {
            final isSelected = _selectedTags.contains(tag);
            return ChoiceChip(
              label: Text(tag, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : Colors.black87)),
              selected: isSelected,
              selectedColor: _navyTitle,
              backgroundColor: Colors.white,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedTags.add(tag);
                  } else {
                    _selectedTags.remove(tag);
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildNoteAndPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('ADD DESCRIPTION / NOTE (FLAT NO., LOCATION)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  TextField(
                    controller: _noteController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Describe Situation...',
                      hintStyle: const TextStyle(fontSize: 12),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _addressController,
                    decoration: InputDecoration(
                      hintText: 'Flat 402, North Gate...',
                      hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            InkWell(
              onTap: _pickImage,
              child: Container(
                height: 90,
                width: 90,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: _imageBase64 != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(base64Decode(_imageBase64!), fit: BoxFit.cover),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.camera_alt, color: Colors.black54),
                          SizedBox(height: 4),
                          Text('CAPTURE PHOTO\n[+ BASE64 IMAGE]', textAlign: TextAlign.center, style: TextStyle(fontSize: 8, color: Colors.black54)),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBroadcastButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.sensors),
        label: _isBroadcasting
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Text('((•)) BROADCAST ALERT TO VOLUNTEERS', style: TextStyle(fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: _isBroadcasting ? null : _broadcastAlert,
      ),
    );
  }
}
