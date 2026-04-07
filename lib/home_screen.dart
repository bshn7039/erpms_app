import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:erpms_app/app_shell.dart';
import 'package:erpms_app/medical_page.dart';
import 'package:erpms_app/fire_safety_page.dart';
import 'package:erpms_app/reports_page.dart';
import 'package:erpms_app/community_page.dart';
import 'package:erpms_app/emergency_guide_page.dart';
import 'package:erpms_app/join_us_page.dart';
import 'package:erpms_app/models/alert_model.dart';
import 'package:erpms_app/alert_detail_page.dart';
import 'package:erpms_app/edit_profile_screen.dart';

const Color _primaryBlue = Color(0xFF004AAD);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isAccountConnected = false;
  bool _isLoadingCheck = true;

  @override
  void initState() {
    super.initState();
    _checkAccountConnection();
  }

  Future<void> _checkAccountConnection() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (mounted) {
        setState(() {
          _isAccountConnected = doc.data()?['phone'] != null && (doc.data()?['phone'] as String).isNotEmpty;
          _isLoadingCheck = false;
        });
      }
    }
  }

  Widget _assetImage(String path, {double? width, double? height, BoxFit fit = BoxFit.contain}) {
    return Image.asset(
      path,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, __, ___) => Icon(Icons.image_not_supported_outlined, color: _primaryBlue, size: width ?? 32),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingCheck) {
      return const AppShell(body: Center(child: CircularProgressIndicator()));
    }

    return AppShell(
      currentIndex: 0,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_isAccountConnected) _buildAccountWarning(),
          
          // Latest Alerts Ticker (Public Only)
          _buildAlertsList(),
          const SizedBox(height: 16),
          // Map preview
          GestureDetector(
            onTap: () {
              if (!_checkAccess()) return;
              Navigator.pushNamed(context, '/map');
            },
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F0FE),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _primaryBlue.withOpacity(0.5), width: 1),
                image: const DecorationImage(
                  image: AssetImage('assets/images/mappreview.png'),
                  fit: BoxFit.cover,
                  opacity: 0.6,
                ),
              ),
              child: const Center(
                child: Text(
                  'Open Live Map',
                  style: TextStyle(color: _primaryBlue, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Feature grid reordered as requested
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.85,
            children: [
              _gridItem('assets/images/guidelogo.png', 'Emergency Aid Guide', () => Navigator.push(context, MaterialPageRoute(builder: (context) => const EmergencyGuidePage()))),
              _gridItem('assets/images/joinus.png', 'Join Us', () => _protectedNav(const JoinUsPage())),
              _gridItem('assets/images/reports.png', 'Reports', () => _protectedNav(const ReportsPage())),
              _gridItem('assets/images/communitybox.png', 'Community', () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CommunityPage()))),
              _gridItem('assets/images/medical.png', 'Medical Help', () => _protectedNav(const MedicalPage())),
              _gridItem('assets/images/firealarm.png', 'Fire Safety', () => _protectedNav(const FireSafetyPage())),
            ],
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildAccountWarning() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amber.shade200)),
      child: Column(
        children: [
          Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Expanded(child: Text('Mobile number not connected! Safety features are disabled.', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange))),
            ],
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const EditProfileScreen())),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            child: const Text('Connect Now'),
          ),
        ],
      ),
    );
  }

  bool _checkAccess() {
    if (!_isAccountConnected) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please connect your mobile number in Profile to access this feature.')));
      return false;
    }
    return true;
  }

  void _protectedNav(Widget page) {
    if (_checkAccess()) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => page));
    }
  }

  Widget _buildAlertsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('alerts')
          .where('visibility', isEqualTo: 'public')
          .orderBy('timestamp', descending: true)
          .limit(3)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final alerts = snapshot.data!.docs.map((doc) => AlertModel.fromDoc(doc)).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'LATEST PUBLIC UPDATES',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF1D3557),
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.campaign, color: Colors.red.shade600, size: 20),
              ],
            ),
            const SizedBox(height: 10),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: alerts.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final alert = alerts[index];
                return GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AlertDetailPage(alert: alert))),
                  child: _alertPill('${alert.severity.toUpperCase()}: ${alert.title}'),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _gridItem(String imagePath, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: _primaryBlue.withOpacity(0.1), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 70,
              height: 70,
              child: _assetImage(imagePath, fit: BoxFit.contain),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1D3557),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _alertPill(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: Colors.red, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.red, size: 18),
        ],
      ),
    );
  }
}
