import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'tender_register.dart';
import 'department_home.dart' show departmentNames;

class OwnerConsole extends StatefulWidget {
  const OwnerConsole({super.key, required this.session});
  final AuthSession session;

  @override
  State<OwnerConsole> createState() => _OwnerConsoleState();
}

class _OwnerConsoleState extends State<OwnerConsole> {
  late final api = OwnerHttp(widget.session.token);
  late Future<Map<String, dynamic>> overview = api.overview();
  late Future<List<Map<String, dynamic>>> accounts = api.accounts();
  late Future<List<Map<String, dynamic>>> events = api.activity();
  late Future<List<Map<String, dynamic>>> approvals = api.approvals();
  final deciding = <int>{};
  String accountSearch = "";
  bool pendingOnly = false;

  void refresh() {
    setState(() {
      overview = api.overview();
      accounts = api.accounts();
      events = api.activity();
      approvals = api.approvals();
    });
  }

  Future<void> editAccount(Map<String, dynamic>? account) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _AccountDialog(api: api, account: account, ownerId: widget.session.userId),
    );
    if (mounted && saved == true) refresh();
  }

  Future<void> configureThresholds() async {
    try {
      final rules = await api.thresholds();
      if (!mounted) return;
      await showDialog<void>(context: context, builder: (_) => _ThresholdDialog(api: api, rules: rules));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> decide(int id, String decision) async {
    if (deciding.contains(id)) return;
    setState(() => deciding.add(id));
    try {
      await api.decide(id, decision);
      if (mounted) refresh();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => deciding.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 4,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Owner Console'),
        actions: [
          IconButton(tooltip: 'Tender register', icon: const Icon(Icons.assignment_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TenderRegister(api: api)))),
          IconButton(tooltip: 'Refresh', onPressed: refresh, icon: const Icon(Icons.refresh)),
        ],
        bottom: const TabBar(tabs: [
          Tab(text: 'Overview'), Tab(text: 'Approvals'), Tab(text: 'Accounts'), Tab(text: 'Activity'),
        ]),
      ),
      body: TabBarView(children: [
        _Load<Map<String, dynamic>>(future: overview, buildData: (summary) => _FinanceOverview(summary: summary)),
        _Load<List<Map<String, dynamic>>>(future: approvals, buildData: (rows) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Align(alignment: Alignment.centerLeft, child: OutlinedButton.icon(
              onPressed: configureThresholds, icon: const Icon(Icons.tune),
              label: const Text('Approval thresholds'),
            )),
            if (rows.isEmpty) const ListTile(title: Text('No pending approvals')),
            for (final row in rows)
              Card(child: ListTile(
                title: Text(row['description'].toString()),
                subtitle: Text('${row['requested_by']} · ${row['requested_at']}'
                  '${row['amount'] == null ? '' : ' · PKR ${row['amount']}'}'),
                trailing: Wrap(spacing: 8, children: [
                  TextButton(onPressed: deciding.contains(row['id']) ? null : () => decide(row['id'] as int, 'reject'),
                    child: const Text('Reject')),
                  FilledButton(onPressed: deciding.contains(row['id']) ? null : () => decide(row['id'] as int, 'approve'),
                    child: const Text('Approve')),
                ]),
              )),
          ],
        )),
        _Load<List<Map<String, dynamic>>>(future: accounts, buildData: (rows) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Align(alignment: Alignment.centerLeft, child: FilledButton.icon(
              onPressed: () => editAccount(null),
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('Create account'),
            )),
            const SizedBox(height:16),
            const Text('New registrations wait here until you assign a role. Role changes sign the user out immediately.'),
            const SizedBox(height:12),
            TextField(decoration: const InputDecoration(labelText:'Find a person',prefixIcon:Icon(Icons.search)),onChanged:(v)=>setState(()=>accountSearch=v.toLowerCase())),
            SwitchListTile(title:Text('Awaiting assignment (${rows.where((a)=>a['role']=='pending').length})'),value:pendingOnly,onChanged:(v)=>setState(()=>pendingOnly=v)),
            for (final account in rows.where((a)=>(!pendingOnly||a['role']=='pending') && '${a['full_name']} ${a['email']}'.toLowerCase().contains(accountSearch)))
              ListTile(
                title: Text(account['full_name'].toString()),
                subtitle: Text("${account['email']} · ${departmentNames[account['role']] ?? account['role']}"),
                trailing: Text(account['role']=='pending' ? 'Assign role →' : account['is_active'] == true ? 'Active' : 'Inactive'),
                onTap: () => editAccount(account),
              ),
          ],
        )),
        _Load<List<Map<String, dynamic>>>(future: events, buildData: (rows) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (rows.isEmpty) const ListTile(title: Text('No activity recorded yet')),
            for (final event in rows)
              ListTile(
                title: Text('${event['method']}  ${event['resource']}'),
                subtitle: Text('${event['actor'] ?? 'Removed account'} · ${event['occurred_at']}'
                  '${event['resource_id'] == null ? '' : ' · Record ${event['resource_id']}'}'),
                trailing: Text('${event['status_code']}'),
              ),
            if (rows.length == 100)
              TextButton(onPressed: () => setState(() => events = api.activity(before: rows.last['id'] as int)),
                child: const Text('Older activity')),
          ],
        )),
      ]),
    ),
  );
}

class _Load<T> extends StatelessWidget {
  const _Load({required this.future, required this.buildData});
  final Future<T> future;
  final Widget Function(T) buildData;

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
      return buildData(snapshot.data as T);
    },
  );
}

class _FinanceOverview extends StatelessWidget {
  const _FinanceOverview({required this.summary});
  final Map<String, dynamic> summary;

  double number(Object? value) => double.tryParse(value.toString()) ?? 0;
  String amount(Object? value) => 'PKR ${number(value).toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final days = (summary['cash_movements'] as List).cast<Map<String, dynamic>>();
    final maximum = days.fold<double>(1, (total, row) =>
      math.max(total, math.max(number(row['receipts']), number(row['supplier_payments']))));
    final colors = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('${summary['start_date']} to ${summary['end_date']}', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Wrap(spacing: 12, runSpacing: 12, children: [
          for (final (label, value) in [
            ('Billed', amount(summary['billed'])),
            ('Recorded expenses', amount(summary['recorded_expenses'])),
            ('Billed less expenses', amount(summary['billed_less_expenses'])),
            ('Open receivables', amount(summary['open_receivables'])),
            ('Projects', '${summary['project_count']}'),
          ])
            SizedBox(width: 218, child: Card(child: ListTile(title: Text(label), subtitle: Text(value)))),
        ]),
        const SizedBox(height: 20),
        Text('Recorded customer receipts and supplier payments', style: Theme.of(context).textTheme.titleMedium),
        for (final row in days.reversed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              Text('${row['date']}'),
              const SizedBox(width: 12),
              Expanded(child: Column(children: [
                _CashBar(label: 'Receipts', amount: amount(row['receipts']),
                  fraction: number(row['receipts']) / maximum, color: colors.primary),
                _CashBar(label: 'Supplier payments', amount: amount(row['supplier_payments']),
                  fraction: number(row['supplier_payments']) / maximum, color: colors.tertiary),
              ])),
            ]),
          ),
      ],
    );
  }
}

class _CashBar extends StatelessWidget {
  const _CashBar({required this.label, required this.amount, required this.fraction, required this.color});
  final String label;
  final String amount;
  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: '$label · $amount',
    child: Padding(padding: const EdgeInsets.symmetric(vertical: 3),
      child: LinearProgressIndicator(
        value: fraction.clamp(0, 1).toDouble(), color: color, semanticsLabel: '$label · $amount',
      )),
  );
}

class _AccountDialog extends StatefulWidget {
  const _AccountDialog({required this.api, required this.account, required this.ownerId});
  final OwnerHttp api;
  final Map<String, dynamic>? account;
  final String ownerId;

  @override
  State<_AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends State<_AccountDialog> {
  static const roles = ['owner', 'admin', 'hr', 'accountant', 'project_manager', 'site_supervisor', 'employee', 'procurement', 'store', 'estimator', 'equipment', 'pending', 'applicant'];
  late final name = TextEditingController(text: widget.account?['full_name']?.toString());
  late final email = TextEditingController(text: widget.account?['email']?.toString());
  final password = TextEditingController();
  late final originalRole = widget.account?['role']?.toString() ?? 'employee';
  late String role = originalRole;
  late bool active = widget.account?['is_active'] != false;
  bool saving = false;
  String? error;
  late final projects = widget.api.projects();
  late final selectedProjects = <int>{...((widget.account?['project_ids'] as List?) ?? []).cast<int>()};

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final editing = widget.account != null;
    if (name.text.trim().isEmpty || (!editing && email.text.trim().isEmpty)) {
      setState(() => error = 'Enter the account details.');
      return;
    }
    if ((!editing || password.text.isNotEmpty) && password.text.length < 12) {
      setState(() => error = 'Use a password with at least 12 characters.');
      return;
    }
    setState(() { saving = true; error = null; });
    try {
      await widget.api.saveAccount({
        'full_name': name.text.trim(),
        if (!editing) 'email': email.text.trim(),
        if (!editing || role != originalRole) 'role': role,
        if (editing) 'is_active': active,
        'project_ids': selectedProjects.toList(),
        if (password.text.isNotEmpty) 'password': password.text,
      }, id: widget.account?['id'] as int?);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() { saving = false; error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.account != null;
    final self = widget.account?['id'].toString() == widget.ownerId;
    final options = [...roles, if (!roles.contains(originalRole)) originalRole];
    return AlertDialog(
      title: Text(editing ? 'Edit account access' : 'Create account'),
      content: SizedBox(width: 420, child: SingleChildScrollView(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Full name')),
          TextField(controller: email, enabled: !editing, decoration: const InputDecoration(labelText: 'Email')),
          DropdownButtonFormField<String>(
            initialValue: role,
            decoration: const InputDecoration(labelText: 'Department / role', helperText: 'Only the assigned department will be available.'),
            items: [for (final value in options) DropdownMenuItem(value: value, child: Text(departmentNames[value] ?? value))],
            onChanged: saving || self ? null : (value) => setState(() => role = value!),
          ),
          if (role == 'project_manager' || role == 'site_supervisor')
            FutureBuilder<List<Map<String, dynamic>>>(future: projects, builder: (context, snapshot) {
              if (snapshot.hasError) return const Text('Could not load projects. Close and retry.');
              if (!snapshot.hasData) return const LinearProgressIndicator();
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SizedBox(height: 16),
                const Text('Assigned projects'),
                const Text('No selection means no access to existing projects.'),
                for (final project in snapshot.data!) CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${project['name']}'),
                  subtitle: Text('${project['code']}'),
                  value: selectedProjects.contains(project['id']),
                  onChanged: saving ? null : (checked) => setState(() {
                    if (checked == true) { selectedProjects.add(project['id'] as int); }
                    else { selectedProjects.remove(project['id']); }
                  }),
                ),
              ]);
            }),
          if (editing) SwitchListTile(title: const Text('Active account'), value: active,
            onChanged: saving || self ? null : (value) => setState(() => active = value)),
          TextField(controller: password, obscureText: true, enableSuggestions: false, autocorrect: false,
            decoration: InputDecoration(labelText: editing ? 'New password (optional)' : 'Initial password')),
          if (error != null) Text(error!),
        ],
      ))),
      actions: [
        TextButton(onPressed: saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: saving ? null : save, child: const Text('Save')),
      ],
    );
  }
}

class _ThresholdDialog extends StatefulWidget {
  const _ThresholdDialog({required this.api, required this.rules});
  final OwnerHttp api;
  final Map<String, dynamic> rules;

  @override
  State<_ThresholdDialog> createState() => _ThresholdDialogState();
}

class _ThresholdDialogState extends State<_ThresholdDialog> {
  late final order = TextEditingController(text: widget.rules['purchase_order_threshold']?.toString());
  late final payment = TextEditingController(text: widget.rules['vendor_payment_threshold']?.toString());
  bool saving = false;
  String? error;

  @override
  void dispose() {
    order.dispose();
    payment.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final values = [order.text.trim(), payment.text.trim()];
    if (values.any((value) => value.isNotEmpty &&
        (!RegExp(r'^\d{1,14}(\.\d{1,2})?$').hasMatch(value) || (double.tryParse(value) ?? 0) <= 0))) {
      setState(() => error = 'Enter positive amounts with up to two decimal places.');
      return;
    }
    setState(() { saving = true; error = null; });
    try {
      await widget.api.saveThresholds({
        'purchase_order_threshold': values[0].isEmpty ? null : values[0],
        'vendor_payment_threshold': values[1].isEmpty ? null : values[1],
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() { saving = false; error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Approval Thresholds'),
    content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('Amounts at or above a threshold require owner approval. Leave a field blank to disable that threshold.'),
      TextField(controller: order, decoration: const InputDecoration(labelText: 'Purchase orders (PKR)')),
      TextField(controller: payment, decoration: const InputDecoration(labelText: 'Vendor payments (PKR)')),
      if (error != null) Text(error!),
    ])),
    actions: [
      TextButton(onPressed: saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: saving ? null : save, child: const Text('Save')),
    ],
  );
}
