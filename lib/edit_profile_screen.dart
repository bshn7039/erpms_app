import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

const Color _primaryBlue = Color(0xFF004AAD);

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _emergencyContactPhoneController = TextEditingController();
  String? _bloodGroup;
  String? _profileData;
  bool _isLoading = false;
  bool _shareLocationDuringSOS = true;

  final List<String> _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = doc.data();
      if (data != null) {
        _fullNameController.text = data['full_name'] ?? '';
        _allergiesController.text = data['allergies'] ?? '';
        _emergencyContactPhoneController.text = data['emergency_contact_phone'] ?? '';
        setState(() {
          _bloodGroup = data['blood_group'];
          _profileData = data['profile_data'];
          _shareLocationDuringSOS = data['share_location_sos'] ?? true;
        });
      }
    }
  }

  Future<void> _pickAndCompressImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final result = await FlutterImageCompress.compressWithFile(
        pickedFile.path,
        minWidth: 200,
        minHeight: 200,
        quality: 70,
      );
      if (result != null) {
        setState(() {
          _profileData = base64Encode(result);
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final userData = {
            'full_name': _fullNameController.text,
            'allergies': _allergiesController.text,
            'emergency_contact_phone': _emergencyContactPhoneController.text,
            'blood_group': _bloodGroup,
            'profile_data': _profileData,
            'share_location_sos': _shareLocationDuringSOS,
          };

          await FirebaseFirestore.instance.collection('users').doc(user.uid).set(userData, SetOptions(merge: true));

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile Saved Successfully')));
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save profile: $e')));
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
          Navigator.pop(context);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: _primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: _pickAndCompressImage,
                      child: CircleAvatar(
                        radius: 50,
                        backgroundImage: _profileData != null ? MemoryImage(base64Decode(_profileData!)) : const AssetImage('assets/images/profile.png') as ImageProvider,
                        child: const Icon(Icons.camera_alt, color: Colors.white70),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Personal Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryBlue)),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _fullNameController,
                    decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder()),
                    validator: (value) => value!.isEmpty ? 'Please enter your full name' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _bloodGroup,
                    decoration: const InputDecoration(labelText: 'Blood Group', border: OutlineInputBorder()),
                    items: _bloodGroups.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (newValue) => setState(() => _bloodGroup = newValue),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _allergiesController,
                    decoration: const InputDecoration(labelText: 'Allergies', border: OutlineInputBorder()),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 24),
                  const Text('Safety & Privacy', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emergencyContactPhoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Emergency Contact Phone (10 digits)',
                      hintText: 'Required for SOS alerts',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.emergency),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Emergency contact is required';
                      if (!RegExp(r'^\d{10}$').hasMatch(value)) return 'Enter a valid 10-digit number';
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('Share Live Location during SOS'),
                    subtitle: const Text('Your location is ONLY shared when SOS is active or an incident is engaged.', style: TextStyle(fontSize: 12)),
                    value: _shareLocationDuringSOS,
                    onChanged: (val) => setState(() => _shareLocationDuringSOS = val),
                    activeColor: Colors.redAccent,
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Save Profile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
