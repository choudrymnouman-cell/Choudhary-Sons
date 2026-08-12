import 'package:flutter/material.dart';

void main() {
  runApp(const ChoudharySonsApp());
}

class ChoudharySonsApp extends StatelessWidget {
  const ChoudharySonsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Choudhary & Sons',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final modules = <({IconData icon, String title, String subtitle})>[
      (icon: Icons.engineering_outlined, title: 'Projects', subtitle: 'Sites, progress & contracts'),
      (icon: Icons.groups_outlined, title: 'Employees', subtitle: 'Profiles, teams & documents'),
      (icon: Icons.fact_check_outlined, title: 'Attendance', subtitle: 'Check-in, shifts & overtime'),
      (icon: Icons.payments_outlined, title: 'Payroll', subtitle: 'Salary, advances & deductions'),
      (icon: Icons.inventory_2_outlined, title: 'Materials', subtitle: 'Stock, suppliers & purchases'),
      (icon: Icons.account_balance_wallet_outlined, title: 'Finance', subtitle: 'Expenses, billing & profit'),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choudhary & Sons'),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none)),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Company Dashboard', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Manage civil projects, workforce and business operations.', style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 24),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: modules.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.08,
              ),
              itemBuilder: (context, index) {
                final module = modules[index];
                return Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {},
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(module.icon, size: 30),
                          const Spacer(),
                          Text(module.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(module.subtitle, style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
