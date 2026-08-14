import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/api_service.dart';

class MaterialStockScreen extends StatefulWidget {
  const MaterialStockScreen({super.key, required this.session});
  final AuthSession session;
  @override State<MaterialStockScreen> createState() => _MaterialStockScreenState();
}

class _MaterialStockScreenState extends State<MaterialStockScreen> {
  final _api = ApiService();
  final _db = Supabase.instance.client;
  bool _loading = true;
  String? _error;
  List<dynamic> _materials = [], _projects = [], _history = [];

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([_api.materials(widget.session.token), _api.projects(widget.session.token), _db.from('material_stock_movements').select('*, materials(name,unit), projects(name,code)').order('created_at', ascending: false).limit(100)]);
      if (!mounted) return;
      setState(() { _materials = results[0] as List; _projects = results[1] as List; _history = results[2] as List; });
    } catch (e) { if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', '')); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  double _num(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

  Future<void> _movement() async {
    if (_materials.isEmpty) return;
    int materialId = (_materials.first as Map)['id'] as int;
    int? projectId;
    String type = 'received';
    final qty = TextEditingController(), cost = TextEditingController(), ref = TextEditingController(), notes = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (context) => StatefulBuilder(builder: (context, setLocal) => AlertDialog(
      title: const Text('Record Stock Movement'),
      content: SizedBox(width: 460, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<int>(value: materialId, decoration: const InputDecoration(labelText: 'Material'), items: _materials.map((e) { final m=e as Map; return DropdownMenuItem<int>(value:m['id'] as int, child:Text('${m['name']} (${m['quantity_on_hand']} ${m['unit']})')); }).toList(), onChanged:(v)=>setLocal(()=>materialId=v!)),
        const SizedBox(height:10), DropdownButtonFormField<String>(value:type, decoration:const InputDecoration(labelText:'Movement'), items:const [DropdownMenuItem(value:'received',child:Text('Receive Stock')),DropdownMenuItem(value:'issued',child:Text('Issue to Project')),DropdownMenuItem(value:'adjustment_in',child:Text('Adjustment In')),DropdownMenuItem(value:'adjustment_out',child:Text('Adjustment Out'))], onChanged:(v)=>setLocal(()=>type=v!)),
        const SizedBox(height:10), DropdownButtonFormField<int?>(value:projectId, decoration:const InputDecoration(labelText:'Project (optional)'), items:[const DropdownMenuItem<int?>(value:null,child:Text('General / Store')), ..._projects.map((e){final p=e as Map; return DropdownMenuItem<int?>(value:p['id'] as int,child:Text('${p['code'] ?? ''} - ${p['name']}'));})], onChanged:(v)=>setLocal(()=>projectId=v)),
        const SizedBox(height:10), TextField(controller:qty,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Quantity')),
        const SizedBox(height:10), TextField(controller:cost,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Unit cost (for received stock)')),
        const SizedBox(height:10), TextField(controller:ref,decoration:const InputDecoration(labelText:'Reference / challan')),
        const SizedBox(height:10), TextField(controller:notes,decoration:const InputDecoration(labelText:'Notes')),
      ]))),
      actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('Record'))],
    )));
    if (ok != true || _num(qty.text) <= 0) return;
    try {
      await _db.rpc('record_material_stock_movement', params:{'p_material_id':materialId,'p_project_id':projectId,'p_type':type,'p_quantity':_num(qty.text),'p_unit_cost':_num(cost.text),'p_reference':ref.text.trim().isEmpty?null:ref.text.trim(),'p_notes':notes.text.trim().isEmpty?null:notes.text.trim()});
      await _load();
    } catch(e) { if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString()))); }
  }

  @override Widget build(BuildContext context) {
    final low = _materials.where((e){final m=e as Map; return _num(m['quantity_on_hand']) <= _num(m['reorder_level']);}).length;
    final value = _materials.fold<double>(0,(s,e){final m=e as Map; return s+_num(m['quantity_on_hand'])*_num(m['average_cost']);});
    return Scaffold(
      appBar:AppBar(title:const Text('Material Inventory'),actions:[IconButton(onPressed:_load,icon:const Icon(Icons.refresh))]),
      floatingActionButton:FloatingActionButton.extended(onPressed:_movement,icon:const Icon(Icons.swap_horiz),label:const Text('Stock Movement')),
      body:_loading?const Center(child:CircularProgressIndicator()):_error!=null?Center(child:Text(_error!)):ListView(padding:const EdgeInsets.all(18),children:[
        Wrap(spacing:10,runSpacing:10,children:[_Stat(label:'Materials',value:'${_materials.length}'),_Stat(label:'Low Stock',value:'$low'),_Stat(label:'Stock Value',value:'PKR ${value.toStringAsFixed(0)}')]),
        const SizedBox(height:18), Text('Current Stock',style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.bold)),
        ..._materials.map((e){final m=Map<String,dynamic>.from(e as Map);final isLow=_num(m['quantity_on_hand'])<=_num(m['reorder_level']);return Card(child:ListTile(leading:Icon(isLow?Icons.warning_amber_outlined:Icons.inventory_2_outlined),title:Text('${m['name']}'),subtitle:Text('${m['sku'] ?? ''} • ${m['location'] ?? 'Store'} • Avg cost PKR ${_num(m['average_cost']).toStringAsFixed(0)}'),trailing:Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.end,children:[Text('${m['quantity_on_hand']} ${m['unit']}',style:const TextStyle(fontWeight:FontWeight.bold)),if(isLow)const Text('LOW STOCK',style:TextStyle(fontSize:11))])));}),
        const SizedBox(height:18), Text('Recent Movements',style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.bold)),
        if(_history.isEmpty)const Card(child:ListTile(title:Text('No stock movements yet'))),
        ..._history.take(30).map((e){final m=Map<String,dynamic>.from(e as Map);final mat=m['materials'] is Map?m['materials'] as Map:<String,dynamic>{};final project=m['projects'] is Map?m['projects'] as Map:<String,dynamic>{};return Card(child:ListTile(leading:Icon('${m['movement_type']}'.contains('received')||'${m['movement_type']}'.contains('_in')?Icons.south_west:Icons.north_east),title:Text('${mat['name'] ?? 'Material'} • ${m['quantity']} ${mat['unit'] ?? ''}'),subtitle:Text('${m['movement_type']} • ${project['name'] ?? 'General store'}${m['reference'] == null ? '' : ' • ${m['reference']}'}')));}),
        const SizedBox(height:80),
      ]),
    );
  }
}

class _Stat extends StatelessWidget { const _Stat({required this.label,required this.value}); final String label,value; @override Widget build(BuildContext context)=>Container(width:180,padding:const EdgeInsets.all(14),decoration:BoxDecoration(border:Border.all(color:Theme.of(context).dividerColor),borderRadius:BorderRadius.circular(14)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(value,style:const TextStyle(fontWeight:FontWeight.bold)),Text(label,style:Theme.of(context).textTheme.bodySmall)])); }
