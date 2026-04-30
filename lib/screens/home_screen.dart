import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_drawer.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cardBg = AppColors.darkCard;
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: AppColors.heroGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.flash_on_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          const Text('Sparks Invoice', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: -0.5)),
        ]),
        actions: [_ProfileAvatar()],
      ),
      drawer: const AppDrawer(currentRoute: '/home'),
      body: SingleChildScrollView(
        child: Column(children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(32, 56, 32, 64),
            decoration: BoxDecoration(
              color: AppColors.darkBg,
              image: DecorationImage(
                image: const AssetImage('assets/glow.png'),
                fit: BoxFit.cover,
                opacity: 0.1,
                onError: (_, __) => {},
              ),
            ),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: AppColors.heroGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: primary.withOpacity(0.3), 
                      blurRadius: 30, 
                      spreadRadius: 5,
                    )
                  ],
                ),
                child: const Icon(Icons.flash_on_rounded, size: 56, color: Colors.white),
              ),
              const SizedBox(height: 32),
              const Text('Sparks Invoice', textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1.0)),
              const SizedBox(height: 12),
              const Text('Premium Invoicing for Professionals', textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              const Text('Create, manage, and share professional invoices with ease.', textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
              const SizedBox(height: 48),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/create-invoice'),
                child: Container(
                  width: double.infinity, height: 60,
                  decoration: BoxDecoration(
                    gradient: AppColors.heroGradient,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [BoxShadow(color: primary.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))],
                  ),
                  child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.add_rounded, color: Colors.white, size: 24),
                    SizedBox(width: 12),
                    Text('Create New Invoice', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ]),
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('QUICK ACCESS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted, letterSpacing: 2.0)),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: _QuickBtn(label: 'Dashboard', icon: Icons.grid_view_rounded, onTap: () => Navigator.pushNamed(context, '/dashboard'), cardBg: cardBg)),
                const SizedBox(width: 12),
                Expanded(child: _QuickBtn(label: 'Clients', icon: Icons.people_alt_rounded, onTap: () => Navigator.pushNamed(context, '/clients'), cardBg: cardBg)),
                const SizedBox(width: 12),
                Expanded(child: _QuickBtn(label: 'Invoices', icon: Icons.receipt_long_rounded, onTap: () => Navigator.pushNamed(context, '/invoices'), cardBg: cardBg)),
              ]),
              const SizedBox(height: 32),
              const Text('FEATURES', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted, letterSpacing: 2.0)),
              const SizedBox(height: 16),
              _FeatureCard(icon: Icons.speed_rounded, color: AppColors.primary, title: 'Fast & Easy', subtitle: 'Generate professional invoices in seconds', cardBg: cardBg),
              const SizedBox(height: 12),
              _FeatureCard(icon: Icons.picture_as_pdf_rounded, color: AppColors.danger, title: 'PDF Export', subtitle: 'Download and share invoices as PDF', cardBg: cardBg),
              const SizedBox(height: 12),
              _FeatureCard(icon: Icons.people_alt_rounded, color: AppColors.success, title: 'Client Management', subtitle: 'Manage all your clients in one place', cardBg: cardBg),
            ]),
          ),
        ]),
      ),
    );
  }
}
              const SizedBox(height: 24),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon; final Color color; final String title, subtitle; final Color cardBg;
  const _FeatureCard({required this.icon, required this.color, required this.title, required this.subtitle, required this.cardBg});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg, 
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10), 
          decoration: BoxDecoration(
            color: color.withOpacity(0.1), 
            borderRadius: BorderRadius.circular(12)
          ), 
          child: Icon(icon, color: color, size: 22)
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ])),
        Icon(Icons.chevron_right_rounded, color: color.withOpacity(0.3), size: 20),
      ]),
    );
  }
}

class _QuickBtn extends StatelessWidget {
  final String label; final IconData icon; final VoidCallback onTap; final Color cardBg;
  const _QuickBtn({required this.label, required this.icon, required this.onTap, required this.cardBg});
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: cardBg, 
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(children: [
          Icon(icon, color: primary, size: 24),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
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
      backgroundColor: AppColors.darkSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 64, height: 64,
            decoration: const BoxDecoration(
              gradient: AppColors.heroGradient,
              shape: BoxShape.circle,
            ),
            child: Center(child: Text(initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24))),
          ),
          const SizedBox(height: 16),
          Text(email, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
          const SizedBox(height: 4),
          const Text('Signed in', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 24),
          const Divider(color: Colors.white10),
          const SizedBox(height: 12),
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
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: () => _show(context),
        child: CircleAvatar(
          radius: 17,
          backgroundColor: primary.withOpacity(0.1),
          child: Text(initial, style: TextStyle(color: primary, fontWeight: FontWeight.bold, fontSize: 13)),
        ),
      ),
    );
  }
}
