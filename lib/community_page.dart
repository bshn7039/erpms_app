import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:erpms_app/app_shell.dart';
import 'package:erpms_app/join_us_page.dart';

const Color _primaryBlue = Color(0xFF004AAD);

class Story {
  final String id;
  final String title;
  final String author;
  final bool isVerified;
  final String date;
  final String fullContent;
  final String? imageUrl;

  const Story({
    required this.id,
    required this.title,
    required this.author,
    required this.isVerified,
    required this.date,
    required this.fullContent,
    this.imageUrl,
  });
}

class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key});

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  int? _totalUsers;
  int? _totalVolunteers;
  int? _queriesHandled;
  String? _role;
  String? _volunteerStatus;
  bool _loadingStats = true;

  final List<Story> _stories = const [
    Story(
      id: '1',
      title: 'Saved by ERPMS AI',
      author: 'Anita Verma',
      isVerified: true,
      date: 'Feb 2026 · Panvel',
      fullContent:
          'During sudden flooding in Sector 7, Anita used the ERPMS AI assistant to understand the safest route out of her area. '
          'Verified volunteers nearby received her request, coordinated through the NGO network, and helped evacuate her family within 40 minutes.',
    ),
    Story(
      id: '2',
      title: 'Night-time Medical Coordination',
      author: 'ReliefCare NGO',
      isVerified: true,
      date: 'Jan 2026 · Navi Mumbai',
      fullContent:
          'A volunteer used the ERPMS app to flag a late-night medical emergency. The request was routed to a verified NGO partner, '
          'who coordinated an ambulance, shared a digital medical summary, and updated the family through the app alerts.',
    ),
    Story(
      id: '3',
      title: 'Local Shelter Setup in 3 Hours',
      author: 'Community Volunteers',
      isVerified: false,
      date: 'Dec 2025 · Sector 4',
      fullContent:
          'After a fire in a residential block, local volunteers used ERPMS to list available spaces, water, and food. '
          'Within three hours, a temporary shelter was up and mapped in the app for nearby residents.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadStatsAndUser();
  }

  Future<void> _loadStatsAndUser() async {
    try {
      final usersCountSnap = await FirebaseFirestore.instance.collection('users').count().get();
      final volunteersCountSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'volunteer')
          .count()
          .get();

      // Count of personal alerts (SOS/Requests) that are marked as resolved
      final queriesHandledSnap = await FirebaseFirestore.instance
          .collection('alerts')
          .where('visibility', isEqualTo: 'personal')
          .where('status', isEqualTo: 'resolved')
          .count()
          .get();

      String? role;
      String? volunteerStatus;
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final userDoc =
            await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
        final data = userDoc.data();
        if (data != null) {
          role = data['role'] as String?;
          volunteerStatus = data['volunteer_status'] as String?;
        }
      }

      if (!mounted) return;
      setState(() {
        _totalUsers = usersCountSnap.count;
        _totalVolunteers = volunteersCountSnap.count;
        _queriesHandled = queriesHandledSnap.count;
        _role = role ?? 'user';
        _volunteerStatus = volunteerStatus ?? 'Not Applied';
        _loadingStats = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingStats = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      padBody: true,
      isBodyScrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeroHeader(context),
          const SizedBox(height: 16),
          _buildCrisisPillars(),
          const SizedBox(height: 18),
          _buildImpactMetrics(),
          const SizedBox(height: 20),
          _buildActionCenter(context),
          const SizedBox(height: 24),
          const Text(
            'COMMUNITY STORIES',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1D3557),
            ),
          ),
          const SizedBox(height: 12),
          ..._stories.map((story) => _buildStoryCard(context, story)).toList(),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildHeroHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF004AAD), Color(0xFF0077FF)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(
            Icons.public,
            color: Colors.white,
            size: 40,
          ),
          SizedBox(height: 14),
          Text(
            'UNIVERSAL HELP\nIN ANY CRISIS',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              height: 1.25,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Connecting needs. Coordinating action. Saving lives.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCrisisPillars() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CRISIS PILLARS',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1D3557),
          ),
        ),
        const SizedBox(height: 0),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.6,
          children: const [
            _InfoSoftCard(
              icon: Icons.landscape,
              title: 'Disaster Response',
              subtitle: 'Safety guides, alerts',
            ),
            _InfoSoftCard(
              icon: Icons.emergency,
              title: 'Medical Urgency',
              subtitle: 'First-aid, 108 connect',
            ),
            _InfoSoftCard(
              icon: Icons.groups,
              title: 'NGO Network',
              subtitle: 'Verified local partners',
            ),
            _InfoSoftCard(
              icon: Icons.local_shipping,
              title: 'Resource Logistics',
              subtitle: 'Food, water, shelter',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildImpactMetrics() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'OUR IMPACT IN NUMBERS',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1D3557),
          ),
        ),
        const SizedBox(height: 6),
        if (_loadingStats)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: SizedBox(
              height: 28,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          )
        else
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  label: 'TOTAL USERS',
                  value: _totalUsers?.toString() ?? '0',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricCard(
                  label: 'VOLUNTEERS READY',
                  value: _totalVolunteers?.toString() ?? '0',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricCard(
                  label: 'QUERIES\nHANDLED',
                  value: _queriesHandled?.toString() ?? '0',
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildActionCenter(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ACTION CENTER',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1D3557),
          ),
        ),
        const SizedBox(height: 12),
        Builder(
          builder: (context) {
            String label = 'BECOME A VOLUNTEER';
            VoidCallback? onPressed;

            if (_role == 'volunteer') {
              label = 'VOLUNTEER DASHBOARD';
              onPressed = () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const JoinUsPage(),
                  ),
                );
              };
            } else if (_volunteerStatus == 'Pending' ||
                _volunteerStatus == 'pending') {
              label = 'APPLICATION PENDING';
              onPressed = null;
            } else {
              onPressed = () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const JoinUsPage(),
                  ),
                );
              };
            }

            final bool isDisabled = onPressed == null;

            return SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isDisabled ? Colors.grey.shade300 : _primaryBlue,
                  foregroundColor:
                      isDisabled ? Colors.grey.shade700 : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: onPressed,
                icon: const Icon(Icons.handshake_outlined),
                label: Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    fontSize: 14,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStoryCard(BuildContext context, Story story) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StoryDetailPage(story: story),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: _primaryBlue.withOpacity(0.12),
              child: const Icon(
                Icons.person,
                color: _primaryBlue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    story.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1D3557),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        story.author,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4D4C4C),
                        ),
                      ),
                      if (story.isVerified) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.verified,
                          size: 16,
                          color: _primaryBlue,
                        ),
                      ],
                      const SizedBox(width: 6),
                      const Text(
                        '•',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        story.date,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    story.fullContent,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF4D4C4C),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoSoftCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _InfoSoftCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: _primaryBlue,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1D3557),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF4D4C4C),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;

  const _MetricCard({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _primaryBlue,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF4D4C4C),
            ),
          ),
        ],
      ),
    );
  }
}

class StoryDetailPage extends StatelessWidget {
  final Story story;

  const StoryDetailPage({super.key, required this.story});

  @override
  Widget build(BuildContext context) {
    return AppShell(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            story.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1D3557),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                story.author,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4D4C4C),
                ),
              ),
              if (story.isVerified) ...[
                const SizedBox(width: 4),
                const Icon(
                  Icons.verified,
                  size: 18,
                  color: _primaryBlue,
                ),
              ],
              const SizedBox(width: 6),
              const Text(
                '•',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                story.date,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            story.fullContent,
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              color: Color(0xFF4D4C4C),
            ),
          ),
        ],
      ),
    );
  }
}
