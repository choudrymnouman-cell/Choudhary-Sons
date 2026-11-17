import 'package:flutter/material.dart';

import '../services/api_service.dart';

const _statuses = {
  'upcoming': 'Upcoming',
  'submitted': 'Submitted',
  'won': 'Won',
  'lost': 'Lost',
  'withdrawn': 'Withdrawn',
};

class TenderRegister extends StatefulWidget {
  const TenderRegister({super.key, required this.api});
  final OwnerHttp api;

  @override
  State<TenderRegister> createState() => _TenderRegisterState();
}

class _TenderRegisterState extends State<TenderRegister> {
  late Future<List<Map<String, dynamic>>> _rows = widget.api.tenders();
  String _filter = 'all';

  void _refresh() => setState(() => _rows = widget.api.tenders());

  Future<void> _edit([Map<String, dynamic>? row]) async {
    final saved = await showDialog<bool>(context: context,
      builder: (_) => _TenderDialog(api: widget.api, row: row));
    if (mounted && saved == true) _refresh();
  }

  String _deadline(Map<String, dynamic> row) {
    final days = row['days_until_deadline'] as int;
    if (row['status'] != 'upcoming') return row['deadline'].toString();
    if (days == 0) return 'Due today';
    return days < 0 ? 'Overdue by ${-days} days' : 'Due in $days days';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Tender Register'), actions: [
      IconButton(onPressed: _refresh, tooltip: 'Refresh', icon: const Icon(Icons.refresh)),
    ]),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _edit(), icon: const Icon(Icons.add), label: const Text('New tender')),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _rows,
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final rows = snapshot.data!.where((row) => _filter == 'all' || row['status'] == _filter).toList();
        return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 86), children: [
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final entry in {'all': 'All', ..._statuses}.entries)
              ChoiceChip(label: Text(entry.value), selected: _filter == entry.key,
                onSelected: (_) => setState(() => _filter = entry.key)),
          ]),
          const SizedBox(height: 12),
          if (rows.isEmpty) const ListTile(title: Text('No tenders in this view.')),
          for (final row in rows)
            Card(child: ListTile(
              title: Text('${row['reference']} · ${row['title']}'),
              subtitle: Text('${row['authority']} · ${_statuses[row['status']]}\n'
                '${_deadline(row)}${row['estimated_margin_percent'] == null ? '' : ' · Est. margin ${row['estimated_margin_percent']}%'}'),
              isThreeLine: true,
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => _edit(row),
            )),
        ]);
      },
    ),
  );
}

class _TenderDialog extends StatefulWidget {
  const _TenderDialog({required this.api, required this.row});
  final OwnerHttp api;
  final Map<String, dynamic>? row;

  @override
  State<_TenderDialog> createState() => _TenderDialogState();
}

class _TenderDialogState extends State<_TenderDialog> {
  final _form = GlobalKey<FormState>();
  late final _fields = {
    for (final field in ['reference', 'title', 'authority', 'deadline', 'bid_amount', 'estimated_cost', 'notes'])
      field: TextEditingController(text: widget.row?[field]?.toString()),
  };
  late String _status = widget.row?['status']?.toString() ?? 'upcoming';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final entered = DateTime.tryParse(_fields['deadline']!.text);
    final now = DateTime.now();
    final first = DateTime(2000);
    final last = DateTime(2100, 12, 31);
    final initial = entered != null && !entered.isBefore(first) && !entered.isAfter(last) ? entered : now;
    final chosen = await showDatePicker(context: context, firstDate: first, lastDate: last, initialDate: initial);
    if (mounted && chosen != null) _fields['deadline']!.text = chosen.toIso8601String().split('T').first;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _saving) return;
    setState(() { _saving = true; _error = null; });
    try {
      await widget.api.saveTender({
        for (final entry in _fields.entries)
          entry.key: entry.value.text.trim().isEmpty ? null : entry.value.text.trim(),
        'status': _status,
      }, id: widget.row?['id'] as int?);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() { _saving = false; _error = e.toString(); });
    }
  }

  Widget _field(String key, String label, {bool required = false, bool amount = false, int? limit}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: _fields[key],
        readOnly: key == 'deadline',
        onTap: key == 'deadline' ? _pickDeadline : null,
        maxLength: limit,
        maxLines: key == 'notes' ? 3 : 1,
        keyboardType: amount ? const TextInputType.numberWithOptions(decimal: true) : null,
        decoration: InputDecoration(labelText: label),
        validator: (raw) {
          final value = raw?.trim() ?? '';
          if (required && value.isEmpty) return 'Required';
          if (amount && value.isNotEmpty &&
              (!RegExp(r'^\d{1,14}(\.\d{1,2})?$').hasMatch(value)
                  || (key == 'bid_amount' && (double.tryParse(value) ?? 0) <= 0))) {
            return 'Enter a valid PKR amount.';
          }
          return null;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.row == null ? 'New tender' : 'Edit tender'),
    content: SizedBox(width: 460, child: SingleChildScrollView(child: Form(
      key: _form,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _field('reference', 'Tender reference', required: true, limit: 70),
        _field('title', 'Title', required: true, limit: 180),
        _field('authority', 'Issuing authority', required: true, limit: 180),
        _field('deadline', 'Submission deadline', required: true),
        DropdownButtonFormField<String>(
          initialValue: _status, decoration: const InputDecoration(labelText: 'Status'),
          items: [for (final entry in _statuses.entries) DropdownMenuItem(value: entry.key, child: Text(entry.value))],
          onChanged: _saving ? null : (value) => setState(() => _status = value!),
        ),
        _field('bid_amount', 'Bid amount (PKR)', amount: true),
        _field('estimated_cost', 'Estimated cost (PKR)', amount: true),
        _field('notes', 'Notes', limit: 4000),
        if (_error != null) Text(_error!),
      ]),
    ))),
    actions: [
      TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: _saving ? null : _save, child: const Text('Save')),
    ],
  );
}
