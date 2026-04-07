import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:erpms_app/app_shell.dart';

const Color _primaryBlue = Color(0xFF004AAD);
const Color _navyTitle = Color(0xFF1D3557);

class AdminUserManagementPage extends StatefulWidget {
  const AdminUserManagementPage({super.key});

  @override
  State<AdminUserManagementPage> createState() => _AdminUserManagementPageState();
}

class _AdminUserManagementPageState extends State<AdminUserManagementPage> {
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'User Management',
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
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No users found.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final userData = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                    final userId = snapshot.data!.docs[index].id;
                    return _UserCard(userId: userId, userData: userData);
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
    Query query = FirebaseFirestore.instance.collection('users');
    
    if (_searchQuery.isNotEmpty) {
      query = query.where('full_name', isGreaterThanOrEqualTo: _searchQuery)
                   .where('full_name', isLessThanOrEqualTo: '$_searchQuery\uf8ff');
    }
    
    return query.snapshots();
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
            'User Directory & Roles',
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
          hintText: 'Search by Name',
          prefixIcon: const Icon(Icons.search, color: _primaryBlue),
          suffixIcon: _searchQuery.isNotEmpty 
            ? IconButton(
                icon: const Icon(Icons.clear), 
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                }
              ) 
            : null,
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
        onChanged: (val) {
          setState(() => _searchQuery = val.trim());
        },
      ),
    );
  }
}

class _UserCard extends StatefulWidget {
  final String userId;
  final Map<String, dynamic> userData;
  const _UserCard({required this.userId, required this.userData});

  @override
  State<_UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<_UserCard> {
  String? _pendingGenre;
  final List<String> _genres = ['Medical', 'Physical', 'Rescue', 'Logistics', 'Tech', 'General'];

  @override
  void initState() {
    super.initState();
    _pendingGenre = widget.userData['volunteer_genre'] ?? 'General';
  }

  @override
  Widget build(BuildContext context) {
    final String name = widget.userData['full_name'] ?? 'Unknown';
    final String email = widget.userData['email'] ?? 'No email';
    final String role = widget.userData['role'] ?? 'user';
    final bool isBanned = widget.userData['is_banned'] ?? false;
    final String genre = widget.userData['volunteer_genre'] ?? 'N/A';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _primaryBlue.withOpacity(0.1),
          child: Text(name[0].toUpperCase(), style: const TextStyle(color: _primaryBlue, fontWeight: FontWeight.bold)),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Role: ${role.toUpperCase()} ${role == 'volunteer' ? '($genre)' : ''} • $email', style: const TextStyle(fontSize: 12)),
        trailing: isBanned ? const Icon(Icons.block, color: Colors.red, size: 20) : null,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                const Text('Change Role:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _primaryBlue)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _roleButton(context, 'user', 'Set User', role),
                    _roleButton(context, 'volunteer', 'Set Vol', role),
                    _roleButton(context, 'admin', 'Set Admin', role),
                  ],
                ),
                if (role == 'volunteer') ...[
                  const SizedBox(height: 20),
                  const Text('Set Volunteer Genre:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _primaryBlue)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                    child: DropdownButton<String>(
                      value: _pendingGenre,
                      isExpanded: true,
                      underline: const SizedBox(),
                      items: _genres.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                      onChanged: (val) {
                        setState(() => _pendingGenre = val);
                        _updateGenre(context, val!);
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _toggleBan(context, widget.userId, isBanned),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isBanned ? Colors.green : Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(isBanned ? 'Unsuspend User' : 'Suspend / Ban User'),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _roleButton(BuildContext context, String targetRole, String label, String currentRole) {
    bool isCurrent = currentRole == targetRole;
    return ElevatedButton(
      onPressed: isCurrent ? null : () => _updateRole(context, targetRole),
      style: ElevatedButton.styleFrom(
        backgroundColor: isCurrent ? Colors.grey : _primaryBlue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        textStyle: const TextStyle(fontSize: 11),
      ),
      child: Text(label),
    );
  }

  Future<void> _updateRole(BuildContext context, String targetRole) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({
        'role': targetRole,
        if (targetRole == 'volunteer') 'volunteer_genre': _pendingGenre ?? 'General',
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Role updated to $targetRole')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _updateGenre(BuildContext context, String genre) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({
        'volunteer_genre': genre,
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Genre updated to $genre')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _toggleBan(BuildContext context, String uid, bool currentlyBanned) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'is_banned': !currentlyBanned,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(currentlyBanned ? 'User Unsuspended' : 'User Suspended'))
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}
