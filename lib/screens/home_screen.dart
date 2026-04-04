import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_drawer.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final border = isDark ? AppColors.darkCardBorder : AppColors.lightBorder;

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.receipt_long_rounded, color: AppColors.accent, size: 18),
          ),
          const SizedBox(width: 10),
          const Text('Sparks Invoice'),
        ]),
        actions: [_ProfileAvatar()],
      ),
      drawer: const AppDrawer(currentRoute: '/home'),
      body: SingleChildScrollView(
        child: Column(children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(28, 48, 28, 48),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1A1A24), Color(0xFF2A1A0E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.accent.withOpacity(0.3), width: 1.5),
                ),
                child: const Icon(Icons.receipt_long_rounded, size: 48, color: AppColors.accent),
              ),
              const SizedBox(height: 24),
              const Text('Sparks Invoice', textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -0.5)),
              const SizedBox(height: 8),
              const Text('Company Invoice Generator Mobile App', textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
              const SizedBox(height: 10),
              const Text('Create, manage, and share professional invoices with ease.', textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
              const SizedBox(height: 32),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/create-invoice'),
                child: Container(
                  width: double.infinity, height: 54,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 6))],
                  ),
                  child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.add_rounded, color: Colors.white, size: 22),
                    SizedBox(width: 10),
                    Text('Create Invoice', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ]),
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('QUICK ACCESS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? AppColors.textSecondary : const Color(0xFF6B7280), letterSpacing: 1.5)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _QuickBtn(label: 'Dashboard', icon: Icons.dashboard_outlined, onTap: () => Navigator.pushNamed(context, '/dashboard'), cardBg: cardBg, border: border)),
                const SizedBox(width: 10),
                Expanded(child: _QuickBtn(label: 'Clients', icon: Icons.people_outline_rounded, onTap: () => Navigator.pushNamed(context, '/clients'), cardBg: cardBg, border: border)),
                const SizedBox(width: 10),
                Expanded(child: _QuickBtn(label: 'Invoices', icon: Icons.receipt_long_outlined, onTap: () => Navigator.pushNamed(context, '/invoices'), cardBg: cardBg, border: border)),
              ]),
              const SizedBox(height: 28),
              Text('FEATURES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? AppColors.textSecondary : const Color(0xFF6B7280), letterSpacing: 1.5)),
              const SizedBox(height: 12),
              _FeatureCard(icon: Icons.speed_rounded, color: AppColors.accent, title: 'Fast & Easy', subtitle: 'Generate professional invoices in seconds', cardBg: cardBg, border: border),
              const SizedBox(height: 10),
              _FeatureCard(icon: Icons.picture_as_pdf_rounded, color: AppColors.danger, title: 'PDF Export', subtitle: 'Download and share invoices as PDF', cardBg: cardBg, border: border),
              const SizedBox(height: 10),
              _FeatureCard(icon: Icons.people_alt_rounded, color: AppColors.success, title: 'Client Management', subtitle: 'Manage all your clients in one place', cardBg: cardBg, border: border),
              const SizedBox(height: 10),
              _FeatureCard(icon: Icons.bar_chart_rounded, color: AppColors.warning, title: 'Analytics', subtitle: 'Track revenue, pending and overdue amounts', cardBg: cardBg, border: border),
              const SizedBox(height: 24),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon; final Color color; final String title, subtitle; final Color cardBg, border;
  const _FeatureCard({required this.icon, required this.color, required this.title, required this.subtitle, required this.cardBg, required this.border});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: border)),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 20)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : const Color(0xFF1A1A2E))),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ])),
        Icon(Icons.chevron_right_rounded, color: color.withOpacity(0.5), size: 18),
      ]),
    );
  }
}

class _QuickBtn extends StatelessWidget {
  final String label; final IconData icon; final VoidCallback onTap; final Color cardBg, border;
  const _QuickBtn({required this.label, required this.icon, required this.onTap, required this.cardBg, required this.border});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: border)),
        child: Column(children: [
          Icon(icon, color: AppColors.accent, size: 22),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF1A1A2E))),
        ]),
      ),
    );
  }
}

// ── Shared profile avatar for AppBar ─────────────────────────────────────────
class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar();

  void _show(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? '';
    final initial = email.isNotEmpty ? email[0].toUpperCase() : 'U';
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 56, height: 56,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.accent, AppColors.accentLight]),
              shape: BoxShape.circle,
            ),
            child: Center(child: Text(initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22))),
          ),
          const SizedBox(height: 12),
          Text(email, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          const Text('Signed in', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 8),
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            tileColor: AppColors.danger.withOpacity(0.08),
            leading: const Icon(Icons.logout_rounded, color: AppColors.danger),
            title: const Text('Logout', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600)),
            onTap: () async {
              Navigator.pop(context);
              await AuthService().logout();
              if (context.mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
            },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? '';
    final initial = email.isNotEmpty ? email[0].toUpperCase() : 'U';
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: () => _show(context),
        child: CircleAvatar(
          radius: 17,
          backgroundColor: AppColors.accent.withOpacity(0.15),
          child: Text(initial, style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 13)),
        ),
      ),
    );
  }
}
