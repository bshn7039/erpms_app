import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:erpms_app/app_shell.dart';
import 'package:erpms_app/models/volunteer_model.dart';

const Color _primaryBlue = Color(0xFF004AAD);
const Color _navyTitle = Color(0xFF1D3557);
const Color _textDark = Color(0xFF4D4C4C);

class AdminVolunteerPage extends StatefulWidget {
  const AdminVolunteerPage({super.key});

  @override
  State<AdminVolunteerPage> createState() => _AdminVolunteerPageState();
}

class _AdminVolunteerPageState extends State<AdminVolunteerPage> {
  String _searchCity = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Volunteer Applications',
      isBodyScrollable: false,
      showAuxiliaryButtons: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          _buildSearchBar(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text(
                        'Database Error: ${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('No pending applications found.'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final volunteer = VolunteerModel.fromDoc(snapshot.data!.docs[index]);
                    return _VolunteerApplicationCard(volunteer: volunteer);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _getStream() {
    Query query = FirebaseFirestore.instance
        .collection('volunteers')
        .where('status', isEqualTo: 'pending');
    
    if (_searchCity.isNotEmpty) {
      query = query.where('city', isEqualTo: _searchCity);
    }
    
    return query.orderBy('applied_at', descending: true).snapshots();
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('Back to Command Center'),
          ),
          const SizedBox(height: 8),
          const Text(
            'Pending Applications (Nationwide)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _navyTitle),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search by City',
          prefixIcon: const Icon(Icons.search, color: _primaryBlue),
          suffixIcon: _searchCity.isNotEmpty 
            ? IconButton(
                icon: const Icon(Icons.clear), 
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchCity = '');
                }
              ) 
            : null,
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
        onSubmitted: (val) {
          setState(() => _searchCity = val.trim());
        },
      ),
    );
  }
}

class _VolunteerApplicationCard extends StatefulWidget {
  final VolunteerModel volunteer;
  const _VolunteerApplicationCard({required this.volunteer});

  @override
  State<_VolunteerApplicationCard> createState() => _VolunteerApplicationCardState();
}

class _VolunteerApplicationCardState extends State<_VolunteerApplicationCard> {
  bool _isExpanded = false;
  String _selectedGenre = 'General';
  final List<String> _genres = ['General', 'Medical', 'Physical', 'Rescue', 'Logistics', 'Tech'];

  @override
  Widget build(BuildContext context) {
    final v = widget.volunteer;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    v.name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _buildLocationBadge(v.city),
              ],
            ),
            const SizedBox(height: 4),
            Text('Skills: ${v.skills.join(", ")}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 12),
            if (!_isExpanded)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => setState(() => _isExpanded = true),
                  child: const Text('Review Proof'),
                ),
              ),
            if (_isExpanded) ...[
              const Divider(),
              const Text('Proof of Identity & Skills', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildProofImage('Identity Document', v.id_64),
                  const SizedBox(width: 8),
                  _buildProofImage('Skill Certificate', v.skill_64),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Assign Volunteer Genre:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              DropdownButton<String>(
                value: _selectedGenre,
                isExpanded: true,
                items: _genres.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                onChanged: (val) => setState(() => _selectedGenre = val!),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _updateStatus(v.uid, 'approved'),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _updateStatus(v.uid, 'rejected'),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Reject'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Center(
                child: IconButton(
                  icon: const Icon(Icons.keyboard_arrow_up),
                  onPressed: () => setState(() => _isExpanded = false),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLocationBadge(String city) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: _primaryBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Text(city, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _primaryBlue)),
    );
  }

  Widget _buildProofImage(String label, String? b64) {
    return Expanded(
      child: Column(
        children: [
          Container(
            height: 100,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: b64 != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(base64Decode(b64), fit: BoxFit.cover),
                  )
                : const Icon(Icons.image_not_supported, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Future<void> _updateStatus(String uid, String status) async {
    try {
      await FirebaseFirestore.instance.collection('volunteers').doc(uid).update({
        'status': status,
        if (status == 'approved') 'genre': _selectedGenre,
      });
      
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'volunteer_status': status == 'approved' ? 'Verified' : status,
        if (status == 'approved') 'role': 'volunteer',
        if (status == 'approved') 'volunteer_genre': _selectedGenre,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Volunteer $status as $_selectedGenre')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}
