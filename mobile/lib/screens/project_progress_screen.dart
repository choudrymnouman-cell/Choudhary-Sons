import 'package:flutter/material.dart';

import '../services/api_service.dart';

class ProjectProgressScreen extends StatefulWidget {
  const ProjectProgressScreen({super.key, required this.session});
  final AuthSession session;

  @override
  State<ProjectProgressScreen> createState() => _ProjectProgressScreenState();
}

class _ProjectProgressScreenState extends State<ProjectProgressScreen> {
  final _api = ApiService();
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.projects(widget.session.token);
  }

  void _refresh() => setState(() => _future = _api.projects(widget.session.token));

  double _progress(Map<String, dynamic> project) {
    final status = '${project['status'] ?? ''}'.toLowerCase();
    if (status == 'completed') return 1;
    if (status == 'active') {
      final start = DateTime.tryParse('${project['start_date'] ?? ''}');
      final end = DateTime.tryParse('${project['end_date'] ?? ''}');
      if (start != null && end != null && end.isAfter(start)) {
        final total = end.difference(start).inDays;
        final elapsed = DateTime.now().difference(start).inDays;
        return (elapsed / total).clamp(0.05, 0.95).toDouble();
      }
      return .5;
    }
    if (status == 'on_hold') return .35;
    return .05;
  }

  String _money(dynamic value) {
    final amount = value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
    return 'PKR ${amount.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Project Progress'), actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh))]),
      body: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text(snapshot.error.toString().replaceFirst('Exception: ', '')));
          final projects = snapshot.data ?? const [];
          if (projects.isEmpty) return const Center(child: Text('No projects yet.'));
          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.all(18),
              itemCount: projects.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final p = Map<String, dynamic>.from(projects[index] as Map);
                final progress = _progress(p);
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const CircleAvatar(child: Icon(Icons.engineering_outlined)),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${p['name'] ?? 'Project'}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                            Text('${p['code'] ?? ''} • ${p['status'] ?? 'planned'}'),
                          ])),
                          Text('${(progress * 100).round()}%', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        ]),
                        const SizedBox(height: 16),
                        LinearProgressIndicator(value: progress, minHeight: 8, borderRadius: BorderRadius.circular(20)),
                        const SizedBox(height: 14),
                        Wrap(spacing: 18, runSpacing: 8, children: [
                          _Info(icon: Icons.payments_outlined, text: _money(p['contract_value'])),
                          if (p['start_date'] != null) _Info(icon: Icons.play_circle_outline, text: '${p['start_date']}'),
                          if (p['end_date'] != null) _Info(icon: Icons.flag_outlined, text: '${p['end_date']}'),
                          if (p['site_address'] != null) _Info(icon: Icons.location_on_outlined, text: '${p['site_address']}'),
                        ]),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 17), const SizedBox(width: 5), ConstrainedBox(constraints: const BoxConstraints(maxWidth: 220), child: Text(text, overflow: TextOverflow.ellipsis))]);
}
