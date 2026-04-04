import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/invoice.dart';
import '../providers/theme_provider.dart';
import '../services/auth_service.dart';
import '../services/client_service.dart';
import '../services/invoice_service.dart';
import '../theme/app_colors.dart';
import 'invoice_details_screen.dart';
import 'invoice_list_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  final _invoiceSvc = InvoiceService();
  final _clientSvc  = ClientService();
  bool _showMonthly = false;

  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() { _fadeCtrl.dispose(); super.dispose(); }

  // ── Helpers ────────────────────────────────────────────────────────────────
  String _fmt(double v) => NumberFormat('#,##0.00').format(v);
  String _fmtShort(double v) => NumberFormat('#,##0.##').format(v);

  List<Invoice> _filterByPeriod(List<Invoice> all) {
    final cutoff = DateTime.now().subtract(Duration(days: _showMonthly ? 30 : 7));
    return all.where((i) => i.date.toDate().isAfter(cutoff)).toList();
  }

  List<FlSpot> _buildSpots(List<Invoice> invoices) {
    final days = _showMonthly ? 30 : 7;
    final now  = DateTime.now();
    final Map<int, double> byDay = {};
    for (final inv in invoices.where((i) => i.effectiveStatus == InvoiceStatus.paid)) {
      final diff = now.difference(inv.date.toDate()).inDays;
      if (diff >= 0 && diff < days) {
        final x = days - 1 - diff;
        byDay[x] = (byDay[x] ?? 0) + inv.total;
      }
    }
    if (byDay.isEmpty) return [FlSpot(0, 0), FlSpot((days - 1).toDouble(), 0)];
    return List.generate(days, (i) => FlSpot(i.toDouble(), byDay[i] ?? 0));
  }

  // ── Dialogs ────────────────────────────────────────────────────────────────
  void _showNotifications() => showDialog(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Notifications'),
      content: const Text('No notifications at this time.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
    ),
  );

  void _showProfileMenu() {
    final user    = FirebaseAuth.instance.currentUser;
    final primary = Theme.of(context).colorScheme.primary;
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircleAvatar(radius: 28, backgroundColor: primary.withOpacity(0.15),
            child: Text((user?.email?.isNotEmpty == true) ? user!.email![0].toUpperCase() : 'U',
              style: TextStyle(color: primary, fontWeight: FontWeight.bold, fontSize: 22))),
          const SizedBox(height: 12),
          Text(user?.email ?? '', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(height: 4),
          Text('Signed in', style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 12)),
          const SizedBox(height: 20),
          Divider(color: Theme.of(context).dividerColor),
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
    final primary  = Theme.of(context).colorScheme.primary;
    final onBg     = Theme.of(context).colorScheme.onSurface;
    final subColor = Theme.of(context).textTheme.bodySmall?.color ?? AppColors.textSecondary;
    final cardBg   = Theme.of(context).cardColor;
    final divColor = Theme.of(context).dividerColor;
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final themeProv = context.watch<ThemeProvider>();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        title: Text('Dashboard', style: TextStyle(color: onBg, fontWeight: FontWeight.bold, fontSize: 20)),
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined, color: subColor),
            onPressed: () => themeProv.toggle(),
          ),
          IconButton(icon: Icon(Icons.notifications_none_rounded, color: subColor), onPressed: _showNotifications),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: _showProfileMenu,
              child: CircleAvatar(
                radius: 17,
                backgroundColor: primary.withOpacity(0.15),
                child: Text(
                  (FirebaseAuth.instance.currentUser?.email?.isNotEmpty == true)
                      ? FirebaseAuth.instance.currentUser!.email![0].toUpperCase() : 'U',
                  style: TextStyle(color: primary, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<Invoice>>(
        stream: _invoiceSvc.getInvoices(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final all      = snap.data ?? [];
          final filtered = _filterByPeriod(all);
          final spots    = _buildSpots(filtered);

          final totalRevenue = all.where((i) => i.effectiveStatus == InvoiceStatus.paid).fold(0.0, (s, i) => s + i.total);
          final outstanding  = all.where((i) => i.effectiveStatus == InvoiceStatus.unpaid || i.effectiveStatus == InvoiceStatus.partiallyPaid).fold(0.0, (s, i) => s + i.total);
          final overdue      = all.where((i) => i.effectiveStatus == InvoiceStatus.overdue).fold(0.0, (s, i) => s + i.total);
          final outCount     = all.where((i) => i.effectiveStatus == InvoiceStatus.unpaid || i.effectiveStatus == InvoiceStatus.partiallyPaid).length;
          final ovdCount     = all.where((i) => i.effectiveStatus == InvoiceStatus.overdue).length;
          final now          = DateTime.now();
          final monthCount   = all.where((i) { final d = i.date.toDate(); return d.month == now.month && d.year == now.year; }).length;
          final paidCount    = all.where((i) => i.effectiveStatus == InvoiceStatus.paid).length;
          final sym          = all.isNotEmpty && all.first.currency == 'USD' ? r'$' : 'Rs.';
          final recent       = List<Invoice>.from(all)..sort((a, b) => b.date.compareTo(a.date));

          return FadeTransition(
            opacity: _fadeAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

                // ── 1. HERO CARD ─────────────────────────────────────────
                _HeaderCard(
                  totalRevenue: totalRevenue,
                  sym: sym,
                  fmt: _fmt,
                  onNewInvoice: () => Navigator.pushNamed(context, '/create-invoice'),
                  onNewClient:  () => Navigator.pushNamed(context, '/add-client'),
                ),
                const SizedBox(height: 16),

                // ── 2. SUMMARY CARDS ─────────────────────────────────────
                Row(children: [
                  Expanded(child: _SummaryCard(
                    title: 'Outstanding',
                    value: '$sym${_fmtShort(outstanding)}',
                    sub: '$outCount pending',
                    color: AppColors.warning,
                    icon: Icons.pending_actions_rounded,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => InvoiceListScreen(initialFilter: InvoiceStatus.unpaid))),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _SummaryCard(
                    title: 'Overdue',
                    value: '$sym${_fmtShort(overdue)}',
                    sub: '$ovdCount overdue',
                    color: AppColors.danger,
                    icon: Icons.warning_amber_rounded,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => InvoiceListScreen(initialFilter: InvoiceStatus.overdue))),
                  )),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _SummaryCard(
                    title: 'This Month',
                    value: '$monthCount',
                    sub: 'invoices',
                    color: AppColors.success,
                    icon: Icons.description_outlined,
                    onTap: () => Navigator.pushNamed(context, '/invoices'),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _SummaryCard(
                    title: 'Total Paid',
                    value: '$sym${_fmtShort(totalRevenue)}',
                    sub: '$paidCount paid',
                    color: primary,
                    icon: Icons.check_circle_outline_rounded,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => InvoiceListScreen(initialFilter: InvoiceStatus.paid))),
                  )),
                ]),
                const SizedBox(height: 24),

                // ── 3. LINE CHART ─────────────────────────────────────────
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Revenue Trend', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: onBg)),
                  _ChartToggle(showMonthly: _showMonthly, onToggle: (v) => setState(() => _showMonthly = v)),
                ]),
                const SizedBox(height: 12),
                _ChartCard(
                  spots: spots,
                  showMonthly: _showMonthly,
                  cardBg: cardBg,
                  divColor: divColor,
                  subColor: subColor,
                  primary: primary,
                ),
                const SizedBox(height: 20),

                // ── 4. PIE CHART ──────────────────────────────────────────
                Text('Invoice Status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: onBg)),
                const SizedBox(height: 12),
                _PieCard(
                  paid: paidCount,
                  unpaid: outCount,
                  overdue: ovdCount,
                  cardBg: cardBg,
                  divColor: divColor,
                ),
                const SizedBox(height: 24),

                // ── 5. RECENT INVOICES ────────────────────────────────────
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Recent Invoices', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: onBg)),
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/invoices'),
                    child: Text('View All', style: TextStyle(color: primary, fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ]),
                const SizedBox(height: 12),

                if (all.isEmpty)
                  _EmptyState()
                else
                  ...recent.take(5).map((inv) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _InvoiceCard(
                      invoice: inv,
                      sym: sym,
                      clientSvc: _clientSvc,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => InvoiceDetailsScreen(invoice: inv))),
                    ),
                  )),
              ]),
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// WIDGETS
// ═══════════════════════════════════════════════════════════════════════════

// ── 1. Header card ────────────────────────────────────────────────────────────
class _HeaderCard extends StatelessWidget {
  final double totalRevenue;
  final String sym;
  final String Function(double) fmt;
  final VoidCallback onNewInvoice, onNewClient;
  const _HeaderCard({required this.totalRevenue, required this.sym, required this.fmt, required this.onNewInvoice, required this.onNewClient});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F172A),
            Color(0xFF312E81),
            Color(0xFF0D9488),
            Color(0xFF10B981),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0.0, 0.35, 0.70, 1.0],
        ),
        boxShadow: [BoxShadow(color: const Color(0xFF312E81).withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      // Full Column — no Row, no overflow risk
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        // Icon
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 30),
        ),
        const SizedBox(height: 12),
        // App name
        const Text('Sparks Invoice',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.3)),
        const SizedBox(height: 14),
        // Revenue label
        Text('TOTAL REVENUE',
            style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 9, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        // Animated amount — full width, ellipsis prevents overflow
        TweenAnimationBuilder<double>(
          key: ValueKey(totalRevenue),
          tween: Tween(begin: 0, end: totalRevenue),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOut,
          builder: (_, val, __) => Text(
            '$sym${NumberFormat('#,##0.00').format(val)}',
            style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -1),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 20),
        // Buttons row
        Row(children: [
          Expanded(child: GestureDetector(
            onTap: onNewInvoice,
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 8, offset: const Offset(0, 3))],
              ),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.add_circle_outline_rounded, color: Color(0xFF0F172A), size: 18),
                SizedBox(width: 6),
                Text('New Invoice', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 13)),
              ]),
            ),
          )),
          const SizedBox(width: 12),
          Expanded(child: GestureDetector(
            onTap: onNewClient,
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.person_add_alt_1_rounded, color: Colors.white.withOpacity(0.9), size: 18),
                const SizedBox(width: 6),
                Text('New Client', style: TextStyle(color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.bold, fontSize: 13)),
              ]),
            ),
          )),
        ]),
      ]),
    );
  }
}

// ── 2. Summary card ───────────────────────────────────────────────────────────
class _SummaryCard extends StatefulWidget {
  final String title, value, sub;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;
  const _SummaryCard({required this.title, required this.value, required this.sub, required this.color, required this.icon, required this.onTap});
  @override
  State<_SummaryCard> createState() => _SummaryCardState();
}
class _SummaryCardState extends State<_SummaryCard> {
  double _scale = 1.0;
  @override
  Widget build(BuildContext context) {
    final cardBg   = Theme.of(context).cardColor;
    final onBg     = Theme.of(context).colorScheme.onSurface;
    final subColor = Theme.of(context).textTheme.bodySmall?.color ?? AppColors.textSecondary;
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.96),
      onTapUp: (_) { setState(() => _scale = 1.0); widget.onTap(); },
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale, duration: const Duration(milliseconds: 120),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: widget.color.withOpacity(0.2)),
            boxShadow: [BoxShadow(color: widget.color.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              // Circular icon
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color.withOpacity(0.12)),
                child: Icon(widget.icon, color: widget.color, size: 20),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 11, color: widget.color.withOpacity(0.4)),
            ]),
            const SizedBox(height: 12),
            Text(widget.value,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: onBg),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Text(widget.title, style: TextStyle(fontSize: 12, color: subColor, fontWeight: FontWeight.w600)),
            Text(widget.sub, style: TextStyle(fontSize: 10, color: widget.color, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}

// ── 3. Chart toggle ───────────────────────────────────────────────────────────
class _ChartToggle extends StatelessWidget {
  final bool showMonthly;
  final ValueChanged<bool> onToggle;
  const _ChartToggle({required this.showMonthly, required this.onToggle});
  @override
  Widget build(BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final primary  = Theme.of(context).colorScheme.primary;
    final subColor = Theme.of(context).textTheme.bodySmall?.color ?? AppColors.textSecondary;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _ToggleChip(label: 'Weekly',  active: !showMonthly, onTap: () => onToggle(false), primary: primary, sub: subColor),
        _ToggleChip(label: 'Monthly', active: showMonthly,  onTap: () => onToggle(true),  primary: primary, sub: subColor),
      ]),
    );
  }
}
class _ToggleChip extends StatelessWidget {
  final String label; final bool active; final VoidCallback onTap; final Color primary, sub;
  const _ToggleChip({required this.label, required this.active, required this.onTap, required this.primary, required this.sub});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(color: active ? primary : Colors.transparent, borderRadius: BorderRadius.circular(10)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: active ? Colors.white : sub)),
    ),
  );
}

// ── 4. Line chart card ────────────────────────────────────────────────────────
class _ChartCard extends StatelessWidget {
  final List<FlSpot> spots;
  final bool showMonthly;
  final Color cardBg, divColor, subColor, primary;
  const _ChartCard({required this.spots, required this.showMonthly, required this.cardBg, required this.divColor, required this.subColor, required this.primary});

  @override
  Widget build(BuildContext context) {
    final days   = showMonthly ? 30 : 7;
    final maxY   = spots.map((s) => s.y).fold(0.0, (a, b) => a > b ? a : b);
    final safeMax = maxY < 1 ? 10.0 : maxY * 1.3;

    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: divColor),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: LineChart(
        LineChartData(
          minX: 0, maxX: (days - 1).toDouble(),
          minY: 0, maxY: safeMax,
          lineBarsData: [LineChartBarData(
            spots: spots,
            isCurved: true,
            gradient: LinearGradient(colors: [primary, AppColors.success]),
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [primary.withOpacity(0.2), AppColors.success.withOpacity(0.03)],
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
              ),
            ),
          )],
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true,
              interval: showMonthly ? 5 : 1,
              getTitlesWidget: (v, _) {
                final day = DateTime.now().subtract(Duration(days: days - 1 - v.toInt()));
                final label = showMonthly ? DateFormat('d').format(day) : DateFormat('E').format(day).substring(0, 1);
                return Padding(padding: const EdgeInsets.only(top: 6),
                    child: Text(label, style: TextStyle(fontSize: 9, color: subColor, fontWeight: FontWeight.bold)));
              },
            )),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(show: true, drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(color: divColor, strokeWidth: 0.5)),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => primary,
              getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
                'Rs.${s.y.toStringAsFixed(0)}',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
              )).toList(),
            ),
          ),
        ),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOut,
      ),
    );
  }
}

// ── 5. Pie chart card ─────────────────────────────────────────────────────────
class _PieCard extends StatelessWidget {
  final int paid, unpaid, overdue;
  final Color cardBg, divColor;
  const _PieCard({required this.paid, required this.unpaid, required this.overdue, required this.cardBg, required this.divColor});

  @override
  Widget build(BuildContext context) {
    final total   = paid + unpaid + overdue;
    final primary = Theme.of(context).colorScheme.primary;

    // Theme-based colors — no hardcoded green/orange/red
    final cPaid    = primary;
    final cUnpaid  = primary.withOpacity(0.55);
    final cOverdue = primary.withOpacity(0.25);

    if (total == 0) {
      return Container(
        height: 90,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: divColor)),
        child: Center(child: Text('No invoice data yet', style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color))),
      );
    }

    final sections = [
      if (paid > 0)    PieChartSectionData(value: paid.toDouble(),    color: cPaid,    title: '', radius: 44),
      if (unpaid > 0)  PieChartSectionData(value: unpaid.toDouble(),  color: cUnpaid,  title: '', radius: 44),
      if (overdue > 0) PieChartSectionData(value: overdue.toDouble(), color: cOverdue, title: '', radius: 44),
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: divColor),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        // Strictly constrained — no overflow possible
        SizedBox(
          width: 120, height: 120,
          child: PieChart(
            PieChartData(sections: sections, sectionsSpace: 2, centerSpaceRadius: 30),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          _PieLegend(color: cPaid,    label: 'Paid',    count: paid),
          const SizedBox(height: 10),
          _PieLegend(color: cUnpaid,  label: 'Unpaid',  count: unpaid),
          const SizedBox(height: 10),
          _PieLegend(color: cOverdue, label: 'Overdue', count: overdue),
        ])),
      ]),
    );
  }
}
class _PieLegend extends StatelessWidget {
  final Color color; final String label; final int count;
  const _PieLegend({required this.color, required this.label, required this.count});
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 8),
    Expanded(child: Text('$label ($count)',
        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w500),
        overflow: TextOverflow.ellipsis)),
  ]);
}

// ── 6. Invoice card ───────────────────────────────────────────────────────────
class _InvoiceCard extends StatelessWidget {
  final Invoice invoice;
  final String sym;
  final ClientService clientSvc;
  final VoidCallback onTap;
  const _InvoiceCard({required this.invoice, required this.sym, required this.clientSvc, required this.onTap});

  Color _statusColor(InvoiceStatus s) {
    switch (s) {
      case InvoiceStatus.paid:          return AppColors.success;
      case InvoiceStatus.unpaid:        return AppColors.warning;
      case InvoiceStatus.overdue:       return AppColors.danger;
      case InvoiceStatus.partiallyPaid: return AppColors.info;
      default:                          return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status   = invoice.effectiveStatus;
    final c        = _statusColor(status);
    final cardBg   = Theme.of(context).cardColor;
    final onBg     = Theme.of(context).colorScheme.onSurface;
    final subColor = Theme.of(context).textTheme.bodySmall?.color ?? AppColors.textSecondary;
    final divColor = Theme.of(context).dividerColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: divColor),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.receipt_outlined, color: c, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(invoice.invoiceNumber,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: onBg),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            FutureBuilder(
              future: clientSvc.getClient(invoice.clientRef.id),
              builder: (_, snap) => Text(snap.data?.name ?? '—',
                  style: TextStyle(fontSize: 12, color: subColor),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ])),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('$sym${NumberFormat('#,##0.##').format(invoice.total)}',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: onBg)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
              child: Text(status.name.toUpperCase(),
                  style: TextStyle(color: c, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            ),
          ]),
        ]),
      ),
    );
  }
}

// ── 7. Empty state ────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(32),
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Theme.of(context).dividerColor),
    ),
    child: Column(children: [
      Icon(Icons.receipt_long_outlined, size: 56,
          color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.4)),
      const SizedBox(height: 14),
      Text('No invoices yet',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Theme.of(context).colorScheme.onSurface)),
      const SizedBox(height: 6),
      Text('Create your first invoice to get started',
          style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color),
          textAlign: TextAlign.center),
    ]),
  );
}
