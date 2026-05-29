import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/invoice.dart';
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
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        title: Text('Dashboard', style: TextStyle(color: onBg, fontWeight: FontWeight.bold, fontSize: 20)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
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
                    color: const Color(0xFFF5C99A),
                    icon: Icons.receipt_long,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => InvoiceListScreen(initialFilter: InvoiceStatus.unpaid))),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _SummaryCard(
                    title: 'Overdue',
                    value: '$sym${_fmtShort(overdue)}',
                    sub: '$ovdCount overdue',
                    color: const Color(0xFFF4919B),
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
                    color: const Color(0xFFC4B5F4),
                    icon: Icons.calendar_month,
                    onTap: () => Navigator.pushNamed(context, '/invoices'),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _SummaryCard(
                    title: 'Total Paid',
                    value: '$sym${_fmtShort(totalRevenue)}',
                    sub: '$paidCount paid',
                    color: const Color(0xFF00D4B8),
                    icon: Icons.check_circle_outline,
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
        borderRadius: BorderRadius.circular(22),
        color: const Color(0xFF00BFA5), // flat solid teal — no gradient
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                // Spark logo + app name branding
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/spark_logo.png',
                      width: 30,
                      height: 30,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: const Text(
                        'Sparks Invoice',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Revenue label
                const Text('TOTAL REVENUE',
                    style: TextStyle(color: Colors.white70, fontSize: 9, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                // Animated amount
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
                        color: Colors.white.withOpacity(0.15),
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
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.96),
      onTapUp: (_) { setState(() => _scale = 1.0); widget.onTap(); },
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale, duration: const Duration(milliseconds: 120),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              // Circular icon container
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  shape: BoxShape.circle,
                ),
                child: Icon(widget.icon, color: Colors.white, size: 28),
              ),
              Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white.withOpacity(0.5)),
            ]),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(widget.value,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
                  maxLines: 1),
            ),
            const SizedBox(height: 3),
            Text(widget.title, style: const TextStyle(fontSize: 12, color: Color(0xFF333333), fontWeight: FontWeight.w600)),
            Text(widget.sub,   style: TextStyle(fontSize: 10, color: const Color(0xFF1A1A1A).withOpacity(0.6), fontWeight: FontWeight.w600)),
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
        color: isDark ? AppColors.darkCard : AppColors.darkCard,
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
class _ChartCard extends StatefulWidget {
  final List<FlSpot> spots;
  final bool showMonthly;
  final Color cardBg, divColor, subColor, primary;
  const _ChartCard({required this.spots, required this.showMonthly, required this.cardBg, required this.divColor, required this.subColor, required this.primary});

  @override
  State<_ChartCard> createState() => _ChartCardState();
}

class _ChartCardState extends State<_ChartCard> {
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    // Short delay gives the widget time to mount before animating in
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _isLoaded = true);
    });
  }

  @override
  void didUpdateWidget(_ChartCard old) {
    super.didUpdateWidget(old);
    // Re-trigger animation when period toggle changes
    if (old.showMonthly != widget.showMonthly) {
      setState(() => _isLoaded = false);
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) setState(() => _isLoaded = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final days    = widget.showMonthly ? 30 : 7;
    final maxY    = widget.spots.map((s) => s.y).fold(0.0, (a, b) => a > b ? a : b);
    final safeMax = maxY < 1 ? 10.0 : maxY * 1.3;

    // Animate from flat-zero line → real data
    final animatedSpots = _isLoaded
        ? widget.spots
        : List.generate(widget.spots.length, (i) => FlSpot(widget.spots[i].x, 0));

    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: widget.cardBg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      child: LineChart(
        LineChartData(
          minX: 0, maxX: (days - 1).toDouble(),
          minY: 0, maxY: safeMax,
          lineBarsData: [LineChartBarData(
            spots: animatedSpots,
            isCurved: true,
            gradient: LinearGradient(colors: [widget.primary, AppColors.success]),
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [widget.primary.withOpacity(0.2), AppColors.success.withOpacity(0.03)],
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
              ),
            ),
          )],
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true,
              interval: widget.showMonthly ? 5 : 1,
              getTitlesWidget: (v, _) {
                final day = DateTime.now().subtract(Duration(days: days - 1 - v.toInt()));
                final label = widget.showMonthly ? DateFormat('d').format(day) : DateFormat('E').format(day).substring(0, 1);
                return Padding(padding: const EdgeInsets.only(top: 6),
                    child: Text(label, style: TextStyle(fontSize: 9, color: widget.subColor, fontWeight: FontWeight.bold)));
              },
            )),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(show: true, drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(color: widget.divColor, strokeWidth: 0.5)),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => widget.primary,
              getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
                'Rs.${s.y.toStringAsFixed(0)}',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
              )).toList(),
            ),
          ),
        ),
        // Smooth 1000ms ease-out animation between data states
        duration: const Duration(milliseconds: 1000),
        curve: Curves.easeOutCubic,
      ),
    );
  }
}

// ── 5. Pie chart card ─────────────────────────────────────────────────────────
class _PieCard extends StatefulWidget {
  final int paid, unpaid, overdue;
  final Color cardBg, divColor;
  const _PieCard({required this.paid, required this.unpaid, required this.overdue, required this.cardBg, required this.divColor});

  @override
  State<_PieCard> createState() => _PieCardState();
}

class _PieCardState extends State<_PieCard> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final total = widget.paid + widget.unpaid + widget.overdue;

    // Status-based colors matching dashboard cards
    const cPaid    = Color(0xFF00D4B8); // Teal  — Paid
    const cUnpaid  = Color(0xFFF4919B); // Pink  — Unpaid/Pending
    const cOverdue = Color(0xFFF5C99A); // Peach — Overdue

    if (total == 0) {
      return Container(
        height: 90,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: widget.cardBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 6))],
        ),
        child: Center(child: Text('No invoice data yet', style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color))),
      );
    }

    // Build base sections list (index-stable for touch tracking)
    final baseSections = <({double value, Color color, String label, int count})>[
      if (widget.paid > 0)    (value: widget.paid.toDouble(),    color: cPaid,    label: 'Paid',    count: widget.paid),
      if (widget.unpaid > 0)  (value: widget.unpaid.toDouble(),  color: cUnpaid,  label: 'Unpaid',  count: widget.unpaid),
      if (widget.overdue > 0) (value: widget.overdue.toDouble(), color: cOverdue, label: 'Overdue', count: widget.overdue),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: widget.cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        // Pie chart — animates from 0 → real values on mount
        SizedBox(
          width: 120, height: 120,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 1000),
              curve: Curves.easeOutCubic,
              builder: (context, progress, _) {
                return PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 28,
                    pieTouchData: PieTouchData(
                      touchCallback: (event, response) {
                        setState(() {
                          _touchedIndex = (event.isInterestedForInteractions &&
                              response?.touchedSection != null)
                              ? response!.touchedSection!.touchedSectionIndex
                              : -1;
                        });
                      },
                    ),
                    sections: baseSections.asMap().entries.map((e) {
                      final i       = e.key;
                      final s       = e.value;
                      final touched = i == _touchedIndex;
                      return PieChartSectionData(
                        value: s.value * progress, // animate from 0
                        color: s.color,
                        title: '',
                        radius: touched ? 52 : 45, // pop on touch
                      );
                    }).toList(),
                  ),
                  // fl_chart's own swap animation handles legend/data changes
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Legend
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: baseSections.map((s) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _PieLegend(color: s.color, label: s.label, count: s.count),
          )).toList(),
        )),
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
