import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:erpms_app/app_shell.dart';
import 'package:erpms_app/utils/location_helper.dart';

const Color _primaryBlue = Color(0xFF004AAD);
const Color _navyTitle = Color(0xFF1D3557);
const Color _textDark = Color(0xFF4D4C4C);

class JoinUsPage extends StatefulWidget {
  const JoinUsPage({super.key});

  @override
  State<JoinUsPage> createState() => _JoinUsPageState();
}

class _JoinUsPageState extends State<JoinUsPage> {
  int _currentStep = 0;
  bool _isLoading = true;
  String? _userRole;
  String? _volunteerStatus;

  // Form State
  final _formKey1 = GlobalKey<FormState>();
  final _formKey2 = GlobalKey<FormState>();
  
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  final _ageController = TextEditingController(text: '18');
  final _skillsController = TextEditingController();
  
  String? _bloodGroup;
  String? _selectedGenre;
  String? _idProof64;
  String? _skillProof64;

  final List<String> _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];
  final List<String> _genres = ['General', 'Medical', 'Physical', 'Flood', 'Fire', 'Rescue', 'Logistics', 'Tech'];

  @override
  void initState() {
    super.initState();
    _fetchUserStatus();
    _detectCity();
  }

  Future<void> _detectCity() async {
    try {
      final pos = await LocationHelper.getCurrentPosition();
      final city = await LocationHelper.getDistrictForPosition(pos);
      if (city != null && mounted) {
        setState(() {
          _cityController.text = city;
        });
      }
    } catch (e) {
      debugPrint("City detection failed: $e");
    }
  }

  Future<void> _fetchUserStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = doc.data();
      if (mounted) {
        setState(() {
          _userRole = data?['role'] ?? 'user';
          _volunteerStatus = data?['volunteer_status'] ?? 'Not Applied';
          _nameController.text = data?['full_name'] ?? '';
          _phoneController.text = data?['phone'] ?? '';
          _bloodGroup = data?['blood_group'];
          _isLoading = false;
        });
      }
    }
  }

  Future<String?> _pickAndCompress() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (pickedFile != null) {
      final result = await FlutterImageCompress.compressWithFile(
        pickedFile.path,
        minWidth: 600,
        minHeight: 600,
        quality: 60,
      );
      if (result != null) return base64Encode(result);
    }
    return null;
  }

  Future<void> _submitApplication() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final appData = {
        'uid': user.uid,
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'city': _cityController.text.trim(),
        'age': int.tryParse(_ageController.text) ?? 0,
        'blood_group': _bloodGroup,
        'genre': _selectedGenre,
        'skills': _skillsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
        'id_64': _idProof64,
        'skill_64': _skillProof64,
        'status': 'pending',
        'applied_at': FieldValue.serverTimestamp(),
      };

      final batch = FirebaseFirestore.instance.batch();
      batch.set(FirebaseFirestore.instance.collection('volunteers').doc(user.uid), appData);
      batch.update(FirebaseFirestore.instance.collection('users').doc(user.uid), {
        'volunteer_status': 'pending',
        'volunteer_genre': _selectedGenre,
      });

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Application Submitted Successfully!')));
        _fetchUserStatus();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const AppShell(body: Center(child: CircularProgressIndicator()));

    if (_userRole == 'admin') {
      return _buildStatusView('Administrators cannot apply as volunteers.', Icons.admin_panel_settings);
    }
    if (_volunteerStatus == 'pending') {
      return _buildStatusView('Your application is under review.\nPlease wait for admin approval.', Icons.hourglass_empty, color: Colors.orange);
    }
    if (_volunteerStatus == 'Verified' || _userRole == 'volunteer') {
      return _buildStatusView('You are a verified ERPMS Volunteer!\nCheck your dashboard for active alerts.', Icons.verified, color: Colors.green);
    }

    return AppShell(
      title: 'Volunteer Application',
      isBodyScrollable: true,
      padBody: false,
      body: Column(
        children: [
          _buildHeader(),
          Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(primary: _primaryBlue),
            ),
            child: Stepper(
              physics: const NeverScrollableScrollPhysics(),
              currentStep: _currentStep,
              onStepContinue: () {
                if (_currentStep == 0) {
                  if (_formKey1.currentState!.validate() && _idProof64 != null) {
                    setState(() => _currentStep++);
                  } else if (_idProof64 == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please upload ID Proof')));
                  }
                } else if (_currentStep == 1) {
                  if (_formKey2.currentState!.validate() && _selectedGenre != null && _skillProof64 != null) {
                    setState(() => _currentStep++);
                  } else if (_selectedGenre == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a Genre')));
                  } else if (_skillProof64 == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please upload Skill Proof')));
                  }
                }
              },
              onStepCancel: _currentStep > 0 ? () => setState(() => _currentStep--) : null,
              controlsBuilder: (context, details) {
                return Padding(
                  padding: const EdgeInsets.only(top: 20, bottom: 20),
                  child: Row(
                    children: [
                      if (_currentStep < 2)
                        Expanded(
                          child: ElevatedButton(
                            onPressed: details.onStepContinue,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryBlue, 
                              foregroundColor: Colors.white, 
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('NEXT STEP'),
                          ),
                        ),
                      if (_currentStep == 2)
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _submitApplication,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red, 
                              foregroundColor: Colors.white, 
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('SUBMIT APPLICATION ✅'),
                          ),
                        ),
                      if (_currentStep > 0) ...[
                        const SizedBox(width: 12),
                        OutlinedButton(
                          onPressed: details.onStepCancel,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('BACK'),
                        ),
                      ]
                    ],
                  ),
                );
              },
              steps: [
                _stepIdentity(),
                _stepSkills(),
                _stepReview(),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: Column(
        children: const [
          Text(
            '“Service to others is the rent you pay for your room here on earth.”',
            textAlign: TextAlign.center,
            style: TextStyle(fontStyle: FontStyle.italic, color: _textDark, fontSize: 13),
          ),
          SizedBox(height: 10),
          Text(
            'VOLUNTEER APPLICATION',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: _primaryBlue, letterSpacing: 1.2),
          ),
        ],
      ),
    );
  }

  Step _stepIdentity() {
    return Step(
      isActive: _currentStep >= 0,
      state: _currentStep > 0 ? StepState.complete : StepState.indexed,
      title: const Text('Step 1: Identity & Basics'),
      content: Form(
        key: _formKey1,
        child: Column(
          children: [
            TextFormField(
              controller: _nameController,
              decoration: _inputDeco('Full Name', Icons.person),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _phoneController,
                    decoration: _inputDeco('Phone', Icons.phone),
                    keyboardType: TextInputType.phone,
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _ageController,
                    decoration: _inputDeco('Age', Icons.calendar_today),
                    keyboardType: TextInputType.number,
                    validator: (v) => v!.isEmpty ? 'Req' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _cityController,
              readOnly: true,
              decoration: _inputDeco('City', Icons.location_city, hintText: 'Detecting city...'),
              validator: (v) => v!.isEmpty ? 'City detection required' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _bloodGroup,
              decoration: _inputDeco('Blood Group', Icons.bloodtype),
              items: _bloodGroups.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
              onChanged: (v) => setState(() => _bloodGroup = v),
              validator: (v) => v == null ? 'Required' : null,
            ),
            const SizedBox(height: 20),
            _uploadBox('Capture/Upload ID Proof (Aadhaar/License)', _idProof64 != null, () async {
              final res = await _pickAndCompress();
              if (res != null) setState(() => _idProof64 = res);
            }),
          ],
        ),
      ),
    );
  }

  Step _stepSkills() {
    return Step(
      isActive: _currentStep >= 1,
      state: _currentStep > 1 ? StepState.complete : StepState.indexed,
      title: const Text('Step 2: Skills & Certification'),
      content: Form(
        key: _formKey2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Selection: Choose a Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _navyTitle)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedGenre,
              decoration: _inputDeco('Volunteer Genre', Icons.category),
              items: _genres.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
              onChanged: (v) => setState(() => _selectedGenre = v),
              validator: (v) => v == null ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _skillsController,
              decoration: _inputDeco('Skills (e.g. Nursing, First Aid)', Icons.bolt, hintText: 'Comma separated values'),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 20),
            _uploadBox('Verification: Capture Certification Proof', _skillProof64 != null, () async {
              final res = await _pickAndCompress();
              if (res != null) setState(() => _skillProof64 = res);
            }),
          ],
        ),
      ),
    );
  }

  Step _stepReview() {
    return Step(
      isActive: _currentStep >= 2,
      title: const Text('Step 3: Review Your Information'),
      content: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _reviewRow('NAME', _nameController.text),
            _reviewRow('PHONE', _phoneController.text),
            _reviewRow('CITY', _cityController.text),
            _reviewRow('BLOOD GROUP', _bloodGroup ?? 'N/A'),
            _reviewRow('GENRE', _selectedGenre ?? 'N/A'),
            _reviewRow('SKILLS', _skillsController.text),
            const Divider(),
            const Text('IDENTIFICATION & SKILLS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _navyTitle)),
            const SizedBox(height: 12),
            Row(
              children: [
                _miniPreview('ID Proof', _idProof64),
                const SizedBox(width: 12),
                _miniPreview('Skill Proof', _skillProof64),
              ],
            ),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                'Application Status: Pending Review',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange, letterSpacing: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniPreview(String label, String? b64) {
    return Expanded(
      child: Column(
        children: [
          Container(
            height: 80,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: b64 != null 
              ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(base64Decode(b64), fit: BoxFit.cover))
              : const Icon(Icons.image, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _reviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _navyTitle)),
        ],
      ),
    );
  }

  Widget _uploadBox(String label, bool isDone, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: isDone ? Colors.green.shade50 : Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDone ? Colors.green : _primaryBlue.withOpacity(0.3), width: 1.5),
          boxShadow: [
            if (!isDone) BoxShadow(color: _primaryBlue.withOpacity(0.1), blurRadius: 4)
          ],
        ),
        child: Row(
          children: [
            Icon(isDone ? Icons.verified_rounded : Icons.camera_alt_rounded, color: isDone ? Colors.green : _primaryBlue),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDone ? Colors.green.shade700 : _primaryBlue))),
            if (isDone) const Icon(Icons.check_circle, color: Colors.green),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String label, IconData icon, {String? hintText}) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      prefixIcon: Icon(icon, color: _primaryBlue, size: 20),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _buildStatusView(String message, IconData icon, {Color color = _primaryBlue}) {
    return AppShell(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, size: 80, color: color),
              ),
              const SizedBox(height: 32),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _navyTitle.withOpacity(0.8), height: 1.4),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color, 
                    foregroundColor: Colors.white, 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('BACK TO HOME', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
