import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import 'dashboard_screen.dart';
import 'invoice_list_screen.dart';
import 'client_list_screen.dart';
import 'settings_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _idx = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    InvoiceListScreen(),
    ClientListScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final unselected = AppColors.textMuted;
    final navBg = AppColors.darkSurface;

    return Scaffold(
      body: IndexedStack(index: _idx, children: _screens),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.darkBg,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2), 
              blurRadius: 20, 
              offset: const Offset(0, -5)
            )
          ],
        ),
        child: SafeArea(
          top: false,
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: navBg,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1), 
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Row(children: [
              _NavTab(icon: Icons.grid_view_rounded, label: 'Dashboard', active: _idx == 0, color: primary, inactive: unselected, onTap: () => setState(() => _idx = 0)),
              _NavTab(icon: Icons.receipt_long_rounded, label: 'Invoices', active: _idx == 1, color: primary, inactive: unselected, onTap: () => setState(() => _idx = 1)),
              _NavTab(icon: Icons.people_alt_rounded, label: 'Clients', active: _idx == 2, color: primary, inactive: unselected, onTap: () => setState(() => _idx = 2)),
              _NavTab(icon: Icons.settings_rounded, label: 'Settings', active: _idx == 3, color: primary, inactive: unselected, onTap: () => setState(() => _idx = 3)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color color, inactive;
  final VoidCallback onTap;
  const _NavTab({required this.icon, required this.label, required this.active, required this.color, required this.inactive, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: active ? color.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 24, color: active ? color : inactive),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 10, color: active ? color : inactive, fontWeight: active ? FontWeight.bold : FontWeight.w500)),
      ]),
    ),
  );
}
