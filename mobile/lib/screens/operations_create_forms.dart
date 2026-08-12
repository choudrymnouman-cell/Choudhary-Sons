import 'package:flutter/material.dart';

import '../services/api_service.dart';

class OperationsCreateScreen extends StatefulWidget {
  const OperationsCreateScreen({super.key, required this.session, required this.type});
  final AuthSession session;
  final String type;

  @override
  State<OperationsCreateScreen> createState() => _OperationsCreateScreenState();
}

class _OperationsCreateScreenState extends State<OperationsCreateScreen> {
  final _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _c = {};
  bool _saving = false;
  bool _loadingLookups = true;
  String? _lookupError;
  List<dynamic> _projects = [];
  List<dynamic> _suppliers = [];
  List<dynamic> _assets = [];
  int? _projectId;
  int? _supplierId;
  int? _assetId;

  TextEditingController ctrl(String key) => _c.putIfAbsent(key, TextEditingController.new);

  @override
  void initState() {
    super.initState();
    _loadLookups();
  }

  Future<void> _loadLookups() async {
    try {
      final token = widget.session.token;
      final results = await Future.wait([
        _api.projects(token),
        _api.suppliers(token),
        _api.assets(token),
      ]);
      if (!mounted) return;
      setState(() {
        _projects = results[0];
        _suppliers = results[1];
        _assets = results[2];
      });
    } catch (e) {
      if (mounted) setState(() => _lookupError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loadingLookups = false);
    }
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _field(String key, String label, {bool number = false, int lines = 1, bool optional = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl(key),
        keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        maxLines: lines,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        validator: (v) => !optional && (v == null || v.trim().isEmpty) ? 'Required' : null,
      ),
    );
  }

  Widget _projectDropdown({bool required = false}) {
    return _dropdown(
      label: 'Project',
      value: _projectId,
      required: required,
      items: _projects,
      labelFor: (item) => '${item['code'] ?? ''} — ${item['name'] ?? 'Project'}',
      onChanged: (value) => setState(() => _projectId = value),
    );
  }

  Widget _supplierDropdown() {
    return _dropdown(
      label: 'Supplier',
      value: _supplierId,
      required: true,
      items: _suppliers,
      labelFor: (item) => '${item['name'] ?? 'Supplier'}',
      onChanged: (value) => setState(() => _supplierId = value),
    );
  }

  Widget _assetDropdown() {
    return _dropdown(
      label: 'Asset / vehicle / machinery',
      value: _assetId,
      required: true,
      items: _assets,
      labelFor: (item) => '${item['asset_code'] ?? ''} — ${item['name'] ?? 'Asset'}',
      onChanged: (value) => setState(() => _assetId = value),
    );
  }

  Widget _dropdown({
    required String label,
    required int? value,
    required bool required,
    required List<dynamic> items,
    required String Function(Map<String, dynamic>) labelFor,
    required ValueChanged<int?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<int>(
        value: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        items: items.map((raw) {
          final item = Map<String, dynamic>.from(raw as Map);
          return DropdownMenuItem<int>(
            value: item['id'] as int,
            child: Text(labelFor(item), overflow: TextOverflow.ellipsis),
          );
        }).toList(),
        onChanged: onChanged,
        validator: (v) => required && v == null ? 'Required' : null,
      ),
    );
  }

  List<Widget> _fields() {
    switch (widget.type) {
      case 'Supplier':
        return [
          _field('name', 'Supplier name'),
          _field('contact_person', 'Contact person', optional: true),
          _field('phone', 'Phone', optional: true),
          _field('email', 'Email', optional: true),
          _field('tax_number', 'Tax number', optional: true),
          _field('address', 'Address', lines: 2, optional: true),
        ];
      case 'Material':
        return [
          _field('sku', 'SKU'),
          _field('name', 'Material name'),
          _field('unit', 'Unit'),
          _field('quantity_on_hand', 'Quantity on hand', number: true),
          _field('reorder_level', 'Reorder level', number: true),
          _field('average_cost', 'Average cost', number: true),
          _field('location', 'Store / location', optional: true),
        ];
      case 'Purchase Order':
        return [
          _field('po_number', 'PO number'),
          _supplierDropdown(),
          _projectDropdown(),
          _field('order_date', 'Order date (YYYY-MM-DD)'),
          _field('expected_date', 'Expected date (YYYY-MM-DD)', optional: true),
          _field('subtotal', 'Subtotal', number: true),
          _field('tax_amount', 'Tax amount', number: true),
          _field('total_amount', 'Total amount', number: true),
          _field('notes', 'Notes', lines: 2, optional: true),
        ];
      case 'Expense':
        return [
          _projectDropdown(),
          _field('category', 'Category'),
          _field('description', 'Description'),
          _field('amount', 'Amount', number: true),
          _field('expense_date', 'Expense date (YYYY-MM-DD)'),
          _field('vendor', 'Vendor', optional: true),
          _field('payment_method', 'Payment method', optional: true),
          _field('reference', 'Reference', optional: true),
        ];
      case 'Invoice':
        return [
          _field('invoice_number', 'Invoice number'),
          _projectDropdown(required: true),
          _field('invoice_date', 'Invoice date (YYYY-MM-DD)'),
          _field('due_date', 'Due date (YYYY-MM-DD)', optional: true),
          _field('amount', 'Amount', number: true),
          _field('tax_amount', 'Tax amount', number: true),
          _field('paid_amount', 'Paid amount', number: true),
          _field('notes', 'Notes', lines: 2, optional: true),
        ];
      case 'Asset':
        return [
          _field('asset_code', 'Asset code'),
          _field('name', 'Asset name'),
          _field('asset_type', 'Asset type'),
          _field('registration_number', 'Registration number', optional: true),
          _field('make_model', 'Make / model', optional: true),
          _projectDropdown(),
          _field('current_meter', 'Current meter', number: true),
          _field('notes', 'Notes', lines: 2, optional: true),
        ];
      case 'Fuel Log':
        return [
          _assetDropdown(),
          _projectDropdown(),
          _field('liters', 'Liters', number: true),
          _field('rate_per_liter', 'Rate per liter', number: true),
          _field('meter_reading', 'Meter reading', number: true, optional: true),
          _field('vendor', 'Vendor', optional: true),
        ];
      case 'Maintenance':
        return [
          _assetDropdown(),
          _field('maintenance_type', 'Maintenance type'),
          _field('description', 'Description', lines: 2),
          _field('cost', 'Cost', number: true),
          _field('vendor', 'Vendor', optional: true),
          _field('next_due_date', 'Next due date (YYYY-MM-DD)', optional: true),
          _field('next_due_meter', 'Next due meter', number: true, optional: true),
        ];
      case 'Site Report':
        return [
          _projectDropdown(required: true),
          _field('weather', 'Weather', optional: true),
          _field('workforce_count', 'Workforce count', number: true),
          _field('work_completed', 'Work completed', lines: 3),
          _field('materials_used', 'Materials used', lines: 2, optional: true),
          _field('equipment_used', 'Equipment used', lines: 2, optional: true),
          _field('delays_issues', 'Delays / issues', lines: 2, optional: true),
          _field('tomorrow_plan', 'Tomorrow plan', lines: 2, optional: true),
        ];
      case 'Safety Incident':
        return [
          _projectDropdown(),
          _field('severity', 'Severity'),
          _field('title', 'Incident title'),
          _field('description', 'Description', lines: 3),
          _field('injured_person', 'Injured person', optional: true),
          _field('corrective_action', 'Corrective action', lines: 2, optional: true),
        ];
      case 'Notice':
        return [
          _field('title', 'Notice title'),
          _field('body', 'Notice body', lines: 4),
          _field('audience', 'Audience'),
        ];
      default:
        return const [];
    }
  }

  double _num(String key) => double.tryParse(ctrl(key).text.trim()) ?? 0;
  String? _text(String key) => ctrl(key).text.trim().isEmpty ? null : ctrl(key).text.trim();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final t = widget.session.token;
      switch (widget.type) {
        case 'Supplier':
          await _api.createSupplier(t, {'name': _text('name'), 'contact_person': _text('contact_person'), 'phone': _text('phone'), 'email': _text('email'), 'tax_number': _text('tax_number'), 'address': _text('address')});
          break;
        case 'Material':
          await _api.createMaterial(t, {'sku': _text('sku'), 'name': _text('name'), 'unit': _text('unit'), 'quantity_on_hand': _num('quantity_on_hand'), 'reorder_level': _num('reorder_level'), 'average_cost': _num('average_cost'), 'location': _text('location')});
          break;
        case 'Purchase Order':
          await _api.createPurchaseOrder(t, {'po_number': _text('po_number'), 'supplier_id': _supplierId, 'project_id': _projectId, 'order_date': _text('order_date'), 'expected_date': _text('expected_date'), 'subtotal': _num('subtotal'), 'tax_amount': _num('tax_amount'), 'total_amount': _num('total_amount'), 'notes': _text('notes')});
          break;
        case 'Expense':
          await _api.createExpense(t, {'project_id': _projectId, 'category': _text('category'), 'description': _text('description'), 'amount': _num('amount'), 'expense_date': _text('expense_date'), 'vendor': _text('vendor'), 'payment_method': _text('payment_method'), 'reference': _text('reference')});
          break;
        case 'Invoice':
          await _api.createInvoice(t, {'invoice_number': _text('invoice_number'), 'project_id': _projectId, 'client_id': null, 'invoice_date': _text('invoice_date'), 'due_date': _text('due_date'), 'amount': _num('amount'), 'tax_amount': _num('tax_amount'), 'paid_amount': _num('paid_amount'), 'notes': _text('notes')});
          break;
        case 'Asset':
          await _api.createAsset(t, {'asset_code': _text('asset_code'), 'name': _text('name'), 'asset_type': _text('asset_type'), 'registration_number': _text('registration_number'), 'make_model': _text('make_model'), 'project_id': _projectId, 'current_meter': _num('current_meter'), 'notes': _text('notes')});
          break;
        case 'Fuel Log':
          await _api.createFuelLog(t, {'asset_id': _assetId, 'project_id': _projectId, 'liters': _num('liters'), 'rate_per_liter': _num('rate_per_liter'), 'meter_reading': _text('meter_reading') == null ? null : _num('meter_reading'), 'vendor': _text('vendor')});
          break;
        case 'Maintenance':
          await _api.createMaintenance(t, {'asset_id': _assetId, 'maintenance_type': _text('maintenance_type'), 'description': _text('description'), 'cost': _num('cost'), 'vendor': _text('vendor'), 'next_due_date': _text('next_due_date'), 'next_due_meter': _text('next_due_meter') == null ? null : _num('next_due_meter')});
          break;
        case 'Site Report':
          await _api.createSiteReport(t, {'project_id': _projectId, 'weather': _text('weather'), 'workforce_count': _num('workforce_count').toInt(), 'work_completed': _text('work_completed'), 'materials_used': _text('materials_used'), 'equipment_used': _text('equipment_used'), 'delays_issues': _text('delays_issues'), 'tomorrow_plan': _text('tomorrow_plan')});
          break;
        case 'Safety Incident':
          await _api.createSafetyIncident(t, {'project_id': _projectId, 'severity': _text('severity'), 'title': _text('title'), 'description': _text('description'), 'injured_person': _text('injured_person'), 'corrective_action': _text('corrective_action')});
          break;
        case 'Notice':
          await _api.createNotice(t, {'title': _text('title'), 'body': _text('body'), 'audience': _text('audience')});
          break;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${widget.type} saved')));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Add ${widget.type}')),
      body: _loadingLookups
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_lookupError != null) ...[
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.warning_amber_outlined),
                        title: const Text('Some lookup data could not load'),
                        subtitle: Text(_lookupError!),
                        trailing: IconButton(onPressed: _loadLookups, icon: const Icon(Icons.refresh)),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  ..._fields(),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'Saving...' : 'Save'),
                  ),
                ],
              ),
            ),
    );
  }
}
