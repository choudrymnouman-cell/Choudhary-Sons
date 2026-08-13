import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/commercial_dashboard.dart';
import 'screens/documents_screen.dart';
import 'screens/employee_portal_screens.dart';
import 'screens/field_operations_screen.dart';
import 'screens/management_lists.dart';
import 'services/api_service.dart';

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
    appBarTheme: const AppBarTheme(backgroundColor: Colors.white, foregroundColor: brandInk, elevation: 0, centerTitle: false),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: brandGreen.withValues(alpha: .10))),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(minimumSize: const Size(0, 52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: brandGreen.withValues(alpha: .16))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: brandGreen, width: 1.5)),
    ),
    listTileTheme: const ListTileThemeData(contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 6), minTileHeight: 68, iconColor: brandGreen),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(backgroundColor: brandGreen, foregroundColor: Colors.white),
  );
}

class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 92});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * .08),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: brandGreen, width: size * .035),
        boxShadow: [BoxShadow(color: brandGreen.withValues(alpha: .16), blurRadius: 22, offset: const Offset(0, 8))],
      ),
      child: Container(
        decoration: const BoxDecoration(shape: BoxShape.circle, color: brandGreen),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('C&S', style: TextStyle(color: Colors.white, fontSize: size * .27, fontWeight: FontWeight.w900, letterSpacing: -1)),
              SizedBox(height: size * .015),
              Text('KOT ADDU', style: TextStyle(color: Colors.white.withValues(alpha: .9), fontSize: size * .085, fontWeight: FontWeight.w800, letterSpacing: .6)),
            ],
          ),
        ),
      ),
    );
  }
}

class ChoudharySonsApp extends StatelessWidget {
  const ChoudharySonsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner: false, title: 'Choudhary & Sons', theme: _appTheme(), home: const LoginScreen());
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _api = ApiService();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      setState(() => _error = 'Enter your email and password.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final session = await _api.login(_emailController.text, _passwordController.text);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => session.isManagement ? ManagementDashboard(session: session) : EmployeeDashboard(session: session)));
    } catch (error) {
      if (mounted) setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFF8FBF9), Color(0xFFE8F2ED)]),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 30, 28, 28),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      const Align(alignment: Alignment.center, child: BrandLogo(size: 104)),
                      const SizedBox(height: 20),
                      const Text('Choudhary & Sons', textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: brandInk, letterSpacing: -.5)),
                      const SizedBox(height: 6),
                      const Text('Civil Contractors & Suppliers', textAlign: TextAlign.center, style: TextStyle(color: brandGreen, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('Company Management Portal', textAlign: TextAlign.center, style: TextStyle(color: brandInk.withValues(alpha: .58))),
                      const SizedBox(height: 28),
                      TextField(controller: _emailController, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email address', prefixIcon: Icon(Icons.mail_outline))),
                      const SizedBox(height: 14),
                      TextField(controller: _passwordController, obscureText: true, onSubmitted: (_) => _login(), decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline))),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Theme.of(context).colorScheme.errorContainer, borderRadius: BorderRadius.circular(12)), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer))),
                      ],
                      const SizedBox(height: 20),
                      FilledButton.icon(onPressed: _loading ? null : _login, icon: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.login), label: Text(_loading ? 'Signing in...' : 'Sign In')),
                      const SizedBox(height: 14),
                      const Text('Secure access for management and employees', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Color(0xFF6D7971))),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ManagementDashboard extends StatelessWidget {
  const ManagementDashboard({super.key, required this.session});
  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    final modules = <({IconData icon, String title, String subtitle})>[
      (icon: Icons.engineering_outlined, title: 'Projects', subtitle: 'Contracts, sites & progress'),
      (icon: Icons.groups_outlined, title: 'Employees', subtitle: 'Staff, roles & records'),
      (icon: Icons.folder_copy_outlined, title: 'Documents', subtitle: 'Contracts, CNICs, invoices & files'),
      (icon: Icons.fact_check_outlined, title: 'Attendance', subtitle: 'Daily attendance & overtime'),
      (icon: Icons.event_available_outlined, title: 'Leave', subtitle: 'Review and approve leave requests'),
      (icon: Icons.payments_outlined, title: 'Payroll', subtitle: 'Salary, advances & deductions'),
      (icon: Icons.shopping_cart_outlined, title: 'Procurement', subtitle: 'Suppliers, POs & materials'),
      (icon: Icons.inventory_2_outlined, title: 'Inventory', subtitle: 'Site stock & consumption'),
      (icon: Icons.account_balance_wallet_outlined, title: 'Finance', subtitle: 'Expenses, billing & profit'),
      (icon: Icons.work_outline, title: 'Recruitment', subtitle: 'Jobs & applications'),
      (icon: Icons.precision_manufacturing_outlined, title: 'Assets', subtitle: 'Machinery & vehicles'),
      (icon: Icons.health_and_safety_outlined, title: 'Safety', subtitle: 'Incidents & inspections'),
    ];

    void openModule(String title) {
      if (title == 'Documents') {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => DocumentsScreen(session: session)));
      } else if (const {'Procurement', 'Inventory', 'Finance'}.contains(title)) {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => CommercialDashboard(session: session)));
      } else if (const {'Assets', 'Safety'}.contains(title)) {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => FieldOperationsScreen(session: session)));
      } else {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => ManagementListScreen(session: session, type: title)));
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Row(mainAxisSize: MainAxisSize.min, children: [BrandLogo(size: 38), SizedBox(width: 10), Text('Choudhary & Sons')]),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none)),
          IconButton(tooltip: 'Sign out', onPressed: () async { await ApiService().signOut(); if (!context.mounted) return; Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false); }, icon: const Icon(Icons.logout)),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final columns = width >= 1180 ? 4 : width >= 780 ? 3 : width >= 520 ? 2 : 2;
          final ratio = width < 400 ? .93 : width < 700 ? 1.05 : 1.18;
          return ListView(
            padding: EdgeInsets.symmetric(horizontal: width > 1100 ? 48 : 18, vertical: 22),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(gradient: const LinearGradient(colors: [brandGreenDark, brandGreen]), borderRadius: BorderRadius.circular(20)),
                child: Row(children: [
                  const BrandLogo(size: 62),
                  const SizedBox(width: 16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Welcome, ${session.fullName}', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 5),
                    Text('Management access • ${session.role.replaceAll('_', ' ')}', style: TextStyle(color: Colors.white.withValues(alpha: .82))),
                  ])),
                ]),
              ),
              const SizedBox(height: 22),
              const Text('Business Operations', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: brandInk)),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: modules.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: ratio),
                itemBuilder: (context, index) {
                  final module = modules[index];
                  return Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => openModule(module.title),
                      child: Padding(
                        padding: const EdgeInsets.all(15),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Container(width: 42, height: 42, decoration: BoxDecoration(color: brandGreenSoft, borderRadius: BorderRadius.circular(12)), child: Icon(module.icon, color: brandGreen, size: 24)),
                          const Spacer(),
                          Text(module.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: brandInk)),
                          const SizedBox(height: 3),
                          Text(module.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, height: 1.25, color: brandInk.withValues(alpha: .58))),
                        ]),
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class EmployeeDashboard extends StatefulWidget {
  const EmployeeDashboard({super.key, required this.session});
  final AuthSession session;
  @override
  State<EmployeeDashboard> createState() => _EmployeeDashboardState();
}

class _EmployeeDashboardState extends State<EmployeeDashboard> {
  final _api = ApiService();
  bool _busy = false;

  Future<void> _attendanceAction(bool checkIn) async {
    setState(() => _busy = true);
    try {
      checkIn ? await _api.checkIn(widget.session.token) : await _api.checkOut(widget.session.token);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(checkIn ? 'Checked in successfully' : 'Checked out successfully')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))));
    } finally { if (mounted) setState(() => _busy = false); }
  }

  @override
  Widget build(BuildContext context) {
    final menu = <({IconData icon, String title, String subtitle})>[
      (icon: Icons.person_outline, title: 'My Profile', subtitle: 'Personal and employment details'),
      (icon: Icons.calendar_month_outlined, title: 'Attendance History', subtitle: 'View check-in and check-out records'),
      (icon: Icons.payments_outlined, title: 'Salary & Payslips', subtitle: 'Salary, deductions and advances'),
      (icon: Icons.event_busy_outlined, title: 'Leave Requests', subtitle: 'Apply and track leave'),
      (icon: Icons.work_outline, title: 'Open Jobs', subtitle: 'View internal and public vacancies'),
      (icon: Icons.campaign_outlined, title: 'Notices', subtitle: 'Company announcements and updates'),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Row(mainAxisSize: MainAxisSize.min, children: [BrandLogo(size: 36), SizedBox(width: 10), Text('Employee Portal')]),
        actions: [IconButton(tooltip: 'Sign out', onPressed: () async { await _api.signOut(); if (!mounted) return; Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false); }, icon: const Icon(Icons.logout))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: brandGreenDark, borderRadius: BorderRadius.circular(20)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Hello, ${widget.session.fullName}', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text('Manage your workday and employment information.', style: TextStyle(color: Colors.white.withValues(alpha: .78))),
            ]),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Row(children: [Icon(Icons.fingerprint, color: brandGreen), SizedBox(width: 10), Text('Today\'s Attendance', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))]),
                const SizedBox(height: 16),
                FilledButton.icon(onPressed: _busy ? null : () => _attendanceAction(true), icon: const Icon(Icons.login), label: const Text('Check In')),
                const SizedBox(height: 10),
                OutlinedButton.icon(onPressed: _busy ? null : () => _attendanceAction(false), icon: const Icon(Icons.logout), label: const Text('Check Out')),
              ]),
            ),
          ),
          const SizedBox(height: 14),
          ...menu.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(child: ListTile(leading: Container(width: 42, height: 42, decoration: BoxDecoration(color: brandGreenSoft, borderRadius: BorderRadius.circular(12)), child: Icon(item.icon, color: brandGreen)), title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(item.subtitle), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => EmployeeDataScreen(session: widget.session, type: item.title))))),
          )),
        ],
      ),
    );
  }
}
