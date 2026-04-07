import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:erpms_app/utils/location_helper.dart';

// Design colors
const Color _navyBlue = Color(0xFF004AAD);
const Color _greyLabel = Color(0xFF8F8E8E);
const Color _textDark = Color(0xFF4D4C4C);

InputDecoration _inputDecoration({required String hintText}) {
  return InputDecoration(
    filled: true,
    fillColor: _greyLabel.withOpacity(0.15),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
    hintText: hintText,
    hintStyle: TextStyle(color: _textDark.withOpacity(0.6)),
  );
}

Widget _label(String text) {
  return Align(
    alignment: Alignment.centerLeft,
    child: Text(
      text,
      style: const TextStyle(color: _navyBlue, fontSize: 12, fontWeight: FontWeight.bold),
    ),
  );
}

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleRegister() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }
    if (password != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
      return;
    }

    setState(() => _isLoading = true);

    User? user;
    try {
      // 1. Create Auth User
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      user = cred.user;
    } catch (e) {
      // Handle the Pigeon version mismatch error or other cast errors
      // Often the user is actually created even if this throws a type error
      debugPrint("Auth Creation Error/Warning: $e");
      user = FirebaseAuth.instance.currentUser;
      
      if (user == null) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Auth Error: $e')));
        }
        return;
      }
    }

    // 2. Create Firestore Data (Now that we definitely have a user)
    if (user != null) {
      try {
        GeoPoint initialLocation = const GeoPoint(18.999901, 73.1214965);
        try {
          final pos = await LocationHelper.getCurrentPosition().timeout(const Duration(seconds: 5));
          initialLocation = GeoPoint(pos.latitude, pos.longitude);
        } catch (_) {}

        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'full_name': name,
          'email': email,
          'phone': '',
          'phone_verified': false,
          'blood_group': 'Not Set',
          'allergies': 'None',
          'emergency_contact_phone': '',
          'current_location': initialLocation,
          'profile_data': null,
          'role': 'user',
          'share_location_sos': true,
          'volunteer_genre': '',
          'volunteer_status': 'Not Applied',
        }, SetOptions(merge: true));

        await user.sendEmailVerification();
        
        if (mounted) {
          setState(() => _isLoading = false);
          Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Firestore Error: $e')));
          // Even if Firestore fails, we might want to redirect if the user exists
          Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Image.asset(
            'assets/images/signupbg.png',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.white),
          ),
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 35),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 320),
                  _label('NAME'),
                  const SizedBox(height: 8),
                  TextField(controller: _nameController, decoration: _inputDecoration(hintText: 'Enter your name')),
                  const SizedBox(height: 20),
                  _label('EMAIL'),
                  const SizedBox(height: 8),
                  TextField(controller: _emailController, decoration: _inputDecoration(hintText: 'Enter your email')),
                  const SizedBox(height: 20),
                  _label('PASSWORD'),
                  const SizedBox(height: 8),
                  TextField(controller: _passwordController, obscureText: true, decoration: _inputDecoration(hintText: 'Enter password')),
                  const SizedBox(height: 20),
                  _label('CONFIRM PASSWORD'),
                  const SizedBox(height: 8),
                  TextField(controller: _confirmPasswordController, obscureText: true, decoration: _inputDecoration(hintText: 'Confirm password')),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleRegister,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _navyBlue,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading 
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Create Account', style: TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false),
                      child: const Text('Already have an Account ? Sign In!', style: TextStyle(color: _greyLabel)),
                    ),
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
