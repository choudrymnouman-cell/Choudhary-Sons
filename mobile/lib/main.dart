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

ThemeData appTheme() => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(seedColor: brandGreen),
  scaffoldBackgroundColor: appSurface,
  cardTheme: CardThemeData(color: Colors.white, elevation: 0, margin: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: brandGreen.withValues(alpha: .10)))),
  filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(minimumSize: const Size(0, 52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))),
  outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))),
  inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: brandGreen.withValues(alpha: .15)))),
);

class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 72});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white, border: Border.all(color: brandGreen, width: 3)),
    padding: EdgeInsets.all(size * .08),
    child: Container(
      decoration: const BoxDecoration(shape: BoxShape.circle, color: brandGreen),
      alignment: Alignment.center,
      child: Column(mainAxisSize: MainAxisSize.min, children: [Text('C&S', style: TextStyle(color: Colors.white, fontSize: size * .26, fontWeight: FontWeight.w900)), Text('KOT ADDU', style: TextStyle(color: Colors.white70, fontSize: size * .08, fontWeight: FontWeight.bold))]),
    ),
  );
}

class ChoudharySonsApp extends StatelessWidget {
  const ChoudharySonsApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(debugShowCheckedModeBanner: false, title: 'Choudhary & Sons', theme: appTheme(), home: const LoginScreen());
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
  final applicantService = ApplicantPortalService();
  bool applicantMode = false;
  bool loading = false;
  String? error;

  @override
  void dispose() { email.dispose(); password.dispose(); super.dispose(); }

  Future<void> login() async {
    setState(() { loading = true; error = null; });
    try {
      final session = await api.login(email.text, password.text);
      if (!mounted) return;
      if (applicantMode) {
        await applicantService.ensureApplicantRole();
        if (!mounted) return;
        final applicantSession = AuthSession(token: session.token, userId: session.userId, fullName: session.fullName, email: session.email, role: 'applicant');
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ApplicantDashboard(session: applicantSession)));
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => session.isManagement ? ManagementDashboard(session: session) : EmployeeDashboard(session: session)));
      }
    } catch (e) { if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', '')); }
    finally { if (mounted) setState(() => loading = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFF9FCFA), Color(0xFFE8F2ED)])),
      alignment: Alignment.center,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 450),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(26),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Center(child: BrandLogo(size: 100)),
                const SizedBox(height: 16),
                const Text('Choudhary & Sons', textAlign: TextAlign.center, style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900)),
                const Text('Civil Contractors & Suppliers', textAlign: TextAlign.center, style: TextStyle(color: brandGreen, fontWeight: FontWeight.w700)),
                const SizedBox(height: 20),
                SegmentedButton<bool>(segments: const [ButtonSegment(value: false, label: Text('Staff')), ButtonSegment(value: true, label: Text('Applicant'))], selected: {applicantMode}, onSelectionChanged: (v) => setState(() => applicantMode = v.first)),
                const SizedBox(height: 16),
                TextField(controller: email, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined))),
                const SizedBox(height: 12),
                TextField(controller: password, obscureText: true, onSubmitted: (_) => login(), decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline))),
                if (error != null) ...[const SizedBox(height: 10), Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))],
                const SizedBox(height: 16),
                FilledButton.icon(onPressed: loading ? null : login, icon: const Icon(Icons.login), label: Text(loading ? 'Signing in...' : 'Sign In')),
                if (applicantMode) ...[const SizedBox(height: 10), OutlinedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ApplicantSignupScreen())), icon: const Icon(Icons.person_add_alt), label: const Text('Create Applicant Account'))],
              ]),
            ),
          ),
        ),
      ),
    ),
  );
}

class ApplicantSignupScreen extends StatefulWidget {
  const ApplicantSignupScreen({super.key});
  @override
  State<ApplicantSignupScreen> createState() => _ApplicantSignupScreenState();
}

class _ApplicantSignupScreenState extends State<ApplicantSignupScreen> {
  final name = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final service = ApplicantPortalService();
  bool loading = false;
  String? note;

  Future<void> signup() async {
    if (name.text.trim().isEmpty || email.text.trim().isEmpty || password.text.length < 8) { setState(() => note = 'Enter name, email and password of at least 8 characters.'); return; }
    setState(() { loading = true; note = null; });
    try {
      await service.signUp(email: email.text, password: password.text, fullName: name.text, phone: phone.text);
      if (mounted) setState(() => note = 'Account created. Confirm email if requested, then use Applicant Sign In.');
    } catch (e) { if (mounted) setState(() => note = e.toString()); }
    finally { if (mounted) setState(() => loading = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Applicant Sign Up')),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Card(child: Padding(padding: const EdgeInsets.all(22), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Create Career Profile', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Full name')),
            const SizedBox(height: 10),
            TextField(controller: phone, decoration: const InputDecoration(labelText: 'WhatsApp number')),
            const SizedBox(height: 10),
            TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
            const SizedBox(height: 10),
            TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
            if (note != null) ...[const SizedBox(height: 10), Text(note!)],
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: loading ? null : signup, icon: const Icon(Icons.person_add_alt), label: Text(loading ? 'Creating...' : 'Create Account')),
          ]))),
        ),
      ),
    ),
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
    (icon: Icons.payments_outlined, title: 'Payroll', subtitle: 'Salary & deductions'),
    (icon: Icons.event_available_outlined, title: 'Leave', subtitle: 'Review leave requests'),
    (icon: Icons.folder_copy_outlined, title: 'Documents', subtitle: 'CNICs, invoices & files'),
    (icon: Icons.work_outline, title: 'Recruitment', subtitle: 'Jobs & applications'),
    (icon: Icons.shopping_cart_outlined, title: 'Procurement', subtitle: 'Suppliers & POs'),
    (icon: Icons.inventory_2_outlined, title: 'Inventory', subtitle: 'Materials & stock'),
    (icon: Icons.account_balance_wallet_outlined, title: 'Finance', subtitle: 'Expenses & invoices'),
    (icon: Icons.precision_manufacturing_outlined, title: 'Assets', subtitle: 'Machinery & vehicles'),
    (icon: Icons.health_and_safety_outlined, title: 'Safety', subtitle: 'Incidents & inspections'),
  ];

  @override
  void initState() { super.initState(); load(); }
  Future<void> load() async { try { kpis = await api.dashboardKpis(widget.session.token); } finally { if (mounted) setState(() => loading = false); } }

  void open(String title) {
    if (title == 'Documents') Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentsScreen(session: widget.session)));
    else if (const {'Procurement','Inventory','Finance'}.contains(title)) Navigator.push(context, MaterialPageRoute(builder: (_) => CommercialDashboard(session: widget.session)));
    else if (const {'Assets','Safety'}.contains(title)) Navigator.push(context, MaterialPageRoute(builder: (_) => FieldOperationsScreen(session: widget.session)));
    else Navigator.push(context, MaterialPageRoute(builder: (_) => ManagementListScreen(session: widget.session, type: title)));
  }

  Future<void> signOut() async { await api.signOut(); if (!mounted) return; Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false); }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
    final desktop = c.maxWidth >= 920;
    final content = _DashboardContent(session: widget.session, kpis: kpis, loading: loading, modules: modules, onOpen: open);
    return Scaffold(
      appBar: desktop ? null : AppBar(title: const Text('Choudhary & Sons'), actions: [IconButton(onPressed: signOut, icon: const Icon(Icons.logout))]),
      body: desktop ? Row(children: [SizedBox(width: 250, child: _Sidebar(session: widget.session, modules: modules, onOpen: open, onLogout: signOut)), Expanded(child: content)]) : content,
    );
  });
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.session, required this.modules, required this.onOpen, required this.onLogout});
  final AuthSession session;
  final List<({IconData icon, String title, String subtitle})> modules;
  final void Function(String) onOpen;
  final VoidCallback onLogout;
  @override
  Widget build(BuildContext context) => Container(color: brandGreenDark, child: SafeArea(child: Column(children: [
    const Padding(padding: EdgeInsets.all(18), child: Column(children: [BrandLogo(size: 72), SizedBox(height: 8), Text('Choudhary & Sons', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)), Text('Civil Contractors & Suppliers', style: TextStyle(color: Colors.white70, fontSize: 11))])),
    Expanded(child: ListView(padding: const EdgeInsets.symmetric(horizontal: 8), children: [
      ListTile(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), tileColor: Colors.white10, leading: const Icon(Icons.dashboard, color: Colors.white), title: const Text('Dashboard', style: TextStyle(color: Colors.white))),
      ...modules.map((m) => ListTile(dense: true, leading: Icon(m.icon, color: Colors.white70, size: 20), title: Text(m.title, style: const TextStyle(color: Colors.white, fontSize: 13)), onTap: () => onOpen(m.title))),
    ])),
    Padding(padding: const EdgeInsets.all(10), child: ListTile(tileColor: Colors.white10, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), leading: const CircleAvatar(child: Icon(Icons.person)), title: Text(session.fullName, style: const TextStyle(color: Colors.white, fontSize: 13)), subtitle: Text(session.role, style: const TextStyle(color: Colors.white60, fontSize: 11)), trailing: IconButton(onPressed: onLogout, icon: const Icon(Icons.logout, color: Colors.white70)))),
  ])));
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.session, required this.kpis, required this.loading, required this.modules, required this.onOpen});
  final AuthSession session;
  final Map<String, dynamic> kpis;
  final bool loading;
  final List<({IconData icon, String title, String subtitle})> modules;
  final void Function(String) onOpen;
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(22), children: [
    Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Welcome back, ${session.fullName}', style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900)), const Text("Here's what's happening with your company today.")])), const BrandLogo(size: 52)]),
    const SizedBox(height: 18),
    LayoutBuilder(builder: (_, c) { final count = c.maxWidth > 950 ? 4 : 2; return GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: count, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: c.maxWidth > 950 ? 2.1 : 1.45, children: [
      _Kpi('Total Employees', loading ? '...' : '${kpis['employees'] ?? 0}', Icons.groups, const Color(0xFFEAF8EF)),
      _Kpi('Active Projects', loading ? '...' : '${kpis['active_projects'] ?? 0}', Icons.work, const Color(0xFFEAF3FF)),
      _Kpi('Pending Leave', loading ? '...' : '${kpis['pending_leave'] ?? 0}', Icons.event_available, const Color(0xFFFFF6E5)),
      _Kpi('Safety Alerts', loading ? '...' : '${kpis['open_safety_incidents'] ?? 0}', Icons.health_and_safety, const Color(0xFFFFEEF0)),
    ]); }),
    const SizedBox(height: 20),
    const Text('Quick Actions & Operations', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
    const SizedBox(height: 10),
    LayoutBuilder(builder: (_, c) { final count = c.maxWidth > 1000 ? 5 : c.maxWidth > 650 ? 3 : 2; return GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: modules.length, gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: count, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: c.maxWidth > 1000 ? 1.4 : 1.1), itemBuilder: (_, i) { final m = modules[i]; return Card(child: InkWell(onTap: () => onOpen(m.title), child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: 42, height: 42, decoration: BoxDecoration(color: brandGreenSoft, borderRadius: BorderRadius.circular(12)), child: Icon(m.icon, color: brandGreen)), const Spacer(), Text(m.title, style: const TextStyle(fontWeight: FontWeight.w800)), Text(m.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Colors.black54))])))); }); }),
  ]);
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.label, this.value, this.icon, this.color);
  final String label; final String value; final IconData icon; final Color color;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(18)), child: Row(children: [Icon(icon, color: brandGreen, size: 30), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 12)), Text(value, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900))]))]));
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
  Future<void> attend(bool checkIn) async { setState(() => busy = true); try { checkIn ? await api.checkIn(widget.session.token) : await api.checkOut(widget.session.token); } finally { if (mounted) setState(() => busy = false); } }
  @override
  Widget build(BuildContext context) {
    final menu = const [('My Profile', Icons.person_outline),('Attendance History', Icons.calendar_month_outlined),('Salary & Payslips', Icons.payments_outlined),('Leave Requests', Icons.event_busy_outlined),('Open Jobs', Icons.work_outline),('Notices', Icons.campaign_outlined)];
    return Scaffold(appBar: AppBar(title: const Text('Employee Portal'), actions: [IconButton(onPressed: () async { await api.signOut(); if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false); }, icon: const Icon(Icons.logout))]), body: ListView(padding: const EdgeInsets.all(18), children: [
      Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: brandGreenDark, borderRadius: BorderRadius.circular(18)), child: Text('Hello, ${widget.session.fullName}', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900))),
      const SizedBox(height: 12),
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: busy ? null : () => attend(true), icon: const Icon(Icons.login), label: const Text('Check In'))), const SizedBox(height: 8), SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: busy ? null : () => attend(false), icon: const Icon(Icons.logout), label: const Text('Check Out')))]))),
      const SizedBox(height: 12),
      ...menu.map((m) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Card(child: ListTile(leading: Icon(m.$2), title: Text(m.$1), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EmployeeDataScreen(session: widget.session, type: m.$1))))))),
    ]));
  }
}
