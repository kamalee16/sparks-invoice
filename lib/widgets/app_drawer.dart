import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';

class AppDrawer extends StatelessWidget {
  final String currentRoute;
  const AppDrawer({Key? key, required this.currentRoute}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final primary = Theme.of(context).colorScheme.primary;
    final email = user?.email ?? '';
    final initial = email.isNotEmpty ? email[0].toUpperCase() : 'U';
    final onBg = Theme.of(context).colorScheme.onSurface;

    return Drawer(
      backgroundColor: AppColors.darkSurface,
      child: Column(children: [
        // ── Header — clickable logo navigates to dashboard ───────────────────
        GestureDetector(
          onTap: () {
            Navigator.pop(context);
            Navigator.pushReplacementNamed(context, '/dashboard');
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 64, 24, 32),
            decoration: BoxDecoration(
              gradient: AppColors.heroGradient,
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.flash_on_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 20),
              const Text('Sparks Invoice',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
              const SizedBox(height: 8),
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                  child: CircleAvatar(
                    radius: 10,
                    backgroundColor: Colors.transparent,
                    child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(email,
                      style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis),
                ),
              ]),
            ]),
          ),
        ),

        const SizedBox(height: 16),
        Expanded(
          child: ListView(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), children: [
            _NavItem(icon: Icons.grid_view_rounded, activeIcon: Icons.grid_view_rounded, label: 'Dashboard', route: '/dashboard', current: currentRoute),
            _NavItem(icon: Icons.add_circle_outline_rounded, activeIcon: Icons.add_circle_rounded, label: 'New Invoice', route: '/create-invoice', current: currentRoute),
            _NavItem(icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long_rounded, label: 'All Invoices', route: '/invoices', current: currentRoute),
            _NavItem(icon: Icons.people_outline_rounded, activeIcon: Icons.people_rounded, label: 'Clients', route: '/clients', current: currentRoute),
            _NavItem(icon: Icons.settings_outlined, activeIcon: Icons.settings_rounded, label: 'Settings', route: '/settings', current: currentRoute),
          ]),
        ),

        // ── Logout ───────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          child: ListTile(
            onTap: () async {
              Navigator.pop(context);
              await AuthService().logout();
              if (context.mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
            },
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            tileColor: AppColors.danger.withOpacity(0.1),
            leading: const Icon(Icons.logout_rounded, color: AppColors.danger, size: 22),
            title: const Text('Logout', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ),
      ]),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon, activeIcon;
  final String label, route, current;
  const _NavItem({required this.icon, required this.activeIcon, required this.label, required this.route, required this.current});

  @override
  Widget build(BuildContext context) {
    final active = current == route;
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: active ? primary.withOpacity(0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        onTap: () {
          Navigator.pop(context);
          if (!active) Navigator.pushReplacementNamed(context, route);
        },
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: Icon(active ? activeIcon : icon, color: active ? primary : AppColors.textSecondary, size: 24),
        title: Text(label, style: TextStyle(color: active ? primary : AppColors.textSecondary, fontWeight: active ? FontWeight.w900 : FontWeight.w600, fontSize: 15)),
      ),
    );
  }
}
