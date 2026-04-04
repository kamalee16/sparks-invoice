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
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDark;
    final primary = Theme.of(context).colorScheme.primary;
    final email = user?.email ?? '';
    final initial = email.isNotEmpty ? email[0].toUpperCase() : 'U';
    final onBg = Theme.of(context).colorScheme.onSurface;

    return Drawer(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      child: Column(children: [
        // ── Header — clickable logo navigates to dashboard ───────────────────
        GestureDetector(
          onTap: () {
            Navigator.pop(context);
            Navigator.pushReplacementNamed(context, '/dashboard');
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primaryGradientStart, AppColors.primaryGradientEnd],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 26),
              ),
              const SizedBox(height: 16),
              const Text('Sparks Invoice',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Row(children: [
                CircleAvatar(
                  radius: 10,
                  backgroundColor: Colors.white.withOpacity(0.25),
                  child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(email,
                      style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
                      overflow: TextOverflow.ellipsis),
                ),
              ]),
            ]),
          ),
        ),

        const SizedBox(height: 8),
        Expanded(
          child: ListView(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), children: [
            _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home', route: '/home', current: currentRoute),
            _NavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard_rounded, label: 'Dashboard', route: '/dashboard', current: currentRoute),
            _NavItem(icon: Icons.add_circle_outline_rounded, activeIcon: Icons.add_circle_rounded, label: 'Create Invoice', route: '/create-invoice', current: currentRoute),
            _NavItem(icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long_rounded, label: 'Invoices', route: '/invoices', current: currentRoute),
            _NavItem(icon: Icons.people_outline_rounded, activeIcon: Icons.people_rounded, label: 'Clients', route: '/clients', current: currentRoute),
          ]),
        ),

        // ── Dark mode toggle ─────────────────────────────────────────────────
        Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightBorder),
          ),
          child: Row(children: [
            Icon(isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded, color: primary, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text('Dark Mode', style: TextStyle(fontSize: 14, color: onBg, fontWeight: FontWeight.w500))),
            Switch(
              value: isDark,
              onChanged: (_) => themeProvider.toggle(),
              activeColor: primary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ]),
        ),

        // ── Logout ───────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
          child: ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            tileColor: AppColors.danger.withOpacity(0.08),
            leading: const Icon(Icons.logout_rounded, color: AppColors.danger, size: 20),
            title: const Text('Logout', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600, fontSize: 14)),
            onTap: () async {
              Navigator.pop(context);
              await AuthService().logout();
              if (context.mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
            },
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
    final isActive = current == route;
    final primary = Theme.of(context).colorScheme.primary;
    final onBg = Theme.of(context).colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: isActive ? primary.withOpacity(0.12) : null,
        leading: Icon(
          isActive ? activeIcon : icon,
          color: isActive ? primary : AppColors.textSecondary,
          size: 20,
        ),
        title: Text(label, style: TextStyle(
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          fontSize: 14,
          color: isActive ? primary : onBg,
        )),
        onTap: () {
          Navigator.pop(context);
          if (!isActive) Navigator.pushReplacementNamed(context, route);
        },
      ),
    );
  }
}
