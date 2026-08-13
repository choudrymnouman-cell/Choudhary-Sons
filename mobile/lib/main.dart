import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/commercial_dashboard.dart';
import 'screens/documents_screen.dart';
import 'screens/employee_portal_screens.dart';
import 'screens/field_operations_screen.dart';
import 'screens/management_lists.dart';
import 'services/api_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: const String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://lvvltukzpqtkmpcdsoxq.supabase.co',
    ),
    anonKey: const String.fromEnvironment(
      'SUPABASE_PUBLISHABLE_KEY',
      defaultValue: 'sb_publishable_7FZo2WyCepTAWlqPCkdoRg_QpBlpXdC',
    ),
  );
  runApp(const ChoudharySonsApp());
}

class ChoudharySonsApp extends StatelessWidget {
  const ChoudharySonsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Choudhary & Sons',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const LoginScreen(),
    );
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const Icon(Icons.engineering, size: 54),
                    const SizedBox(height: 14),
                    Text('Choudhary & Sons', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text('Company Management Portal', textAlign: TextAlign.center),
                    const SizedBox(height: 28),
                    TextField(controller: _emailController, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
                    const SizedBox(height: 14),
                    TextField(controller: _passwordController, obscureText: true, onSubmitted: (_) => _login(), decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder())),
                    if (_error != null) ...[const SizedBox(height: 12), Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))],
                    const SizedBox(height: 20),
                    FilledButton.icon(onPressed: _loading ? null : _login, icon: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.login), label: Text(_loading ? 'Signing in...' : 'Sign In')),
                  ]),
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
        title: const Text('Choudhary & Sons'),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none)),
          IconButton(
            tooltip: 'Sign out',
            onPressed: () async {
              await ApiService().signOut();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Welcome, ${session.fullName}', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Management access • ${session.role.replaceAll('_', ' ')}'),
          const SizedBox(height: 22),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: modules.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.05),
            itemBuilder: (context, index) {
              final module = modules[index];
              return Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => openModule(module.title),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(module.icon, size: 30),
                      const Spacer(),
                      Text(module.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(module.subtitle, style: Theme.of(context).textTheme.bodySmall),
                    ]),
                  ),
                ),
              );
            },
          ),
        ],
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
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
        title: const Text('Employee Portal'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () async {
              await _api.signOut();
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Hello, ${widget.session.fullName}', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Manage your workday and employment information.'),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('Attendance', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 14),
                FilledButton.icon(onPressed: _busy ? null : () => _attendanceAction(true), icon: const Icon(Icons.login), label: const Text('Check In')),
                const SizedBox(height: 10),
                OutlinedButton.icon(onPressed: _busy ? null : () => _attendanceAction(false), icon: const Icon(Icons.logout), label: const Text('Check Out')),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          ...menu.map((item) => Card(
                child: ListTile(
                  leading: Icon(item.icon),
                  title: Text(item.title),
                  subtitle: Text(item.subtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => EmployeeDataScreen(session: widget.session, type: item.title))),
                ),
              )),
        ],
      ),
    );
  }
}
