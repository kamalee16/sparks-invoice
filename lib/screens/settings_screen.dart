import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import 'company_settings_screen.dart';
import 'login_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? '';
    final initial = email.isNotEmpty ? email[0].toUpperCase() : 'U';
    final primary = Theme.of(context).colorScheme.primary;
    final onBg = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // Profile card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF232326),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.28),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: const Color(0xFF00E5CC).withOpacity(0.03),
                blurRadius: 18,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: primary.withOpacity(0.15),
              child: Text(initial, style: TextStyle(color: primary, fontWeight: FontWeight.bold, fontSize: 22)),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(email, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: onBg), overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text('Signed in', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ])),
          ]),
        ),
        const SizedBox(height: 24),

        // App info
        _SettingsTile(icon: Icons.info_outline_rounded, iconColor: AppColors.textSecondary, title: 'Version', trailing: const Text('1.0.0', style: TextStyle(color: AppColors.textSecondary, fontSize: 13))),
        const SizedBox(height: 18),

        // Company settings
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CompanySettingsScreen())),
          child: _SettingsTile(
            icon: Icons.business_outlined,
            iconColor: primary,
            title: 'Company Settings',
            trailing: Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(height: 24),

        // Logout
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () async {
              await AuthService().logout();
              if (context.mounted) Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
              );
            },
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Logout'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ]),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget trailing;
  const _SettingsTile({required this.icon, required this.iconColor, required this.title, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF232326),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.28),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: const Color(0xFF00E5CC).withOpacity(0.03),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Colors.white)),
        trailing: trailing,
      ),
    );
  }
}
