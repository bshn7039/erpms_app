import 'package:flutter/material.dart';
import 'package:erpms_app/app_shell.dart';
import 'package:erpms_app/admin_volunteer_page.dart';
import 'package:erpms_app/admin_incidents_page.dart';
import 'package:erpms_app/admin_user_management_page.dart';
import 'package:erpms_app/create_alert_page.dart';

const Color _primaryBlue = Color(0xFF004AAD);
const Color _navyTitle = Color(0xFF1D3557);

class AdminHubPage extends StatelessWidget {
  const AdminHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Admin Panel',
      showAuxiliaryButtons: false,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBackButton(context),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                'Admin Panel',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _navyTitle,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildHubCard(
              context,
              icon: Icons.people,
              title: 'Volunteer Management',
              subtitle: 'Review and verify pending applications across all cities',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AdminVolunteerPage()),
              ),
              isNew: true,
            ),
            _buildHubCard(
              context,
              icon: Icons.map_outlined,
              title: 'Active Incidents',
              subtitle: 'Live global incident monitoring and resolution',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AdminIncidentsPage()),
              ),
            ),
            _buildHubCard(
              context,
              icon: Icons.manage_accounts,
              title: 'User & Role Management',
              subtitle: 'Promote roles, moderate users, and manage directory',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AdminUserManagementPage()),
              ),
            ),
            _buildHubCard(
              context,
              icon: Icons.add_alert,
              title: 'Create Emergency Alert',
              subtitle: 'Manually broadcast a public or personal alert',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CreateAlertPage(isAdminOrVolunteer: true)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextButton.icon(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back, color: _primaryBlue),
        label: const Text('Back to Home', style: TextStyle(color: _primaryBlue, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildHubCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    bool isNew = false,
  }) {
    bool isEnabled = onTap != null;
    return Opacity(
      opacity: isEnabled ? 1.0 : 0.6,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.all(16),
          leading: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: _primaryBlue, size: 30),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isNew) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('New', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
          trailing: const Icon(Icons.chevron_right),
        ),
      ),
    );
  }
}
