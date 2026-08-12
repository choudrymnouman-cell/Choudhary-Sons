import 'package:flutter/material.dart';

import '../services/api_service.dart';

class CommercialDashboard extends StatefulWidget {
  const CommercialDashboard({super.key, required this.session});

  final AuthSession session;

  @override
  State<CommercialDashboard> createState() => _CommercialDashboardState();
}

class _CommercialDashboardState extends State<CommercialDashboard> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  int suppliers = 0;
  int materials = 0;
  int lowStock = 0;
  int purchaseOrders = 0;
  int expenses = 0;
  int invoices = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _api.suppliers(widget.session.token),
        _api.materials(widget.session.token),
        _api.lowStockMaterials(widget.session.token),
        _api.purchaseOrders(widget.session.token),
        _api.expenses(widget.session.token),
        _api.invoices(widget.session.token),
      ]);
      if (!mounted) return;
      setState(() {
        suppliers = results[0].length;
        materials = results[1].length;
        lowStock = results[2].length;
        purchaseOrders = results[3].length;
        expenses = results[4].length;
        invoices = results[5].length;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Commercial Control Center'),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text('Procurement & Finance', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  const Text('Track suppliers, material stock, purchasing, project costs and billing.'),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: 20),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.25,
                    children: [
                      _MetricCard(icon: Icons.storefront_outlined, label: 'Suppliers', value: suppliers),
                      _MetricCard(icon: Icons.inventory_2_outlined, label: 'Materials', value: materials),
                      _MetricCard(icon: Icons.warning_amber_outlined, label: 'Low Stock', value: lowStock),
                      _MetricCard(icon: Icons.receipt_long_outlined, label: 'Purchase Orders', value: purchaseOrders),
                      _MetricCard(icon: Icons.money_off_outlined, label: 'Expenses', value: expenses),
                      _MetricCard(icon: Icons.request_quote_outlined, label: 'Invoices', value: invoices),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const _ActionTile(icon: Icons.calculate_outlined, title: 'BOQ Management', subtitle: 'Quantities, unit rates, progress and project value'),
                  const _ActionTile(icon: Icons.shopping_cart_checkout_outlined, title: 'Purchase Orders', subtitle: 'Create and track supplier orders'),
                  const _ActionTile(icon: Icons.warehouse_outlined, title: 'Inventory', subtitle: 'Stock levels, site stores and reorder alerts'),
                  const _ActionTile(icon: Icons.payments_outlined, title: 'Project Expenses', subtitle: 'Record labour, material, fuel and site expenses'),
                  const _ActionTile(icon: Icons.request_quote_outlined, title: 'Client Invoices', subtitle: 'Billing, receivables and payment status'),
                  const _ActionTile(icon: Icons.trending_up_outlined, title: 'Project Profitability', subtitle: 'Contract value vs cost, billing and cash received'),
                ],
              ),
            ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const Spacer(),
            Text('$value', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {},
      ),
    );
  }
}
