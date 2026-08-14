import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'operations_create_forms.dart';
import 'project_financial_screen.dart';

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
  int suppliers = 0, materials = 0, lowStock = 0, purchaseOrders = 0, expenses = 0, invoices = 0;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        _api.suppliers(widget.session.token), _api.materials(widget.session.token), _api.lowStockMaterials(widget.session.token),
        _api.purchaseOrders(widget.session.token), _api.expenses(widget.session.token), _api.invoices(widget.session.token),
      ]);
      if (!mounted) return;
      setState(() { suppliers = results[0].length; materials = results[1].length; lowStock = results[2].length; purchaseOrders = results[3].length; expenses = results[4].length; invoices = results[5].length; });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _open(String type) async {
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => OperationsCreateScreen(session: widget.session, type: type)));
    if (changed == true) _load();
  }

  void _openFinancials() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProjectFinancialScreen(session: widget.session)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Commercial Control Center'), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))]),
      body: _loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Procurement & Finance', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('Track suppliers, material stock, purchasing, project costs and billing.'),
            if (_error != null) ...[const SizedBox(height: 12), Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))],
            const SizedBox(height: 20),
            GridView.count(
              shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.25,
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
            _ActionTile(icon: Icons.storefront_outlined, title: 'Add Supplier', subtitle: 'Register a supplier or vendor', onTap: () => _open('Supplier')),
            _ActionTile(icon: Icons.inventory_2_outlined, title: 'Add Material', subtitle: 'Create stock item and reorder level', onTap: () => _open('Material')),
            _ActionTile(icon: Icons.shopping_cart_checkout_outlined, title: 'Create Purchase Order', subtitle: 'Create supplier purchase order', onTap: () => _open('Purchase Order')),
            _ActionTile(icon: Icons.payments_outlined, title: 'Record Project Expense', subtitle: 'Labour, material, fuel and site expense', onTap: () => _open('Expense')),
            _ActionTile(icon: Icons.request_quote_outlined, title: 'Create Client Invoice', subtitle: 'Billing and receivables', onTap: () => _open('Invoice')),
            const _ActionTile(icon: Icons.calculate_outlined, title: 'BOQ Management', subtitle: 'Quantities, unit rates, progress and project value'),
            _ActionTile(icon: Icons.trending_up_outlined, title: 'Project Financial Control', subtitle: 'Contract value, cost, billing, collections and estimated profit', onTap: _openFinancials),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.icon, required this.label, required this.value});
  final IconData icon; final String label; final int value;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon), const Spacer(), Text('$value', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)), Text(label)])));
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.title, required this.subtitle, this.onTap});
  final IconData icon; final String title; final String subtitle; final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Card(child: ListTile(leading: Icon(icon), title: Text(title), subtitle: Text(subtitle), trailing: const Icon(Icons.chevron_right), onTap: onTap));
}
