import 'package:flutter/material.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:geolocator/geolocator.dart';
import 'package:erpms_app/utils/location_helper.dart';

/// Professional splash screen: logo + typewriter title, then navigate to Login.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const Color _cobaltBlue = Color(0xFF004aad);

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    try {
      Position position = await LocationHelper.getCurrentPosition();
      String? district = await LocationHelper.getDistrictForPosition(position);
      LocationHelper.currentDistrict = district;
    } catch (e) {
      debugPrint("Location initialization failed: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  height: 200,
                  width: 200,
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.image_not_supported_outlined,
                      size: 100,
                      color: Colors.grey,
                    ),
                  ),
                ),
                const SizedBox(height: 36),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: AnimatedTextKit(
                    animatedTexts: [
                      TypewriterAnimatedText(
                        'Emergency Resource and Public Help Management System',
                        textStyle: const TextStyle(
                          color: _cobaltBlue,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                          height: 1.35,
                        ),
                        speed: const Duration(milliseconds: 80),
                        cursor: '',
                      ),
                    ],
                    isRepeatingAnimation: false,
                    totalRepeatCount: 1,
                    onFinished: () {
                      if (mounted) {
                        Navigator.pushReplacementNamed(context, '/');
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
