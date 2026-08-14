import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'operations_create_forms.dart';
import 'project_progress_screen.dart';

class FieldOperationsScreen extends StatefulWidget {
  const FieldOperationsScreen({super.key, required this.session});
  final AuthSession session;

  @override
  State<FieldOperationsScreen> createState() => _FieldOperationsScreenState();
}

class _FieldOperationsScreenState extends State<FieldOperationsScreen> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _kpis = {}, _assetCosts = {};
  List<dynamic> _assets = [], _reports = [], _incidents = [], _notices = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        _api.dashboardKpis(widget.session.token), _api.assetCostSummary(widget.session.token), _api.assets(widget.session.token),
        _api.siteReports(widget.session.token), _api.safetyIncidents(widget.session.token), _api.notices(widget.session.token),
      ]);
      if (!mounted) return;
      setState(() { _kpis = results[0] as Map<String,dynamic>; _assetCosts = results[1] as Map<String,dynamic>; _assets = results[2] as List; _reports = results[3] as List; _incidents = results[4] as List; _notices = results[5] as List; });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _open(String type) async {
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => OperationsCreateScreen(session: widget.session, type: type)));
    if (changed == true) _load();
  }

  void _openProgress() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProjectProgressScreen(session: widget.session)));

  String _money(dynamic value) {
    final amount = value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
    return 'PKR ${amount.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Field Operations'), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))]),
      body: _loading ? const Center(child: CircularProgressIndicator()) : _error != null ? Center(child: Text(_error!)) : RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Text('Operations Overview', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('Live site, project, fleet and safety information.'),
            const SizedBox(height: 18),
            GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.25, children: [
              _MetricCard(label: 'Active Projects', value: '${_kpis['active_projects'] ?? 0}', icon: Icons.engineering_outlined),
              _MetricCard(label: 'Assets', value: '${_assetCosts['asset_count'] ?? _assets.length}', icon: Icons.precision_manufacturing_outlined),
              _MetricCard(label: 'Open Incidents', value: '${_kpis['open_safety_incidents'] ?? 0}', icon: Icons.health_and_safety_outlined),
              _MetricCard(label: 'Site Reports', value: '${_reports.length}', icon: Icons.description_outlined),
              _MetricCard(label: 'Fuel Cost', value: _money(_assetCosts['fuel_cost']), icon: Icons.local_gas_station_outlined),
              _MetricCard(label: 'Maintenance', value: _money(_assetCosts['maintenance_cost']), icon: Icons.build_outlined),
            ]),
            const SizedBox(height: 20),
            Text('Project Control', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            _ActionTile(icon: Icons.insights_outlined, title: 'Project Progress Dashboard', subtitle: 'Track status, timeline, contract value and site location', onTap: _openProgress),
            const SizedBox(height: 12),
            Text('Quick Actions', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            _ActionTile(icon: Icons.precision_manufacturing_outlined, title: 'Add Machinery / Vehicle', onTap: () => _open('Asset')),
            _ActionTile(icon: Icons.local_gas_station_outlined, title: 'Record Fuel', onTap: () => _open('Fuel Log')),
            _ActionTile(icon: Icons.build_outlined, title: 'Record Maintenance', onTap: () => _open('Maintenance')),
            _ActionTile(icon: Icons.description_outlined, title: 'Daily Site Report', onTap: () => _open('Site Report')),
            _ActionTile(icon: Icons.health_and_safety_outlined, title: 'Report Safety Incident', onTap: () => _open('Safety Incident')),
            _ActionTile(icon: Icons.campaign_outlined, title: 'Create Company Notice', onTap: () => _open('Notice')),
            const SizedBox(height: 16),
            Text('Recent Safety Incidents', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            if (_incidents.isEmpty) const Card(child: ListTile(title: Text('No incidents recorded'))) else ..._incidents.take(5).map((item) { final m = Map<String,dynamic>.from(item as Map); return Card(child: ListTile(leading: const Icon(Icons.warning_amber_outlined), title: Text('${m['title'] ?? 'Safety incident'}'), subtitle: Text('${m['severity'] ?? 'unknown'} • ${m['incident_date'] ?? ''}'))); }),
            const SizedBox(height: 16),
            Text('Company Notices', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            if (_notices.isEmpty) const Card(child: ListTile(title: Text('No active notices'))) else ..._notices.take(5).map((item) { final m = Map<String,dynamic>.from(item as Map); return Card(child: ListTile(leading: const Icon(Icons.campaign_outlined), title: Text('${m['title'] ?? 'Notice'}'), subtitle: Text('${m['body'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis))); }),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value, required this.icon});
  final String label, value; final IconData icon;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon), const Spacer(), Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)), Text(label, style: Theme.of(context).textTheme.bodySmall)])));
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.title, required this.onTap, this.subtitle});
  final IconData icon; final String title; final String? subtitle; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(child: ListTile(leading: Icon(icon), title: Text(title), subtitle: subtitle == null ? null : Text(subtitle!), trailing: const Icon(Icons.chevron_right), onTap: onTap));
}
