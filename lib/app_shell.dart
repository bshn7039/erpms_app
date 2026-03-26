import 'package:erpms_app/chat_list_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:erpms_app/alerts_page.dart';
import 'package:erpms_app/community_page.dart';
import 'package:erpms_app/home_screen.dart';
import 'package:erpms_app/map_screen.dart';
import 'package:erpms_app/profile_screen.dart';
import 'package:erpms_app/sos_page.dart';
import 'package:erpms_app/assistant_hub_page.dart';

const Color _primaryBlue = Color(0xFF004AAD);

class AppShell extends StatefulWidget {
  final Widget body;
  final bool isBodyScrollable;
  final bool showFloatingButtons;
  final bool showAuxiliaryButtons;
  final bool padBody;
  final int? currentIndex;
  final String? title;

  const AppShell({
    super.key,
    required this.body,
    this.isBodyScrollable = true,
    this.showFloatingButtons = true,
    this.showAuxiliaryButtons = true,
    this.padBody = true,
    this.currentIndex,
    this.title,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.currentIndex ?? 0;
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

  void _onItemTapped(int index) {
    if (index == _selectedIndex && widget.currentIndex != null) return;

    Widget nextStep;
    switch (index) {
      case 0:
        nextStep = const HomeScreen();
        break;
      case 1:
        nextStep = const CommunityPage();
        break;
      case 2:
        nextStep = const MapScreen();
        break;
      case 3:
        nextStep = const AlertsPage();
        break;
      case 4:
        nextStep = const ProfileScreen();
        break;
      default:
        nextStep = const HomeScreen();
    }
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => nextStep));
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? 'Not signed in';

    return Scaffold(
      resizeToAvoidBottomInset: true,
      endDrawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: _primaryBlue),
              child: Text(
                email,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: const Text('Home'),
              onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen())),
            ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Profile'),
              onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const ProfileScreen())),
            ),
            ListTile(
              leading: const Icon(Icons.emergency_outlined),
              title: const Text('Assistant Hub'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const AssistantHubPage()));
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                }
              },
            ),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Stack(
            children: [
              Image.asset(
                'assets/images/wavyheader.png',
                width: MediaQuery.of(context).size.width,
                height: 140,
                fit: BoxFit.fill,
                errorBuilder: (_, __, ___) => Container(height: 140, color: _primaryBlue),
              ),
              SafeArea(
                child: Builder(
                  builder: (ctx) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        _assetImage('assets/images/homelogo.png', width: 56, height: 56),
                        const SizedBox(width: 12),
                        Expanded(
                          child: widget.title != null
                              ? Text(
                                  widget.title!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : TextField(
                                  decoration: InputDecoration(
                                    hintText: 'Search here...',
                                    hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                                    prefixIcon: Icon(Icons.search, color: Colors.grey.shade600, size: 22),
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
                                ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.menu, color: Colors.white, size: 28),
                          onPressed: () => Scaffold.of(ctx).openEndDrawer(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Page Body
          Expanded(
            child: Stack(
              children: [
                widget.isBodyScrollable
                    ? SingleChildScrollView(
                        padding: widget.padBody ? const EdgeInsets.all(16) : EdgeInsets.zero,
                        child: widget.body,
                      )
                    : (widget.padBody ? Padding(padding: const EdgeInsets.all(16), child: widget.body) : widget.body),
                if (widget.showAuxiliaryButtons)
                  Positioned(
                    left: 16,
                    bottom: 20,
                    child: GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SosPage())),
                      child: _assetImage('assets/images/sospin.png', width: 56, height: 56),
                    ),
                  ),
                if (widget.showAuxiliaryButtons)
                  Positioned(
                    right: 16,
                    bottom: 20,
                    child: GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ChatListPage())),
                      child: _assetImage('assets/images/aibot.png', width: 56, height: 56),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _onItemTapped(0),
        backgroundColor: _primaryBlue,
        child: const Icon(Icons.home, color: Colors.white),
        elevation: 2.0,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        color: _primaryBlue.withOpacity(0.15),
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _navItem(context, 'assets/images/communavi.png', 'Community', 1),
              _navItem(context, 'assets/images/mappin.png', 'Map', 2),
              const SizedBox(width: 40), // Spacer for FAB
              _navItem(context, 'assets/images/notifi.png', 'Alerts', 3),
              _navItem(context, 'assets/images/profile.png', 'Profile', 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(BuildContext context, String iconPath, String label, int index) {
    final bool isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () => _onItemTapped(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _assetImage(
            iconPath,
            width: 26,
            height: 26,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isSelected ? _primaryBlue : _primaryBlue.withOpacity(0.6),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
            ),
          ),
        ],
      ),
    );
  }
}
