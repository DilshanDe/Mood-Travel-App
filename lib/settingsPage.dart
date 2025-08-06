import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:traveltest_app/services/shared_pref.dart';
import 'package:traveltest_app/forgot_password.dart'; // Add this import

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _selectedTheme = 'System';

  final List<String> _themes = ['Light', 'Dark', 'System'];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    // Load settings from SharedPreferences
    // This is just example - you'll need to implement actual storage
    setState(() {
      // Load your saved settings here
    });
  }

  Future<void> _saveSettings() async {
    // Save settings to SharedPreferences
    // Implementation needed
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: const Color(0xFF273671),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Privacy & Security Section
          _buildSectionHeader('Privacy & Security'),
          _buildSettingTile(
            icon: Icons.security,
            title: 'Change Password',
            subtitle: 'Update your account password',
            onTap: _changePassword,
          ),
          _buildSettingTile(
            icon: Icons.privacy_tip,
            title: 'Privacy Settings',
            subtitle: 'Manage your privacy preferences',
            onTap: _showPrivacySettings,
          ),

          const SizedBox(height: 20),

          // App Preferences Section
          _buildSectionHeader('App Preferences'),
          _buildDropdownSetting(
            icon: Icons.palette,
            title: 'Theme',
            subtitle: 'App appearance',
            value: _selectedTheme,
            items: _themes,
            onChanged: (value) => setState(() => _selectedTheme = value!),
          ),

          const SizedBox(height: 20),

          // Support Section
          _buildSectionHeader('Support'),
          _buildSettingTile(
            icon: Icons.info_outline,
            title: 'About',
            subtitle: 'App version and information',
            onTap: _showAbout,
          ),

          const SizedBox(height: 30),

          // Save Button
          ElevatedButton(
            onPressed: () async {
              await _saveSettings();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Settings saved successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF273671),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Save Settings', style: TextStyle(fontSize: 16)),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF273671),
        ),
      ),
    );
  }

  Widget _buildSwitchSetting({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: SwitchListTile(
        secondary: Icon(icon, color: const Color(0xFF273671)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFF273671),
      ),
    );
  }

  Widget _buildDropdownSetting({
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF273671)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: DropdownButton<String>(
          value: value,
          onChanged: onChanged,
          underline: Container(),
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF273671)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  // Method implementations
  void _changePassword() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ForgotPassword()),
    );
  }

  void _showPrivacySettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Settings'),
        content: const Text(
            'Privacy settings will include:\n\n• Profile visibility\n• Location sharing\n• Data collection preferences\n• Third-party integrations'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _manageDownloadedMaps() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Downloaded Maps'),
        content: const Text(
            'Manage your offline maps:\n\n• Sri Lanka (850 MB)\n• Southeast Asia (1.2 GB)\n• Europe (50 MB)'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Manage'),
          ),
        ],
      ),
    );
  }

  void _clearCache() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text(
            'This will clear temporary files and free up storage space. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cache cleared successfully!')),
              );
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showBackupSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Backup & Sync'),
        content: const Text(
            'Backup settings:\n\n• Auto backup: ON\n• Last backup: Today 2:30 PM\n• Backup size: 45 MB\n\nIncludes: Favorites, itineraries, photos'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showAbout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Travel App'),
        content: const Text(
            'Mood Trip v2.1.0\n\n🤖 AI-Powered Travel Companion\n\nDiscover your perfect destinations with intelligent recommendations based on your mood, preferences, and travel behavior.\n\n✨ Features:\n• Smart destination suggestions\n• Mood-based trip planning\n• Personalized experiences\n• Real-time recommendations\n\nDeveloped with ❤️ for adventurous travelers\n\n© 2025 Mood Trip Team'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
