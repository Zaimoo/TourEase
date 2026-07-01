import 'package:flutter/material.dart';
import 'package:tourease/services/use_auth.dart';
import 'package:tourease/view/fare_admin_screen.dart';
import 'package:tourease/view/jeepney_routes_screen.dart';
import 'package:tourease/view/login_screen.dart';

class SettingsScreen extends StatelessWidget {
  /// Whether the signed-in user is an admin. Admin-only entries (fare
  /// management, debug tools) are hidden when false.
  final bool isAdmin;

  const SettingsScreen({super.key, this.isAdmin = false});

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.logout, color: Colors.orange),
              SizedBox(width: 8),
              Text('Logout'),
            ],
          ),
          content: const Text(
              'Are you sure you want to log out?\nYou will need to sign in again.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await UseAuth().signOut();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteAccountConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text('Delete Account'),
            ],
          ),
          content: const Text(
            'Are you sure you want to permanently delete your account?\n\n'
            'This action cannot be undone. All your data, favorites, reviews, '
            'and trip history will be permanently removed.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                try {
                  final auth = UseAuth();
                  await auth.user?.delete();
                  await auth.signOut();
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting account: $e')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Delete Permanently'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Settings", style: TextStyle(color: Colors.black)),
        backgroundColor: const Color(0xFFB6DCFE),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSettingItem(Icons.notifications, "Notifications"),
          _buildSettingItem(Icons.lock_outline, "Privacy"),
          _buildSettingItem(Icons.language, "Language"),
          _buildSettingItem(Icons.help_outline, "Help & Support"),
          if (isAdmin) ...[
            const Divider(),
            _buildSettingItem(
              Icons.bug_report,
              "DEBUG: ROUTE VIEWER",
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const JeepneyRoutesScreen()),
                );
              },
            ),
            _buildSettingItem(
              Icons.payments_outlined,
              "Manage Fares (Admin)",
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const FareAdminScreen()),
                );
              },
            ),
          ],
          _buildSettingItem(Icons.info_outline, "About App"),
          const SizedBox(height: 8),
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            margin: const EdgeInsets.only(bottom: 16),
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.orange),
              title: const Text("Logout",
                  style: TextStyle(
                      color: Colors.orange, fontWeight: FontWeight.w600)),
              trailing: const Icon(Icons.arrow_forward_ios,
                  size: 16, color: Colors.orange),
              onTap: () => _showLogoutConfirmation(context),
            ),
          ),
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            margin: const EdgeInsets.only(bottom: 16),
            child: ListTile(
              leading:
                  const Icon(Icons.delete_forever, color: Colors.redAccent),
              title: const Text("Delete Account",
                  style: TextStyle(
                      color: Colors.redAccent, fontWeight: FontWeight.w600)),
              trailing: const Icon(Icons.arrow_forward_ios,
                  size: 16, color: Colors.redAccent),
              onTap: () => _showDeleteAccountConfirmation(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem(IconData icon, String title, {VoidCallback? onTap}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: Icon(icon, color: Colors.blueAccent),
        title: Text(title),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap ?? () {},
      ),
    );
  }
}
