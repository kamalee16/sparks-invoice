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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF161B22) : Colors.white;
    final border = isDark ? const Color(0xFF21262D) : const Color(0xFFE2E8F0);
    final selected = isDark ? const Color(0xFF00C9A7) : AppColors.primary;
    final unselected = isDark ? const Color(0xFF8B949E) : AppColors.textSecondary;

    return Scaffold(
      body: IndexedStack(index: _idx, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: bg,
          border: Border(top: BorderSide(color: border, width: 1)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, -2))],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 60,
            child: Row(children: [
              _NavTab(icon: Icons.dashboard_rounded, label: 'Dashboard', active: _idx == 0, color: selected, inactive: unselected, onTap: () => setState(() => _idx = 0)),
              _NavTab(icon: Icons.receipt_long_rounded, label: 'Invoices', active: _idx == 1, color: selected, inactive: unselected, onTap: () => setState(() => _idx = 1)),
              _NavTab(icon: Icons.people_alt_rounded, label: 'Clients', active: _idx == 2, color: selected, inactive: unselected, onTap: () => setState(() => _idx = 2)),
              _NavTab(icon: Icons.settings_rounded, label: 'Settings', active: _idx == 3, color: selected, inactive: unselected, onTap: () => setState(() => _idx = 3)),
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
        Icon(icon, size: 22, color: active ? color : inactive),
        const SizedBox(height: 3),
        Text(label, style: TextStyle(fontSize: 10, color: active ? color : inactive, fontWeight: active ? FontWeight.bold : FontWeight.normal)),
      ]),
    ),
  );
}
