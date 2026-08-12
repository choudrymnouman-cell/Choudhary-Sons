import 'package:flutter/material.dart';

import '../services/api_service.dart';

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
  Map<String, dynamic> _kpis = {};
  Map<String, dynamic> _assetCosts = {};
  List<dynamic> _assets = [];
  List<dynamic> _reports = [];
  List<dynamic> _incidents = [];
  List<dynamic> _notices = [];

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
        _api.dashboardKpis(widget.session.token),
        _api.assetCostSummary(widget.session.token),
        _api.assets(widget.session.token),
        _api.siteReports(widget.session.token),
        _api.safetyIncidents(widget.session.token),
        _api.notices(widget.session.token),
      ]);

      if (!mounted) return;
      setState(() {
        _kpis = results[0] as Map<String, dynamic>;
        _assetCosts = results[1] as Map<String, dynamic>;
        _assets = results[2] as List<dynamic>;
        _reports = results[3] as List<dynamic>;
        _incidents = results[4] as List<dynamic>;
        _notices = results[5] as List<dynamic>;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _money(dynamic value) {
    final amount = value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
    return 'PKR ${amount.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Field Operations'),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 48),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(18),
                    children: [
                      Text('Operations Overview', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      const Text('Live site, fleet and safety information.'),
                      const SizedBox(height: 18),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1.25,
                        children: [
                          _MetricCard(label: 'Active Projects', value: '${_kpis['active_projects'] ?? 0}', icon: Icons.engineering_outlined),
                          _MetricCard(label: 'Assets', value: '${_assetCosts['asset_count'] ?? _assets.length}', icon: Icons.precision_manufacturing_outlined),
                          _MetricCard(label: 'Open Incidents', value: '${_kpis['open_safety_incidents'] ?? 0}', icon: Icons.health_and_safety_outlined),
                          _MetricCard(label: 'Site Reports', value: '${_reports.length}', icon: Icons.description_outlined),
                          _MetricCard(label: 'Fuel Cost', value: _money(_assetCosts['fuel_cost']), icon: Icons.local_gas_station_outlined),
                          _MetricCard(label: 'Maintenance', value: _money(_assetCosts['maintenance_cost']), icon: Icons.build_outlined),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text('Recent Safety Incidents', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      if (_incidents.isEmpty)
                        const Card(child: ListTile(title: Text('No incidents recorded')))
                      else
                        ..._incidents.take(5).map((item) {
                          final incident = item as Map<String, dynamic>;
                          return Card(
                            child: ListTile(
                              leading: const Icon(Icons.warning_amber_outlined),
                              title: Text('${incident['title'] ?? 'Safety incident'}'),
                              subtitle: Text('${incident['severity'] ?? 'unknown'} • ${incident['incident_date'] ?? ''}'),
                              trailing: Icon(incident['is_closed'] == true ? Icons.check_circle_outline : Icons.pending_outlined),
                            ),
                          );
                        }),
                      const SizedBox(height: 16),
                      Text('Company Notices', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      if (_notices.isEmpty)
                        const Card(child: ListTile(title: Text('No active notices')))
                      else
                        ..._notices.take(5).map((item) {
                          final notice = item as Map<String, dynamic>;
                          return Card(
                            child: ListTile(
                              leading: const Icon(Icons.campaign_outlined),
                              title: Text('${notice['title'] ?? 'Notice'}'),
                              subtitle: Text('${notice['body'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const Spacer(),
            Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
