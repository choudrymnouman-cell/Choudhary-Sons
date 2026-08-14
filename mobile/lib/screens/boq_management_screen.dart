import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/api_service.dart';

class BoqManagementScreen extends StatefulWidget {
  const BoqManagementScreen({super.key, required this.session});
  final AuthSession session;

  @override
  State<BoqManagementScreen> createState() => _BoqManagementScreenState();
}

class _BoqManagementScreenState extends State<BoqManagementScreen> {
  final _api = ApiService();
  final _db = Supabase.instance.client;
  bool _loading = true;
  String? _error;
  List<dynamic> _projects = [], _items = [];
  int? _projectId;

  @override
  void initState() { super.initState(); _loadProjects(); }

  Future<void> _loadProjects() async {
    setState(() { _loading = true; _error = null; });
    try {
      final projects = await _api.projects(widget.session.token);
      final firstId = projects.isEmpty ? null : (projects.first as Map)['id'] as int?;
      if (!mounted) return;
      setState(() { _projects = projects; _projectId ??= firstId; });
      await _loadItems();
    } catch (e) { if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', '')); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _loadItems() async {
    if (_projectId == null) { if (mounted) setState(() => _items = []); return; }
    final rows = await _db.from('boq_items').select().eq('project_id', _projectId!).order('id');
    if (mounted) setState(() => _items = List<dynamic>.from(rows));
  }

  double _num(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
  String _money(dynamic v) => 'PKR ${_num(v).toStringAsFixed(0)}';

  Future<void> _addItem() async {
    if (_projectId == null) return;
    final code = TextEditingController(), desc = TextEditingController(), unit = TextEditingController(), qty = TextEditingController(), rate = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Add BOQ Item'),
      content: SizedBox(width: 440, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: code, decoration: const InputDecoration(labelText: 'Item code')),
        const SizedBox(height: 10), TextField(controller: desc, decoration: const InputDecoration(labelText: 'Description')),
        const SizedBox(height: 10), TextField(controller: unit, decoration: const InputDecoration(labelText: 'Unit (Cft, Sqft, Nos...)')),
        const SizedBox(height: 10), TextField(controller: qty, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity')),
        const SizedBox(height: 10), TextField(controller: rate, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Unit rate')),
      ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save'))],
    ));
    if (ok != true || desc.text.trim().isEmpty || unit.text.trim().isEmpty) return;
    await _db.from('boq_items').insert({'project_id': _projectId, 'item_code': code.text.trim().isEmpty ? null : code.text.trim(), 'description': desc.text.trim(), 'unit': unit.text.trim(), 'quantity': _num(qty.text), 'unit_rate': _num(rate.text), 'completed_quantity': 0});
    await _loadItems();
  }

  Future<void> _updateProgress(Map<String, dynamic> item) async {
    final controller = TextEditingController(text: '${item['completed_quantity'] ?? 0}');
    final ok = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: Text('Update ${item['item_code'] ?? 'BOQ'} Progress'),
      content: TextField(controller: controller, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Completed quantity', helperText: 'BOQ quantity: ${item['quantity']} ${item['unit']}')),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Update'))],
    ));
    if (ok != true) return;
    final value = _num(controller.text).clamp(0, _num(item['quantity']));
    await _db.from('boq_items').update({'completed_quantity': value}).eq('id', item['id']);
    await _loadItems();
  }

  @override
  Widget build(BuildContext context) {
    final total = _items.fold<double>(0, (s, e) => s + _num((e as Map)['amount']));
    final earned = _items.fold<double>(0, (s, e) { final m = e as Map; return s + _num(m['completed_quantity']) * _num(m['unit_rate']); });
    final progress = total <= 0 ? 0.0 : (earned / total).clamp(0, 1).toDouble();
    return Scaffold(
      appBar: AppBar(title: const Text('BOQ Management'), actions: [IconButton(onPressed: _loadProjects, icon: const Icon(Icons.refresh))]),
      floatingActionButton: _projectId == null ? null : FloatingActionButton.extended(onPressed: _addItem, icon: const Icon(Icons.add), label: const Text('BOQ Item')),
      body: _loading ? const Center(child: CircularProgressIndicator()) : _error != null ? Center(child: Text(_error!)) : ListView(padding: const EdgeInsets.all(18), children: [
        DropdownButtonFormField<int>(value: _projectId, decoration: const InputDecoration(labelText: 'Project'), items: _projects.map((p) { final m = p as Map; return DropdownMenuItem<int>(value: m['id'] as int, child: Text('${m['code'] ?? ''} - ${m['name'] ?? 'Project'}')); }).toList(), onChanged: (v) async { setState(() => _projectId = v); await _loadItems(); }),
        const SizedBox(height: 18),
        Wrap(spacing: 10, runSpacing: 10, children: [_Summary(label: 'BOQ Value', value: _money(total)), _Summary(label: 'Executed Value', value: _money(earned)), _Summary(label: 'Remaining', value: _money(total - earned)), _Summary(label: 'Progress', value: '${(progress * 100).toStringAsFixed(1)}%')]),
        const SizedBox(height: 14), LinearProgressIndicator(value: progress, minHeight: 9, borderRadius: BorderRadius.circular(20)), const SizedBox(height: 18),
        if (_items.isEmpty) const Card(child: ListTile(title: Text('No BOQ items yet'), subtitle: Text('Use Add BOQ Item to start project quantities.'))),
        ..._items.map((e) { final m = Map<String,dynamic>.from(e as Map); final q = _num(m['quantity']); final done = _num(m['completed_quantity']); final pct = q <= 0 ? 0.0 : (done/q).clamp(0,1).toDouble(); return Card(child: ListTile(onTap: () => _updateProgress(m), leading: CircleAvatar(child: Text('${(pct*100).round()}%')), title: Text('${m['item_code'] ?? ''} ${m['description'] ?? ''}'.trim()), subtitle: Text('${done.toStringAsFixed(2)} / ${q.toStringAsFixed(2)} ${m['unit']} • ${_money(m['unit_rate'])}/${m['unit']}\nAmount: ${_money(m['amount'])}'), isThreeLine: true, trailing: const Icon(Icons.edit_outlined))); }),
        const SizedBox(height: 80),
      ]),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Container(width: 180, padding: const EdgeInsets.all(14), decoration: BoxDecoration(border: Border.all(color: Theme.of(context).dividerColor), borderRadius: BorderRadius.circular(14)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: const TextStyle(fontWeight: FontWeight.bold)), Text(label, style: Theme.of(context).textTheme.bodySmall)]));
}
