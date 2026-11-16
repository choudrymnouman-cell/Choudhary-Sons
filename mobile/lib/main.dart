import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/applicant_dashboard.dart';
import 'screens/commercial_dashboard.dart';
import 'screens/documents_screen.dart';
import 'screens/employee_portal_screens.dart';
import 'screens/field_operations_screen.dart';
import 'screens/management_lists.dart';
import 'screens/recruitment_pipeline_screen.dart';
import 'services/api_service.dart';
import 'services/applicant_portal_service.dart';

const brandGreen = Color(0xFF0B5A3C);
const brandGreenDark = Color(0xFF073D2A);
const brandGreenSoft = Color(0xFFEAF4EF);
const brandInk = Color(0xFF17211C);
const appSurface = Color(0xFFF5F8F6);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!selfHostedWeb) {
    await Supabase.initialize(
      url: const String.fromEnvironment(
        'SUPABASE_URL',
        defaultValue: 'https://lvvltukzpqtkmpcdsoxq.supabase.co',
      ),
      publishableKey: const String.fromEnvironment(
        'SUPABASE_PUBLISHABLE_KEY',
        defaultValue: 'sb_publishable_7FZo2WyCepTAWlqPCkdoRg_QpBlpXdC',
      ),
    );
  }
  runApp(const ChoudharySonsApp());
}

ThemeData appTheme() => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(seedColor: brandGreen),
  scaffoldBackgroundColor: appSurface,
  cardTheme: CardThemeData(
    color: Colors.white,
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(color: brandGreen.withValues(alpha: .10)),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(0, 52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(0, 52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: brandGreen.withValues(alpha: .15)),
    ),
  ),
);

class ChoudharySonsApp extends StatelessWidget {
  const ChoudharySonsApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Choudhary & Sons',
    debugShowCheckedModeBanner: false,
    theme: appTheme(),
    home: const AuthGate(),
  );
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final api = ApiService();
  AuthSession? session;
  bool loading = true;
  String? error;
  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final restored = await api.restoreSession();
      if (mounted) setState(() => session = restored);
    } catch (exception) {
      if (mounted) {
        setState(
          () => error = exception.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _signedIn(AuthSession signedIn) => setState(() => session = signedIn);

  Future<void> _logout() async {
    if (loading) return;
    setState(() => loading = true);
    try {
      await api.signOut();
      if (mounted) {
        setState(() {
          session = null;
          error = null;
        });
      }
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not sign out: $exception')),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(error!, textAlign: TextAlign.center),
                TextButton(onPressed: _restore, child: const Text('Retry')),
                TextButton(
                  onPressed: _logout,
                  child: const Text('Return to sign in'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (session == null) return LoginScreen(onSignedIn: _signedIn);
    return RoleHome(session: session!, onLogout: _logout);
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onSignedIn});
  final ValueChanged<AuthSession> onSignedIn;
  @override
  State<LoginScreen> createState() => _LoginState();
}

class _LoginState extends State<LoginScreen> {
  final api = ApiService();
  final email = TextEditingController(), password = TextEditingController();
  bool busy = false;
  String role = 'Applicant';
  String? error;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> login() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final s = await api.login(email.text.trim(), password.text);
      if (mounted) widget.onSignedIn(s);
    } catch (e) {
      if (mounted)
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.apartment, size: 54, color: brandGreen),
                  const SizedBox(height: 12),
                  Text(
                    'Choudhary & Sons',
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Text('Civil Services • Contractor • Supplier'),
                  const SizedBox(height: 22),
                  if (!selfHostedWeb) SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'Applicant',
                        label: Text('Applicant'),
                        icon: Icon(Icons.person_outline),
                      ),
                      ButtonSegment(
                        value: 'Staff',
                        label: Text('Staff'),
                        icon: Icon(Icons.badge_outlined),
                      ),
                    ],
                    selected: {role},
                    onSelectionChanged: (v) => setState(() => role = v.first),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: password,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: busy ? null : login,
                      child: busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Sign In'),
                    ),
                  ),
                  if (selfHostedWeb || role == 'Applicant') ...[
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ApplicantSignupScreen(),
                          ),
                        );
                      },
                      child: const Text('Create Applicant Account'),
                    ),
                  ],
                ],
              ),
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
  State<ApplicantSignupScreen> createState() => _ApplicantSignupState();
}

class _ApplicantSignupState extends State<ApplicantSignupScreen> {
  final service = ApplicantPortalService();
  final name = TextEditingController(),
      email = TextEditingController(),
      password = TextEditingController();
  bool busy = false;
  String? message;
  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> signup() async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await service.signUp(
        email: email.text.trim(),
        password: password.text,
        fullName: name.text.trim(),
      );
      if (!mounted) return;
      setState(
        () => message = selfHostedWeb
            ? 'Account created. Return to sign in.'
            : 'Account created. Check your email and confirm your address, then return and sign in as Applicant.',
      );
    } catch (e) {
      if (mounted) setState(() => message = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Applicant Signup')),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    'Join our talent network',
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Full name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: email,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: password,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                  ),
                  if (message != null) ...[
                    const SizedBox(height: 12),
                    Text(message!),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: busy ? null : signup,
                      child: const Text('Create Account'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class RoleHome extends StatelessWidget {
  const RoleHome({super.key, required this.session, required this.onLogout});
  final AuthSession session;
  final VoidCallback onLogout;
  @override
  Widget build(BuildContext context) {
    final role = session.role.toLowerCase();
    if (role == 'applicant') {
      return ApplicantDashboard(session: session, onLogout: onLogout);
    }
    if (role == 'employee')
      return EmployeePortalHome(session: session, onLogout: onLogout);
    return ManagementHome(session: session, onLogout: onLogout);
  }
}

class ManagementHome extends StatelessWidget {
  const ManagementHome({
    super.key,
    required this.session,
    required this.onLogout,
  });
  final AuthSession session;
  final VoidCallback onLogout;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Management Dashboard'),
      actions: [
        IconButton(onPressed: onLogout, icon: const Icon(Icons.logout)),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Text(
          'Welcome, ${session.fullName}',
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _HomeTile(
          Icons.business_center_outlined,
          'Commercial Control',
          'Suppliers, stock, BOQ, billing and project finance',
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CommercialDashboard(session: session),
            ),
          ),
        ),
        _HomeTile(
          Icons.engineering_outlined,
          'Field Operations',
          'Projects, site reports, assets and safety',
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FieldOperationsScreen(session: session),
            ),
          ),
        ),
        _HomeTile(
          Icons.people_outline,
          'Employees',
          'Employee records and workforce',
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ManagementListScreen(session: session, type: 'Employees'),
            ),
          ),
        ),
        for (final (icon, title, subtitle) in const [
          (
            Icons.fact_check_outlined,
            'Attendance',
            'Daily check-ins and check-outs',
          ),
          (Icons.payments_outlined, 'Payroll', 'Salary and deductions'),
          (
            Icons.event_available_outlined,
            'Leave',
            'Review staff leave requests',
          ),
        ])
          _HomeTile(
            icon,
            title,
            subtitle,
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    ManagementListScreen(session: session, type: title),
              ),
            ),
          ),
        _HomeTile(
          Icons.work_outline,
          'Recruitment',
          'Vacancies and applications',
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RecruitmentPipelineScreen(session: session),
            ),
          ),
        ),
        _HomeTile(
          Icons.folder_outlined,
          'Documents',
          'Company and project documents',
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DocumentsScreen(session: session),
            ),
          ),
        ),
      ],
    ),
  );
}

class _HomeTile extends StatelessWidget {
  const _HomeTile(this.icon, this.title, this.subtitle, this.tap);
  final IconData icon;
  final String title, subtitle;
  final VoidCallback tap;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: tap,
    ),
  );
}
