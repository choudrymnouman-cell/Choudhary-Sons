import 'package:flutter/material.dart';
import '../services/api_service.dart';

class RequisitionWorkspace extends StatefulWidget {
  const RequisitionWorkspace({super.key, required this.session});
  final AuthSession session;
  @override State<RequisitionWorkspace> createState() => _RequisitionWorkspaceState();
}
class _RequisitionWorkspaceState extends State<RequisitionWorkspace> {
  late final api = WorkspaceHttp(widget.session.token);
  late Future<List<Map<String, dynamic>>> data = api.list('/requisitions');
  String filter = 'requested';
  bool get buyer => const {'owner','procurement'}.contains(widget.session.role);
  bool get requester => const {'owner','project_manager','site_supervisor'}.contains(widget.session.role);
  void refresh() => setState(() => data = api.list('/requisitions'));
  Future<void> openForm([Map<String, dynamic>? row]) async {
    final result = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => _RequisitionForm(api: api, row: row)));
    if (result == true) refresh();
  }
  Future<void> cancel(Map<String, dynamic> row) async {
    final yes = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Cancel material request?'), content: Text('${row['quantity']} ${row['unit']} of ${row['material_name']}'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep request')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cancel request'))]));
    if (yes != true) return;
    try { await api.post('/requisitions/${row['id']}/cancel', {}); refresh(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Material requests'), actions: [IconButton(onPressed: refresh, icon: const Icon(Icons.refresh))]),
    floatingActionButton: requester ? FloatingActionButton.extended(onPressed: () => openForm(), icon: const Icon(Icons.add), label: const Text('Request material')) : null,
    body: Column(children: [Padding(padding: const EdgeInsets.all(20), child: Wrap(spacing: 10, children: [for (final status in ['requested','ordered','cancelled']) ChoiceChip(label: Text(status[0].toUpperCase()+status.substring(1)), selected: filter == status, onSelected: (_) => setState(() => filter = status))])), Expanded(child: FutureBuilder<List<Map<String, dynamic>>>(future: data, builder: (context,s) {
      if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
      if (s.hasError) return Center(child: TextButton(onPressed: refresh, child: const Text('Could not load requests. Retry')));
      final rows = s.data!.where((r) => r['status'] == filter).toList();
      if (rows.isEmpty) return const Center(child: Text('No material requests in this view.'));
      return ListView(padding: const EdgeInsets.fromLTRB(20,0,20,100), children: [for(final r in rows) Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${r['material_name']}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), Text('${r['quantity']} ${r['unit']} · Needed ${r['needed_by']}'), const SizedBox(height: 10), Text('${r['purpose']}'),
        if (r['purchase_order_id'] != null) Text('Linked purchase order #${r['purchase_order_id']}'),
        if (r['status'] == 'requested') Wrap(spacing: 10, children: [
          if (buyer) FilledButton.icon(onPressed: () => openForm(r), icon: const Icon(Icons.shopping_cart_outlined), label: const Text('Create purchase order')),
          if (requester && (widget.session.role == 'owner' || '${r['requested_by']}' == widget.session.userId)) TextButton(onPressed: () => cancel(r), child: const Text('Cancel request')),
        ]),
      ])))]);
    }))]),
  );
}
class _RequisitionForm extends StatefulWidget {
  const _RequisitionForm({required this.api, this.row});
  final WorkspaceHttp api;
  final Map<String,dynamic>? row;
  @override State<_RequisitionForm> createState() => _RequisitionFormState();
}
class _RequisitionFormState extends State<_RequisitionForm> {
  final form = GlobalKey<FormState>();
  final values = <String,TextEditingController>{};
  int? project, material, supplier;
  DateTime needed = DateTime.now().add(const Duration(days: 7));
  bool saving = false;
  bool get order => widget.row != null;
  late Future<List<List<Map<String,dynamic>>>> data = load();
  Future<List<List<Map<String,dynamic>>>> load() => order ? Future.wait([widget.api.list('/commercial/suppliers')]) : Future.wait([widget.api.list('/projects'), widget.api.list('/requisitions/catalogue')]);
  TextEditingController c(String key) => values.putIfAbsent(key, TextEditingController.new);
  @override void dispose() { for(final v in values.values) { v.dispose(); } super.dispose(); }
  Widget field(String key,String label,{bool numeric=false,bool optional=false}) => Padding(padding: const EdgeInsets.only(bottom: 16), child: TextFormField(controller:c(key),keyboardType:numeric?TextInputType.number:TextInputType.text,decoration:InputDecoration(labelText:label),validator:(v){if((v??'').trim().isEmpty)return optional?null:'Enter $label'; if(numeric && (double.tryParse(v!)==null || !double.parse(v).isFinite || double.parse(v)<0))return 'Enter a valid amount';return null;}));
  Future<void> save() async {
    if(!form.currentState!.validate())return;
    setState(()=>saving=true);
    try {
      if(order) {
        final result=await widget.api.post('/requisitions/${widget.row!['id']}/order',{'supplier_id':supplier,'po_number':c('po_number').text.trim(),'unit_price':c('price').text.trim(),'tax_amount':c('tax').text.trim().isEmpty?'0':c('tax').text.trim()});
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(result['status']=='pending_approval'?'Purchase order sent for owner approval.':'Purchase order created.')));
      } else {
        await widget.api.post('/requisitions',{'project_id':project,'material_id':material,'quantity':c('quantity').text.trim(),'purpose':c('purpose').text.trim(),'needed_by':needed.toIso8601String().split('T').first});
      }
      if(mounted) Navigator.pop(context,true);
    } catch(e) {if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}
    finally{if(mounted)setState(()=>saving=false);}
  }
  Widget dropdown(String label,List<Map<String,dynamic>> rows,ValueChanged<int?> changed) => Padding(padding:const EdgeInsets.only(bottom:16),child:DropdownButtonFormField<int>(isExpanded:true,decoration:InputDecoration(labelText:label),items:[for(final r in rows)DropdownMenuItem(value:r['id'] as int,child:Text('${r['name']}'))],onChanged:changed,validator:(v)=>v==null?'Choose $label':null));
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(order?'Convert request to purchase order':'Request site material')),body:FutureBuilder<List<List<Map<String,dynamic>>>>(future:data,builder:(context,s){
    if(s.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());
    if(s.hasError)return Center(child:TextButton(onPressed:()=>setState(()=>data=load()),child:const Text('Could not load options. Retry')));
    return Align(alignment:Alignment.topCenter,child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:720),child:Form(key:form,child:ListView(padding:const EdgeInsets.all(24),children:[
      if(order)...[
        Text('${widget.row!['quantity']} ${widget.row!['unit']} · ${widget.row!['material_name']}',style:const TextStyle(fontSize:22,fontWeight:FontWeight.bold)),const SizedBox(height:20),
        dropdown('Supplier',s.data![0],(v)=>supplier=v),field('po_number','Purchase order number'),field('price','Unit price',numeric:true),field('tax','Tax amount',numeric:true,optional:true),
        const Text('The total is calculated from the requested quantity. Orders above the owner’s configured limit wait for approval.'),
      ] else ...[
        dropdown('Project',s.data![0],(v)=>project=v),dropdown('Material',s.data![1],(v)=>material=v),field('quantity','Quantity',numeric:true),field('purpose','Purpose / work area'),
        OutlinedButton.icon(icon:const Icon(Icons.calendar_month),label:Text('Needed by: ${needed.toIso8601String().split('T').first}'),onPressed:()async{final d=await showDatePicker(context:context,initialDate:needed,firstDate:DateTime(2000),lastDate:DateTime(2100));if(d!=null)setState(()=>needed=d);}),
      ],const SizedBox(height:24),FilledButton(onPressed:saving?null:save,child:Text(saving?'Saving…':order?'Create purchase order':'Submit request')),
    ]))));
  }));
}
