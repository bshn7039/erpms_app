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
  
  // Hardcoded list must include exactly what we use as a default or from DB
  final List<String> _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-', 'Not Set'];
  
  String _bloodGroup = 'Not Set'; // Default to one of the items in the list
  String? _profileData;
  bool _isLoading = false;
  bool _isDataLoaded = false;
  bool _shareLocationDuringSOS = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        _fullNameController.text = data['full_name'] ?? '';
        _allergiesController.text = data['allergies'] ?? '';
        _emergencyContactPhoneController.text = data['emergency_contact_phone'] ?? '';
        
        setState(() {
          String? bg = data['blood_group'];
          // Ensure the value from DB exists in our list to avoid the red screen error
          if (bg != null && _bloodGroups.contains(bg)) {
            _bloodGroup = bg;
          } else {
            _bloodGroup = 'Not Set';
          }
          
          _profileData = data['profile_data'];
          _shareLocationDuringSOS = data['share_location_sos'] ?? true;
          _isDataLoaded = true;
        });
      } else {
        setState(() => _isDataLoaded = true);
      }
    } catch (e) {
      debugPrint("Error loading profile: $e");
      setState(() => _isDataLoaded = true);
    }
  }

  Future<void> _pickAndCompressImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      try {
        final result = await FlutterImageCompress.compressWithFile(
          pickedFile.path,
          minWidth: 250,
          minHeight: 250,
          quality: 80,
        );
        if (result != null) {
          setState(() {
            _profileData = base64Encode(result);
          });
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error processing image: $e')));
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
            'full_name': _fullNameController.text.trim(),
            'allergies': _allergiesController.text.trim(),
            'emergency_contact_phone': _emergencyContactPhoneController.text.trim(),
            'blood_group': _bloodGroup,
            'profile_data': _profileData,
            'share_location_sos': _shareLocationDuringSOS,
          };

          await FirebaseFirestore.instance.collection('users').doc(user.uid).set(userData, SetOptions(merge: true));

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile Updated Successfully')));
            Navigator.pop(context);
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isDataLoaded) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Profile'), backgroundColor: _primaryBlue, foregroundColor: Colors.white),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: _primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: _primaryBlue.withOpacity(0.2), width: 4),
                          ),
                          child: CircleAvatar(
                            radius: 60,
                            backgroundColor: Colors.grey.shade200,
                            backgroundImage: _profileData != null 
                                ? MemoryImage(base64Decode(_profileData!)) 
                                : const AssetImage('assets/images/profile.png') as ImageProvider,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 4,
                          child: GestureDetector(
                            onTap: _pickAndCompressImage,
                            child: Container(
                              height: 36,
                              width: 36,
                              decoration: const BoxDecoration(
                                color: _primaryBlue,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text('Personal Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryBlue)),
                  const Divider(),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _fullNameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (value) => (value == null || value.isEmpty) ? 'Please enter your full name' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _bloodGroup,
                    decoration: const InputDecoration(
                      labelText: 'Blood Group',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.bloodtype_outlined),
                    ),
                    items: _bloodGroups.map((String group) {
                      return DropdownMenuItem<String>(
                        value: group,
                        child: Text(group),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      if (newValue != null) {
                        setState(() => _bloodGroup = newValue);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _allergiesController,
                    decoration: const InputDecoration(
                      labelText: 'Allergies',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.warning_amber_outlined),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 24),
                  const Text('Safety & Privacy', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                  const Divider(),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emergencyContactPhoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Emergency Contact Phone',
                      hintText: '10-digit mobile number',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.emergency_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Emergency contact is required';
                      if (!RegExp(r'^\d{10}$').hasMatch(value)) return 'Enter a valid 10-digit number';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Share Live Location during SOS'),
                    subtitle: const Text('Your location is only shared with responders during active emergencies.'),
                    value: _shareLocationDuringSOS,
                    onChanged: (val) => setState(() => _shareLocationDuringSOS = val),
                    activeColor: Colors.redAccent,
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Save Profile Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
