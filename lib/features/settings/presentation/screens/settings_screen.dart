import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _darkMode = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _buildSectionHeader('Business'),
          _buildSettingsTile(
            icon: Icons.business,
            title: 'Business Profile',
            subtitle: 'Manage your business details',
            onTap: () => context.push('/settings/business-profile'),
          ),
          _buildSettingsTile(
            icon: Icons.receipt_long,
            title: 'Invoice Template',
            subtitle: 'Customize invoice appearance',
            onTap: () => context.push('/settings/invoice-template'),
          ),
          _buildSettingsTile(
            icon: Icons.chat,
            title: 'WhatsApp Templates',
            subtitle: 'Manage message templates',
            onTap: () => context.push('/settings/whatsapp-templates'),
          ),
          const Divider(),
          _buildSectionHeader('HR & Payroll'),
          _buildSettingsTile(
            icon: Icons.people,
            title: 'Employees',
            subtitle: 'Manage staff',
            onTap: () => context.push('/employees'),
          ),
          _buildSettingsTile(
            icon: Icons.calendar_today,
            title: 'Attendance',
            subtitle: 'Mark daily attendance',
            onTap: () => context.push('/attendance'),
          ),
          _buildSettingsTile(
            icon: Icons.payments,
            title: 'Salary',
            subtitle: 'Calculate salaries',
            onTap: () => context.push('/salary'),
          ),
          const Divider(),
          _buildSectionHeader('Security'),
          _buildSettingsTile(
            icon: Icons.admin_panel_settings,
            title: 'Roles & Permissions',
            subtitle: 'Manage user access',
            onTap: () => context.push('/settings/roles-permissions'),
          ),
          _buildSettingsTile(
            icon: Icons.backup,
            title: 'Backup',
            subtitle: 'Backup and restore data',
            onTap: () {},
          ),
          const Divider(),
          _buildSectionHeader('Preferences'),
          _buildSettingsTile(
            icon: Icons.currency_rupee,
            title: 'Currency',
            subtitle: 'INR (₹)',
            onTap: () {},
          ),
          _buildSettingsTile(
            icon: Icons.language,
            title: 'Language',
            subtitle: 'English',
            onTap: () {},
          ),
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode),
            title: const Text('Dark Mode'),
            subtitle: const Text('Toggle dark theme'),
            value: _darkMode,
            onChanged: (value) {
              setState(() => _darkMode = value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
