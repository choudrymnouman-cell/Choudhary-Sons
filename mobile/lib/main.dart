import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/applicant_dashboard.dart';
import 'screens/commercial_dashboard.dart';
import 'screens/documents_screen.dart';
import 'screens/employee_portal_screens.dart';
import 'screens/field_operations_screen.dart';
import 'screens/management_lists.dart';
import 'services/api_service.dart';
import 'services/applicant_portal_service.dart';

const brandGreen = Color(0xFF0B5A3C);
const brandGreenDark = Color(0xFF073D2A);
const brandGreenSoft = Color(0xFFEAF4EF);
const brandGold = Color(0xFFC6A458);
const brandInk = Color(0xFF17211C);
const appSurface = Color(0xFFF5F8F6);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://lvvltukzpqtkmpcdsoxq.supabase.co'),
    anonKey: const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY', defaultValue: 'sb_publishable_7FZo2WyCepTAWlqPCkdoRg_QpBlpXdC'),
  );
  runApp(const ChoudharySonsApp());
}

ThemeData _appTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: brandGreen, primary: brandGreen, secondary: brandGold, surface: Colors.white);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: appSurface,
    appBarTheme: const AppBarTheme(backgroundColor: Colors.white, foregroundColor: brandInk, elevation: 0),
    cardTheme: CardThemeData(color: Colors.white, elevation: 0, margin: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: brandGreen.withValues(alpha: .10)))),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(minimumSize: const Size(0, 52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))),
    outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: brandGreen.withValues(alpha: .16))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: brandGreen, width: 1.5)),
    ),
    listTileTheme: const ListTileThemeData(contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 6), minTileHeight: 64, iconColor: brandGreen),
  );
}

class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 76});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    padding: EdgeInsets.all(size * .08),
    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white, border: Border.all(color: brandGreen, width: size * .035), boxShadow: [BoxShadow(color: brandGreen.withValues(alpha: .14), blurRadius: 18, offset: const Offset(0, 7))]),
    child: Container(
      decoration: const BoxDecoration(shape: BoxShape.circle, color: brandGreen),
      child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text('C&S', style: TextStyle(color: Colors.white, fontSize: size * .27, fontWeight: FontWeight.w900)), Text('KOT ADDU', style: TextStyle(color: Colors.white70, fontSize: size * .08, fontWeight: FontWeight.w800))])),
    ),
  );
}

class ChoudharySonsApp extends StatelessWidget {
  const ChoudharySonsApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(debugShowCheckedModeBanner: false, title: 'Choudhary & Sons', theme: _appTheme(), home: const LoginScreen());
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  final api = ApiService();
  final applicant = ApplicantPortalService();
  bool applicantMode = false;
  bool loading = false;
  String? error;

  @override
  void dispose() { email.dispose(); password.dispose(); super.dispose(); }

  Future<void> login() async {
    if (email.text.trim().isEmpty || password.text.isEmpty) { setState(() => error = 'Enter your email and password.'); return; }
    setState(() { loading = true; error = null; });
    try {
      final session = await api.login(email.text, password.text);
      if (!mounted) return;
      if (applicantMode) {
        await applicant.ensureApplicantRole();
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ApplicantDashboard(session: AuthSession(token: session.token, userId: session.userId, fullName: session.fullName, email: session.email, role: 'applicant'))));
      } else {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => session.isManagement ? ManagementDashboard(session: session) : EmployeeDashboard(session: session)));
      }
    } catch (e) { if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', '')); }
    finally { if (mounted) setState(() => loading = false); }
  }

  Future<void> openSignup() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ApplicantSignupScreen()));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFF9FCFA), Color(0xFFE8F2ED)])),
      child: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 460), child: Card(child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 30, 28, 28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Align(alignment: Alignment.center, child: BrandLogo(size: 104)),
          const SizedBox(height: 18),
          const Text('Choudhary & Sons', textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
          const Text('Civil Contractors & Suppliers', textAlign: TextAlign.center, style: TextStyle(color: brandGreen, fontWeight: FontWeight.w700)),
          const SizedBox(height: 22),
          SegmentedButton<bool>(segments: const [ButtonSegment(value: false, icon: Icon(Icons.business_center_outlined), label: Text('Staff')), ButtonSegment(value: true, icon: Icon(Icons.person_search_outlined), label: Text('Applicant'))], selected: {applicantMode}, onSelectionChanged: (v) => setState(() { applicantMode = v.first; error = null; })),
          const SizedBox(height: 18),
          TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email address', prefixIcon: Icon(Icons.mail_outline))),
          const SizedBox(height: 12),
          TextField(controller: password, obscureText: true, onSubmitted: (_) => login(), decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline))),
          if (error != null) ...[const SizedBox(height: 12), Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))],
          const SizedBox(height: 18),
          FilledButton.icon(onPressed: loading ? null : login, icon: const Icon(Icons.login), label: Text(loading ? 'Signing in...' : applicantMode ? 'Applicant Sign In' : 'Staff Sign In')),
          if (applicantMode) ...[const SizedBox(height: 10), OutlinedButton.icon(onPressed: openSignup, icon: const Icon(Icons.person_add_alt_1), label: const Text('Create Applicant Account'))],
        ]),
      ))))),
    ),
  );
}

class ApplicantSignupScreen extends StatefulWidget {
  const ApplicantSignupScreen({super.key});
  @override
  State<ApplicantSignupScreen> createState() => _ApplicantSignupScreenState();
}

class _ApplicantSignupScreenState extends State<ApplicantSignupScreen> {
  final fullName = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final service = ApplicantPortalService();
  bool loading = false;
  String? message;

  @override
  void dispose() { fullName.dispose(); phone.dispose(); email.dispose(); password.dispose(); super.dispose(); }

  Future<void> signup() async {
    if (fullName.text.trim().isEmpty || email.text.trim().isEmpty || password.text.length < 8) { setState(() => message = 'Enter name, email and a password of at least 8 characters.'); return; }
    setState(() { loading = true; message = null; });
    try {
      await service.signUp(email: email.text, password: password.text, fullName: fullName.text, phone: phone.text);
      if (mounted) setState(() => message = 'Account created. If email confirmation is enabled, confirm your email and then sign in from Applicant mode.');
    } catch (e) { if (mounted) setState(() => message = e.toString()); }
    finally { if (mounted) setState(() => loading = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Create Applicant Account')),
    body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(18), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: Card(child: Padding(padding: const EdgeInsets.all(22), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Join Choudhary & Sons Careers', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
      const SizedBox(height: 6),
      const Text('Create your account, complete your CNIC/profile details, then apply to HR-announced jobs.'),
      const SizedBox(height: 18),
      TextField(controller: fullName, decoration: const InputDecoration(labelText: 'Full name')),
      const SizedBox(height: 12),
      TextField(controller: phone, decoration: const InputDecoration(labelText: 'WhatsApp / phone')),
      const SizedBox(height: 12),
      TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
      const SizedBox(height: 12),
      TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
      if (message != null) ...[const SizedBox(height: 12), Text(message!)],
      const SizedBox(height: 18),
      FilledButton.icon(onPressed: loading ? null : signup, icon: const Icon(Icons.person_add_alt_1), label: Text(loading ? 'Creating...' : 'Create Account')),
    ]))))),
  );
}

class ManagementDashboard extends StatefulWidget {
  const ManagementDashboard({super.key, required this.session});
  final AuthSession session;
  @override
  State<ManagementDashboard> createState() => _ManagementDashboardState();
}

class _ManagementDashboardState extends State<ManagementDashboard> {
  final api = ApiService();
  Map<String, dynamic> kpis = {};
  bool loading = true;

  final modules = const <({IconData icon, String title, String subtitle})>[
    (icon: Icons.groups_outlined, title: 'Employees', subtitle: 'Staff, roles & records'),
    (icon: Icons.engineering_outlined, title: 'Projects', subtitle: 'Contracts, sites & progress'),
    (icon: Icons.description_outlined, title: 'Contracts', subtitle: 'Contract records & documents'),
    (icon: Icons.fact_check_outlined, title: 'Attendance', subtitle: 'Daily attendance & overtime'),
    (icon: Icons.payments_outlined, title: 'Payroll', subtitle: 'Salary, advances & deductions'),
    (icon: Icons.event_available_outlined, title: 'Leave', subtitle: 'Approve staff leave'),
    (icon: Icons.folder_copy_outlined, title: 'Documents', subtitle: 'CNICs, invoices & files'),
    (icon: Icons.work_outline, title: 'Recruitment', subtitle: 'Jobs, applicants & interviews'),
    (icon: Icons.shopping_cart_outlined, title: 'Procurement', subtitle: 'Suppliers & purchase orders'),
    (icon: Icons.inventory_2_outlined, title: 'Inventory', subtitle: 'Materials & site stock'),
    (icon: Icons.account_balance_wallet_outlined, title: 'Finance', subtitle: 'Expenses, invoices & profit'),
    (icon: Icons.precision_manufacturing_outlined, title: 'Assets', subtitle: 'Machinery & vehicles'),
    (icon: Icons.health_and_safety_outlined, title: 'Safety', subtitle: 'Incidents & inspections'),
  ];

  @override
  void initState() { super.initState(); load(); }
  Future<void> load() async { try { kpis = await api.dashboardKpis(widget.session.token); } finally { if (mounted) setState(() => loading = false); } }

  void openModule(String title) {
    if (title == 'Documents') Navigator.of(context).push(MaterialPageRoute(builder: (_) => DocumentsScreen(session: widget.session)));
    else if (const {'Procurement','Inventory','Finance'}.contains(title)) Navigator.of(context).push(MaterialPageRoute(builder: (_) => CommercialDashboard(session: widget.session)));
    else if (const {'Assets','Safety'}.contains(title)) Navigator.of(context).push(MaterialPageRoute(builder: (_) => FieldOperationsScreen(session: widget.session)));
    else Navigator.of(context).push(MaterialPageRoute(builder: (_) => ManagementListScreen(session: widget.session, type: title)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: LayoutBuilder(builder: (context, constraints) {
      final desktop = constraints.maxWidth >= 920;
      final content = _AdminContent(session: widget.session, modules: modules, kpis: kpis, loading: loading, openModule: openModule);
      if (!desktop) return Scaffold(appBar: AppBar(title: const Row(children: [BrandLogo(size: 38), SizedBox(width: 8), Text('Choudhary & Sons')]), actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh)), IconButton(onPressed: signOut, icon: const Icon(Icons.logout))]), body: content);
      return Row(children: [SizedBox(width: 255, child: _AdminSidebar(session: widget.session, modules: modules, openModule: openModule, signOut: signOut)), Expanded(child: content)]);
    }),
  );

  Future<void> signOut() async { await api.signOut(); if (!mounted) return; Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false); }
}

class _AdminSidebar extends StatelessWidget {
  const _AdminSidebar({required this.session, required this.modules, required this.openModule, required this.signOut});
  final AuthSession session;
  final List<({IconData icon, String title, String subtitle})> modules;
  final void Function(String) openModule;
  final VoidCallback signOut;
  @override
  Widget build(BuildContext context) => Container(
    color: brandGreenDark,
    child: SafeArea(child: Column(children: [
      const Padding(padding: EdgeInsets.all(18), child: Column(children: [BrandLogo(size: 72), SizedBox(height: 10), Text('Choudhary & Sons', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)), Text('Civil Contractors & Suppliers', style: TextStyle(color: Colors.white70, fontSize: 12))])),
      Expanded(child: ListView(padding: const EdgeInsets.symmetric(horizontal: 10), children: [
        _SideItem(icon: Icons.dashboard, label: 'Dashboard', selected: true, onTap: () {}),
        const Padding(padding: EdgeInsets.fromLTRB(12, 16, 12, 7), child: Text('MANAGEMENT', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w700))),
        ...modules.map((m) => _SideItem(icon: m.icon, label: m.title, onTap: () => openModule(m.title))),
      ])),
      Padding(padding: const EdgeInsets.all(12), child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withValues(alpha: .08), borderRadius: BorderRadius.circular(14)), child: Row(children: [CircleAvatar(backgroundColor: Colors.white, child: Text(session.fullName.isEmpty ? 'A' : session.fullName.substring(0,1), style: const TextStyle(color: brandGreen, fontWeight: FontWeight.bold))), const SizedBox(width: 9), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(session.fullName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)), Text(session.role.replaceAll('_',' '), style: const TextStyle(color: Colors.white60, fontSize: 11))])), IconButton(onPressed: signOut, icon: const Icon(Icons.logout, color: Colors.white70))]))),
    ])),
  );
}

class _SideItem extends StatelessWidget {
  const _SideItem({required this.icon, required this.label, required this.onTap, this.selected = false});
  final IconData icon; final String label; final VoidCallback onTap; final bool selected;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 4), child: ListTile(dense: true, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), tileColor: selected ? Colors.white.withValues(alpha: .10) : Colors.transparent, leading: Icon(icon, color: Colors.white, size: 20), title: Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)), onTap: onTap));
}

class _AdminContent extends StatelessWidget {
  const _AdminContent({required this.session, required this.modules, required this.kpis, required this.loading, required this.openModule});
  final AuthSession session;
  final List<({IconData icon, String title, String subtitle})> modules;
  final Map<String, dynamic> kpis;
  final bool loading;
  final void Function(String) openModule;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Welcome back, ${session.fullName}', style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900)), const SizedBox(height: 3), const Text("Here's what's happening with your company today.")])), const BrandLogo(size: 54)]),
      const SizedBox(height: 20),
      LayoutBuilder(builder: (context, c) { final count = c.maxWidth > 1000 ? 4 : c.maxWidth > 580 ? 2 : 2; return GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: count, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: c.maxWidth > 1000 ? 2.2 : 1.5, children: [
        _Kpi(icon: Icons.groups, label: 'Total Employees', value: loading ? '...' : '${kpis['employees'] ?? 0}', tone: const Color(0xFFEAF8EF)),
        _Kpi(icon: Icons.work, label: 'Active Projects', value: loading ? '...' : '${kpis['active_projects'] ?? 0}', tone: const Color(0xFFEAF3FF)),
        _Kpi(icon: Icons.event_available, label: 'Pending Leave', value: loading ? '...' : '${kpis['pending_leave'] ?? 0}', tone: const Color(0xFFFFF7E8)),
        _Kpi(icon: Icons.health_and_safety, label: 'Safety Alerts', value: loading ? '...' : '${kpis['open_safety_incidents'] ?? 0}', tone: const Color(0xFFFFEEF0)),
      ]); }),
      const SizedBox(height: 20),
      const Text('Quick Actions & Operations', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
      const SizedBox(height: 10),
      LayoutBuilder(builder: (context, c) { final count = c.maxWidth > 1050 ? 5 : c.maxWidth > 700 ? 3 : 2; return GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: modules.length, gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: count, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: c.maxWidth > 1050 ? 1.45 : 1.15), itemBuilder: (_, i) { final m = modules[i]; return Card(child: InkWell(borderRadius: BorderRadius.circular(18), onTap: () => openModule(m.title), child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: 42, height: 42, decoration: BoxDecoration(color: brandGreenSoft, borderRadius: BorderRadius.circular(12)), child: Icon(m.icon, color: brandGreen)), const Spacer(), Text(m.title, style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 3), Text(m.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Colors.black54))])))); }); }),
    ],
  );
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.icon, required this.label, required this.value, required this.tone});
  final IconData icon; final String label; final String value; final Color tone;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: tone, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.black.withValues(alpha: .05))), child: Row(children: [Container(width: 48, height: 48, decoration: BoxDecoration(color: Colors.white70, borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: brandGreen)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 12)), Text(value, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900))]))]));
}

class EmployeeDashboard extends StatefulWidget {
  const EmployeeDashboard({super.key, required this.session});
  final AuthSession session;
  @override
  State<EmployeeDashboard> createState() => _EmployeeDashboardState();
}

class _EmployeeDashboardState extends State<EmployeeDashboard> {
  final api = ApiService();
  bool busy = false;

  Future<void> attendanceAction(bool checkIn) async {
    setState(() => busy = true);
    try { checkIn ? await api.checkIn(widget.session.token) : await api.checkOut(widget.session.token); if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(checkIn ? 'Checked in successfully' : 'Checked out successfully'))); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
    finally { if (mounted) setState(() => busy = false); }
  }

  @override
  Widget build(BuildContext context) {
    final menu = const <({IconData icon, String title, String subtitle})>[
      (icon: Icons.person_outline, title: 'My Profile', subtitle: 'Personal and employment details'),
      (icon: Icons.calendar_month_outlined, title: 'Attendance History', subtitle: 'Check-in and check-out records'),
      (icon: Icons.payments_outlined, title: 'Salary & Payslips', subtitle: 'Salary, deductions and advances'),
      (icon: Icons.event_busy_outlined, title: 'Leave Requests', subtitle: 'Apply and track leave'),
      (icon: Icons.work_outline, title: 'Open Jobs', subtitle: 'Internal and public vacancies'),
      (icon: Icons.campaign_outlined, title: 'Notices', subtitle: 'Company announcements'),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Employee Portal'), actions: [IconButton(onPressed: () async { await api.signOut(); if (!mounted) return; Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false); }, icon: const Icon(Icons.logout))]),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: brandGreenDark, borderRadius: BorderRadius.circular(20)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Hello, ${widget.session.fullName}', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)), const SizedBox(height: 4), const Text('Manage your workday and employment information.', style: TextStyle(color: Colors.white70))])),
        const SizedBox(height: 14),
        Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [const Text("Today's Attendance", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(height: 12), FilledButton.icon(onPressed: busy ? null : () => attendanceAction(true), icon: const Icon(Icons.login), label: const Text('Check In')), const SizedBox(height: 8), OutlinedButton.icon(onPressed: busy ? null : () => attendanceAction(false), icon: const Icon(Icons.logout), label: const Text('Check Out'))]))),
        const SizedBox(height: 12),
        ...menu.map((item) => Padding(padding: const EdgeInsets.only(bottom: 9), child: Card(child: ListTile(leading: Icon(item.icon), title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(item.subtitle), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => EmployeeDataScreen(session: widget.session, type: item.title))))))),
      ]),
    );
  }
}
