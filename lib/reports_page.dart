import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:erpms_app/app_shell.dart';
import 'package:erpms_app/models/report_model.dart';
import 'package:erpms_app/utils/location_helper.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';

const Color _primaryBlue = Color(0xFF004AAD);
const Color _navyTitle = Color(0xFF1D3557);

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  String _selectedCategory = 'All';
  String? _userDistrict;
  bool _isLoadingLocation = true;
  bool _showLocalOnly = false;

  final List<String> _categories = [
    'All',
    'Weather',
    'Environment',
    'Health',
    'Welfare'
  ];

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    try {
      final position = await LocationHelper.getCurrentPosition();
      final district = await LocationHelper.getDistrictForPosition(position);
      if (mounted) {
        setState(() {
          _userDistrict = district;
          _isLoadingLocation = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Public Reports',
      isBodyScrollable: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter Section
          _buildFilterHeader(),
          const SizedBox(height: 12),
          _buildCategoryChips(),
          const SizedBox(height: 16),
          
          // Reports List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getReportsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                
                final allDocs = snapshot.data!.docs;
                final reports = allDocs
                    .map((doc) => ReportModel.fromDoc(doc))
                    .where((r) {
                      // 1. Category Filter
                      if (_selectedCategory != 'All' && r.category != _selectedCategory) {
                        return false;
                      }
                      // 2. Local Filter (District matching)
                      if (_showLocalOnly && _userDistrict != null) {
                        return r.district?.toLowerCase() == _userDistrict!.toLowerCase();
                      }
                      return true;
                    })
                    .toList();

                if (reports.isEmpty) {
                  return _buildEmptyState();
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() {}); 
                  },
                  child: ListView.builder(
                    itemCount: reports.length,
                    padding: const EdgeInsets.only(bottom: 80),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemBuilder: (context, index) {
                      return _buildReportCard(reports[index]);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          _showLocalOnly ? 'LOCAL REPORTS (${_userDistrict ?? "Unknown"})' : 'NATIONAL UPDATES (INDIA)',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1.1),
        ),
        Row(
          children: [
            const Text('Local Only', style: TextStyle(fontSize: 12, color: Colors.grey)),
            Switch(
              value: _showLocalOnly,
              activeColor: _primaryBlue,
              onChanged: (val) {
                if (_userDistrict == null && val) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Location not detected. Cannot filter by local reports.")));
                  return;
                }
                setState(() => _showLocalOnly = val);
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final isSelected = _selectedCategory == cat;
          String label = cat;
          if (cat == 'Weather') label = 'Weather & Climate';
          if (cat == 'Environment') label = 'Environment & AQI';
          if (cat == 'Welfare') label = 'Health & Welfare';
          if (cat == 'Health') return const SizedBox.shrink();

          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(label),
              selected: isSelected,
              onSelected: (val) => setState(() => _selectedCategory = cat),
              selectedColor: _primaryBlue,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              backgroundColor: Colors.grey.shade100,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          );
        },
      ),
    );
  }

  Stream<QuerySnapshot> _getReportsStream() {
    return FirebaseFirestore.instance
        .collection('reports')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Widget _buildReportCard(ReportModel report) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _getCategoryIcon(report.category),
                    const SizedBox(width: 8),
                    Text(
                      _getCategoryLabel(report.category).toUpperCase(),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                    ),
                    const Spacer(),
                    if (report.district != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)),
                        child: Text(report.district!, style: const TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  report.title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _navyTitle),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      'Source: ${report.source}',
                      style: const TextStyle(fontSize: 12, color: _primaryBlue, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    const Text('•', style: TextStyle(color: Colors.grey)),
                    const SizedBox(width: 8),
                    Text(
                      _formatTimestamp(report.timestamp),
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  report.summary,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF4D4C4C), height: 1.4),
                ),
                if (report.category == 'Environment') _buildAQIMeter(report.summary),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: ElevatedButton(
              onPressed: report.url != null ? () => _launchURL(report.url!) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('Read Full Advisory (${report.source})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAQIMeter(String summary) {
    final regExp = RegExp(r'AQI:?\s*(\d+)');
    final match = regExp.firstMatch(summary);
    if (match == null) return const SizedBox.shrink();
    
    final aqi = int.tryParse(match.group(1)!) ?? 0;
    Color color = Colors.green;
    String status = "Good";
    if (aqi > 50) { color = Colors.yellow.shade700; status = "Moderate"; }
    if (aqi > 100) { color = Colors.orange; status = "Unhealthy for Sensitive Groups"; }
    if (aqi > 150) { color = Colors.red; status = "Unhealthy"; }
    
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Icon(Icons.speed, color: color, size: 20),
          const SizedBox(width: 8),
          Text('AQI: $aqi ($status)', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  String _getCategoryLabel(String cat) {
    if (cat == 'Weather') return 'Weather & Climate';
    if (cat == 'Environment') return 'Environment & AQI';
    if (cat == 'Welfare' || cat == 'Health') return 'Health & Welfare';
    return cat;
  }

  Widget _getCategoryIcon(String category) {
    IconData icon;
    Color color;
    switch (category) {
      case 'Weather':
        icon = Icons.cloud_outlined;
        color = Colors.blue;
        break;
      case 'Environment':
        icon = Icons.factory_outlined;
        color = Colors.green;
        break;
      case 'Health':
      case 'Welfare':
        icon = Icons.medical_services_outlined;
        color = Colors.redAccent;
        break;
      default:
        icon = Icons.article_outlined;
        color = Colors.grey;
    }
    return Icon(icon, size: 18, color: color);
  }

  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final date = timestamp.toDate();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) {
      return 'Updated ${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return 'Updated ${diff.inHours}h ago';
    } else {
      return DateFormat('dd MMM yyyy').format(date);
    }
  }

  Future<void> _launchURL(String urlString) async {
    try {
      final Uri url = Uri.parse(urlString.trim());
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        debugPrint('Could not launch $urlString');
        // Fallback for some Android configurations
        await launchUrl(url, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            _showLocalOnly 
              ? 'No local reports found for ${_userDistrict ?? "your area"}.' 
              : 'No national reports available yet.',
            style: const TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
