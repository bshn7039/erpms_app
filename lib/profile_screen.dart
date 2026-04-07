import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:erpms_app/app_shell.dart';
import 'package:erpms_app/edit_profile_screen.dart';
import 'package:erpms_app/admin_hub_page.dart';

const Color _primaryBlue = Color(0xFF004AAD);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isVerifying = false;

  Future<void> _verifyPhoneNumber() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final phoneController = TextEditingController();
    
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connect Mobile Number'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('A verification code (OTP) will be sent via SMS to your mobile.'),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Mobile Number',
                prefixText: '+91 ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (RegExp(r'^\d{10}$').hasMatch(phoneController.text)) {
                Navigator.pop(context, true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid 10-digit number')));
              }
            },
            child: const Text('Send OTP'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final phoneNumber = '+91${phoneController.text.trim()}';
    setState(() => _isVerifying = true);

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _linkPhone(credential, phoneController.text.trim());
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() => _isVerifying = false);
          if (e.code == 'provider-already-linked') {
             _markPhoneAsVerifiedInFirestore(phoneController.text.trim());
          } else if (e.message != null && e.message!.contains('billing')) {
            _showBillingErrorDialog();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Verification Failed: ${e.message}')));
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() => _isVerifying = false);
          _showOtpDialog(verificationId, phoneController.text.trim());
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      setState(() => _isVerifying = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showBillingErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [Icon(Icons.warning, color: Colors.orange), SizedBox(width: 8), Text('Billing Error')],
        ),
        content: const Text(
          'Firebase Phone Auth requires a Blaze plan for real SMS.\n\n'
          'Workaround: Add a "Test Phone Number" in your Firebase Console (Auth > Settings) to test this feature for free.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  void _showOtpDialog(String verificationId, String rawPhone) {
    final otpController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Enter OTP Code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Sent to +91 $rawPhone'),
            const SizedBox(height: 16),
            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(letterSpacing: 8, fontSize: 20, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                hintText: '000000',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (otpController.text.length != 6) return;
              
              final credential = PhoneAuthProvider.credential(
                verificationId: verificationId,
                smsCode: otpController.text.trim(),
              );
              Navigator.pop(context); 
              setState(() => _isVerifying = true);
              await _linkPhone(credential, rawPhone);
            },
            child: const Text('Verify & Connect'),
          ),
        ],
      ),
    );
  }

  Future<void> _linkPhone(PhoneAuthCredential credential, String rawPhone) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          await user.linkWithCredential(credential);
        } catch (e) {
          if (e is FirebaseAuthException && e.code == 'provider-already-linked') {
            // Already linked, just proceed to update Firestore
          } else {
            rethrow;
          }
        }
        
        await _markPhoneAsVerifiedInFirestore(rawPhone);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Verification Error: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _markPhoneAsVerifiedInFirestore(String rawPhone) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'phone': rawPhone,
        'phone_verified': true,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phone connected successfully!')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const AppShell(body: Center(child: Text('Please log in.')));
    }

    return AppShell(
      currentIndex: 4,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('User data not found.'));
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>;
          return _buildProfileContent(context, userData);
        },
      ),
    );
  }

  Widget _buildProfileContent(BuildContext context, Map<String, dynamic> userData) {
    final fullName = userData['full_name'] ?? 'Not Set';
    final email = userData['email'] ?? FirebaseAuth.instance.currentUser?.email ?? 'Not Set';
    final phone = userData['phone'] as String?;
    final isVerified = userData['phone_verified'] as bool? ?? false;
    final bloodGroup = userData['blood_group'] ?? 'Not Set';
    final allergies = userData['allergies'] ?? 'Not Set';
    final emergencyContactPhone = userData['emergency_contact_phone'] ?? 'Not Set';
    final volunteerStatus = userData['volunteer_status'] ?? 'Not Applied';
    final role = userData['role'] ?? 'user';
    final profileData = userData['profile_data'] as String?;
    final shareLocationSos = userData['share_location_sos'] as bool? ?? true;

    bool isVerifiedVolunteer = volunteerStatus == 'Verified' || volunteerStatus == 'approved';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Column(
              children: [
                Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: _primaryBlue.withOpacity(0.1), width: 3),
                      ),
                      child: CircleAvatar(
                        radius: 55,
                        backgroundColor: Colors.grey.shade200,
                        backgroundImage: profileData != null 
                            ? MemoryImage(base64Decode(profileData)) 
                            : const AssetImage('assets/images/profile.png') as ImageProvider,
                      ),
                    ),
                    if (isVerifiedVolunteer)
                      Positioned(
                        bottom: 0, 
                        right: 0, 
                        child: Container(
                          padding: const EdgeInsets.all(4), 
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), 
                          child: const Icon(Icons.verified, color: Colors.blue, size: 24)
                        ),
                      ),
                    Positioned(
                      bottom: 5,
                      right: isVerifiedVolunteer ? 28 : 5,
                      child: GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const EditProfileScreen())),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: _primaryBlue,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(fullName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Text(email, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                
                const SizedBox(height: 12),
                if (isVerified)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.green.shade200)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.phone_android, size: 16, color: Colors.green),
                        const SizedBox(width: 8),
                        Text(phone ?? '', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(width: 4),
                        const Icon(Icons.check_circle, size: 14, color: Colors.green),
                      ],
                    ),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: _isVerifying ? null : _verifyPhoneNumber,
                    icon: _isVerifying ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.phonelink_setup),
                    label: const Text('Connect & Verify Phone'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (role == 'admin') _buildAdminTile(context),
          _buildInfoCard('Safety & Privacy', [
            _buildInfoRow(Icons.emergency_share, 'Emergency Contact', emergencyContactPhone),
            _buildInfoRow(Icons.location_on, 'Live SOS Tracking', shareLocationSos ? 'Enabled' : 'Disabled'),
          ], color: Colors.red.withOpacity(0.05)),
          _buildInfoCard('Personal Medical ID', [
            _buildInfoRow(Icons.bloodtype, 'Blood Group', bloodGroup),
            _buildInfoRow(Icons.warning_amber_outlined, 'Allergies', allergies),
          ]),
          _buildInfoCard('Volunteer Status', [
            _buildInfoRow(Icons.volunteer_activism, 'Status', isVerifiedVolunteer ? 'Verified' : volunteerStatus),
          ]),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const EditProfileScreen())),
            style: ElevatedButton.styleFrom(backgroundColor: _primaryBlue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Edit Personal Info'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
            },
            child: const Text('Sign Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminTile(BuildContext context) {
    return Card(
      color: Colors.indigo.shade50,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.indigo.shade200)),
      child: ListTile(
        leading: const Icon(Icons.admin_panel_settings, color: Colors.indigo),
        title: const Text('Admin Operations Hub', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
        subtitle: const Text('Access restricted command center'),
        trailing: const Icon(Icons.chevron_right, color: Colors.indigo),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminHubPage())),
      ),
    );
  }

  Widget _buildInfoCard(String title, List<Widget> children, {Color? color}) {
    return Card(
      elevation: 0,
      color: color ?? Colors.grey.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _primaryBlue)),
          const SizedBox(height: 12),
          ...children,
        ]),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(children: [
        Icon(icon, color: _primaryBlue.withOpacity(0.7), size: 18),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        const Spacer(),
        Text(value, style: const TextStyle(color: Colors.black54, fontSize: 14)),
      ]),
    );
  }
}
