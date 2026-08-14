import 'package:flutter/material.dart';

import '../services/api_service.dart';

class ProjectFinancialScreen extends StatefulWidget {
  const ProjectFinancialScreen({super.key, required this.session});
  final AuthSession session;

  @override
  State<ProjectFinancialScreen> createState() => _ProjectFinancialScreenState();
}

class _ProjectFinancialScreenState extends State<ProjectFinancialScreen> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  List<dynamic> _projects = [];
  Map<int, Map<String, dynamic>> _profitability = {};

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final projects = await _api.projects(widget.session.token);
      final data = <int, Map<String, dynamic>>{};
      for (final item in projects) {
        final p = Map<String, dynamic>.from(item as Map);
        final id = p['id'];
        if (id is int) {
          try { data[id] = await _api.projectProfitability(widget.session.token, id); } catch (_) {}
        }
      }
      if (!mounted) return;
      setState(() { _projects = projects; _profitability = data; });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally { if (mounted) setState(() => _loading = false); }
  }

  double _num(dynamic value) => value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
  String _money(dynamic value) => 'PKR ${_num(value).toStringAsFixed(0)}';

  dynamic _pick(Map<String, dynamic> row, List<String> keys, [dynamic fallback = 0]) {
    for (final key in keys) { if (row[key] != null) return row[key]; }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Project Financial Control'), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))]),
      body: _loading ? const Center(child: CircularProgressIndicator()) : _error != null ? Center(child: Text(_error!)) : RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Text('Project Profitability', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('Contract value, project cost, billing, collections and estimated margin.'),
            const SizedBox(height: 18),
            if (_projects.isEmpty) const Card(child: ListTile(title: Text('No projects available'))),
            ..._projects.map((item) {
              final p = Map<String, dynamic>.from(item as Map);
              final id = p['id'];
              final f = id is int ? (_profitability[id] ?? <String,dynamic>{}) : <String,dynamic>{};
              final contract = _num(_pick(f, ['contract_value'], p['contract_value']));
              final cost = _num(_pick(f, ['total_cost', 'project_cost', 'expenses_total']));
              final billed = _num(_pick(f, ['total_billed', 'billed_amount', 'invoice_total']));
              final received = _num(_pick(f, ['total_received', 'received_amount', 'paid_amount']));
              final profit = _num(_pick(f, ['estimated_profit', 'profit'], contract - cost));
              final outstanding = _num(_pick(f, ['outstanding_amount'], billed - received));
              final margin = contract <= 0 ? 0.0 : (profit / contract * 100);
              return Card(
                margin: const EdgeInsets.only(bottom: 14),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const CircleAvatar(child: Icon(Icons.account_balance_wallet_outlined)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${p['name'] ?? 'Project'}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        Text('${p['code'] ?? ''} • ${p['status'] ?? 'planned'}'),
                      ])),
                      Text('${margin.toStringAsFixed(1)}%', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 16),
                    Wrap(spacing: 10, runSpacing: 10, children: [
                      _MoneyChip(label: 'Contract', value: _money(contract), icon: Icons.handshake_outlined),
                      _MoneyChip(label: 'Cost', value: _money(cost), icon: Icons.payments_outlined),
                      _MoneyChip(label: 'Billed', value: _money(billed), icon: Icons.request_quote_outlined),
                      _MoneyChip(label: 'Received', value: _money(received), icon: Icons.savings_outlined),
                      _MoneyChip(label: 'Outstanding', value: _money(outstanding), icon: Icons.schedule_outlined),
                      _MoneyChip(label: 'Est. Profit', value: _money(profit), icon: Icons.trending_up_outlined),
                    ]),
                  ]),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _MoneyChip extends StatelessWidget {
  const _MoneyChip({required this.label, required this.value, required this.icon});
  final String label, value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    width: 180,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(border: Border.all(color: Theme.of(context).dividerColor), borderRadius: BorderRadius.circular(14)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, size: 19), const SizedBox(height: 8), Text(value, style: const TextStyle(fontWeight: FontWeight.bold)), Text(label, style: Theme.of(context).textTheme.bodySmall)]),
  );
}
