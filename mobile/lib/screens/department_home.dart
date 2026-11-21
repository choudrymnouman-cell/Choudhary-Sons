import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'owner_console.dart';
import 'documents_screen.dart';
import 'tender_register.dart';
import 'management_lists.dart';
import 'recruitment_pipeline_screen.dart';
import 'operations_create_forms.dart';
import 'material_stock_screen.dart';
import 'supplier_purchase_screen.dart';
import 'client_receivables_screen.dart';
import 'project_financial_screen.dart';
import 'boq_management_screen.dart';
import 'project_schedule.dart';
import 'safety_workspace.dart';
import 'requisition_workspace.dart';

const departmentNames = <String, String>{
  'owner': 'Owner command center', 'hr': 'Human resources',
  'accountant': 'Finance & accounts', 'procurement': 'Procurement',
  'store': 'Stores & inventory', 'project_manager': 'Project management',
  'site_supervisor': 'Site operations', 'estimator': 'Bidding & estimation',
  'equipment': 'Equipment & fleet', 'admin': 'Administration',
  'employee': 'Employee', 'pending': 'Awaiting assignment', 'applicant': 'Applicant',
};
const departmentIcons = <String, IconData>{
  'owner': Icons.dashboard_outlined, 'hr': Icons.people_outline,
  'accountant': Icons.account_balance_outlined, 'procurement': Icons.shopping_cart_outlined,
  'store': Icons.inventory_2_outlined, 'project_manager': Icons.apartment_outlined,
  'site_supervisor': Icons.engineering_outlined, 'estimator': Icons.calculate_outlined,
  'equipment': Icons.precision_manufacturing_outlined, 'admin': Icons.business_outlined,
};

class DepartmentHome extends StatefulWidget {
  const DepartmentHome({super.key, required this.session, required this.onLogout});
  final AuthSession session;
  final VoidCallback onLogout;
  @override State<DepartmentHome> createState() => _DepartmentHomeState();
}
class _DepartmentHomeState extends State<DepartmentHome> {
  late String selected = widget.session.role;
  String query = '';
  final api = ApiService();
  bool get owner => widget.session.role == 'owner';
  void open(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  List<_Task> tasks() {
    final s = widget.session;
    _Task list(String title, String note, IconData icon) => _Task(title, note, icon, () => open(ManagementListScreen(session:s,type:title)));
    _Task form(String title, String note, IconData icon, String type) => _Task(title,note,icon,()=>open(OperationsCreateScreen(session:s,type:type)));
    _Task records(String title, String note, IconData icon, Future<List<dynamic>> Function() load) => _Task(title,note,icon,()=>open(DepartmentRecords(title:title,load:load)));
    final t = s.token;
    switch(selected) {
      case 'owner': return [
        _Task('Document vault','Upload and retrieve company documents.',Icons.folder_outlined,()=>open(DocumentsScreen(session:s))),
        _Task('Owner console','Approve requests, assign roles and review company activity.',Icons.admin_panel_settings_outlined,()=>open(OwnerConsole(session:s))),
        _Task('Tender register','Track bids, deadlines and projected margins.',Icons.assignment_outlined,()=>open(TenderRegister(api:OwnerHttp(t)))),
      ];
      case 'hr': return [
        list('Employees','Maintain employee profiles and workforce records.',Icons.badge_outlined),
        list('Attendance','Review daily check-ins and attendance.',Icons.fact_check_outlined),
        list('Leave','Review and approve leave requests.',Icons.event_available_outlined),
        list('Payroll','Prepare wages, allowances and deductions.',Icons.payments_outlined),
        _Task('Recruitment','Manage jobs, applicants and hiring stages.',Icons.person_search_outlined,()=>open(RecruitmentPipelineScreen(session:s))),
        form('Post a notice','Share an announcement with the team.',Icons.campaign_outlined,'Notice'),
      ];
      case 'accountant': return [
        _Task('Client billing','Review invoices, collect payments and track dues.',Icons.receipt_long_outlined,()=>open(ClientReceivablesScreen(session:s))),
        _Task('Supplier payments','Record vendor payments and submit for approval.',Icons.account_balance_wallet_outlined,()=>open(SupplierPurchaseScreen(session:s))),
        _Task('Project finances','Review costs, billing and project margins.',Icons.insights_outlined,()=>open(ProjectFinancialScreen(session:s))),
        list('Payroll','Calculate and review employee pay.',Icons.payments_outlined),
        form('New invoice','Create a bill for a client.',Icons.add_card_outlined,'Invoice'),
        form('Record expense','Record a project cost.',Icons.money_off_outlined,'Expense'),
        form('Add client','Register a new billing client.',Icons.person_add_outlined,'Client'),
      ];
      case 'procurement': return [
        if (selfHostedWeb) _Task('Material requests','Follow site requests through procurement and owner approval.',Icons.playlist_add_check,()=>open(RequisitionWorkspace(session:s))),
        _Task('Purchases & deliveries','Review suppliers, purchase orders and deliveries.',Icons.local_shipping_outlined,()=>open(SupplierPurchaseScreen(session:s,showFinance:false))),
        form('New purchase order','Request a purchase; high values go to the owner.',Icons.shopping_cart_checkout_outlined,'Purchase Order'),
        form('Add supplier','Maintain your supplier directory.',Icons.storefront_outlined,'Supplier'),
        form('Receive delivery','Record received material against a purchase order.',Icons.move_to_inbox_outlined,'Delivery'),
        form('Add material','Create a material and reorder level.',Icons.add_box_outlined,'Material'),
      ];
      case 'store': return [
        if (selfHostedWeb) _Task('Material requests','Follow site requests through procurement and owner approval.',Icons.playlist_add_check,()=>open(RequisitionWorkspace(session:s))),
        _Task('Material stock','Receive, issue and track inventory movements.',Icons.inventory_2_outlined,()=>open(MaterialStockScreen(session:s))),
        form('Receive delivery','Receive material into inventory.',Icons.move_to_inbox_outlined,'Delivery'),
        form('Add material','Create a new stock item.',Icons.add_box_outlined,'Material'),
      ];
      case 'estimator': return [
        _Task('Tender register','Create bids and follow upcoming deadlines.',Icons.assignment_outlined,()=>open(TenderRegister(api:OwnerHttp(t)))),
        _Task('Bill of quantities','Maintain quantities, rates and estimated costs.',Icons.calculate_outlined,()=>open(BoqManagementScreen(session:s))),
        records('Material rates','Review the material catalogue and average costs.',Icons.price_change_outlined,()=>api.materials(t)),
      ];
      case 'project_manager': return [
        if (selfHostedWeb) _Task('Material requests','Follow site requests through procurement and owner approval.',Icons.playlist_add_check,()=>open(RequisitionWorkspace(session:s))),
        if (selfHostedWeb) _Task('Tasks & milestones','Plan site targets and update work progress.',Icons.view_timeline_outlined,()=>open(ProjectSchedule(session:s))),
        if (selfHostedWeb) _Task('Quality & safety','Inspect sites and resolve reported incidents.',Icons.health_and_safety_outlined,()=>open(SafetyWorkspace(session:s))),
        list('Projects','Create projects and maintain their lifecycle.',Icons.apartment_outlined),
        _Task('Bill of quantities','Track quantities and executed work.',Icons.calculate_outlined,()=>open(BoqManagementScreen(session:s))),
        records('Daily reports','Review work done, weather and delays.',Icons.description_outlined,()=>api.siteReports(t)),
        form('New site report','Record today’s progress.',Icons.note_add_outlined,'Site Report'),
        records('Safety incidents','Review site safety records.',Icons.health_and_safety_outlined,()=>api.safetyIncidents(t)),
      ];
      case 'site_supervisor': return [
        if (selfHostedWeb) _Task('Material requests','Follow site requests through procurement and owner approval.',Icons.playlist_add_check,()=>open(RequisitionWorkspace(session:s))),
        if (selfHostedWeb) _Task('Tasks & milestones','Update progress against your assigned site targets.',Icons.view_timeline_outlined,()=>open(ProjectSchedule(session:s))),
        if (selfHostedWeb) _Task('Quality & safety','Report incidents and record site inspections.',Icons.health_and_safety_outlined,()=>open(SafetyWorkspace(session:s))),
        list('Attendance','Review site attendance.',Icons.fact_check_outlined),
        form('Daily site report','Record work, weather and delays.',Icons.note_add_outlined,'Site Report'),
        records('Site reports','Review submitted progress reports.',Icons.description_outlined,()=>api.siteReports(t)),
        form('Report an incident','Record a safety incident.',Icons.health_and_safety_outlined,'Safety Incident'),
      ];
      case 'equipment': return [
        if (selfHostedWeb) records('Service alerts','Equipment due for service by date or meter reading.',Icons.notification_important_outlined,()=>WorkspaceHttp(t).list('/assets/maintenance-due')),
        if (selfHostedWeb) records('Fuel history','Review fuel quantities, meter readings and costs.',Icons.local_gas_station_outlined,()=>WorkspaceHttp(t).list('/assets/fuel')),
        if (selfHostedWeb) records('Service history','Review completed maintenance and next service dates.',Icons.build_circle_outlined,()=>WorkspaceHttp(t).list('/assets/maintenance')),

        records('Equipment register','View machinery, vehicles and their status.',Icons.precision_manufacturing_outlined,()=>api.assets(t)),
        form('Add equipment','Register a machine or vehicle.',Icons.add_circle_outline,'Asset'),
        form('Fuel log','Record fuel quantity and cost.',Icons.local_gas_station_outlined,'Fuel Log'),
        form('Maintenance log','Record servicing and maintenance costs.',Icons.build_outlined,'Maintenance'),
      ];
      case 'admin': return [
        list('Employees','Manage workforce records.',Icons.people_outline),
        list('Leave','Review staff leave requests.',Icons.event_available_outlined),
        _Task('Recruitment','Manage recruitment and applications.',Icons.person_search_outlined,()=>open(RecruitmentPipelineScreen(session:s))),
        form('Post a notice','Share a company announcement.',Icons.campaign_outlined,'Notice'),
      ];
      default: return [];
    }
  }
  Widget navigation() => Padding(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    const Icon(Icons.apartment_rounded,size:36,color:Color(0xFF67D5B5)),const SizedBox(height:14),
    const Text('CHOUDHARY\n& SONS',style:TextStyle(color:Colors.white,fontSize:23,fontWeight:FontWeight.w800,letterSpacing:1.2)),
    const SizedBox(height:8),const Text('Company workspace',style:TextStyle(color:Colors.white60)),const SizedBox(height:32),
    Text(owner?'OPEN AS DEPARTMENT':'YOUR DEPARTMENT',style:const TextStyle(color:Colors.white54,fontSize:11,letterSpacing:1.5)),const SizedBox(height:12),
    Expanded(child:ListView(children:[for(final key in owner?departmentIcons.keys:[widget.session.role]) Padding(padding:const EdgeInsets.only(bottom:6),child:ListTile(
      shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12)),selected:key==selected,selectedTileColor:Colors.white.withValues(alpha:.12),
      leading:Icon(departmentIcons[key]??Icons.work_outline,color:key==selected?const Color(0xFF67D5B5):Colors.white60),
      title:Text(departmentNames[key]??key,style:TextStyle(color:key==selected?Colors.white:Colors.white70,fontSize:13)),
      onTap:()=>setState((){selected=key;query='';}),
    ))])),
    const Divider(color:Colors.white24),ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.logout,color:Colors.white70),title:const Text('Sign out',style:TextStyle(color:Colors.white70)),onTap:widget.onLogout),
  ]));
  @override Widget build(BuildContext context) {
    final items = tasks().where((e)=>'${e.title} ${e.note}'.toLowerCase().contains(query.toLowerCase())).toList();
    return Scaffold(body:LayoutBuilder(builder:(context,c){
      final wide=c.maxWidth>=1000;
      return Row(children:[if(wide)SizedBox(width:255,child:Material(color:const Color(0xFF102D29),child:navigation())),Expanded(child:CustomScrollView(slivers:[
        SliverToBoxAdapter(child:Padding(padding:EdgeInsets.all(wide?32:18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[Expanded(child:Text('Choudhary & Sons / ${departmentNames[selected]??selected}',style:const TextStyle(color:Color(0xFF627570)))),
            if(!wide)IconButton(tooltip:'Sign out',onPressed:widget.onLogout,icon:const Icon(Icons.logout)),
            CircleAvatar(backgroundColor:const Color(0xFFDCEEE7),child:Text(widget.session.fullName.isEmpty?'U':widget.session.fullName[0].toUpperCase())),
          ]),const SizedBox(height:28),
          Text('Welcome, ${widget.session.fullName}',style:Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight:FontWeight.w800,color:const Color(0xFF173D34))),const SizedBox(height:8),
          Text(owner?'One account. Every department. Choose where you want to work.':'Your department’s work, organised in one place.'),const SizedBox(height:24),
          if(!wide && owner) DropdownButtonFormField<String>(initialValue:selected,decoration:const InputDecoration(labelText:'Open as department'),items:[for(final k in departmentIcons.keys)DropdownMenuItem(value:k,child:Text(departmentNames[k]!))],onChanged:(v)=>setState((){selected=v!;query='';})),
          if(!wide && owner)const SizedBox(height:20),
          Container(width:double.infinity,padding:const EdgeInsets.all(24),decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFF145B48),Color(0xFF247E65)]),borderRadius:BorderRadius.circular(22)),child:Row(children:[
            Icon(departmentIcons[selected]??Icons.work_outline,color:const Color(0xFFB6F2DE),size:40),const SizedBox(width:20),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(departmentNames[selected]??selected,style:const TextStyle(color:Colors.white,fontSize:24,fontWeight:FontWeight.w700)),const SizedBox(height:6),Text(owner?'Owner access • All actions remain under your own account':'Access assigned by your company owner',style:const TextStyle(color:Colors.white70))])),
          ])),const SizedBox(height:24),
          TextField(key:ValueKey(selected),decoration:const InputDecoration(hintText:'Find a task in this department',prefixIcon:Icon(Icons.search)),onChanged:(v)=>setState(()=>query=v)),const SizedBox(height:24),
          Text('What would you like to do?',style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w700)),
        ]))),
        SliverPadding(padding:EdgeInsets.fromLTRB(wide?32:18,0,wide?32:18,32),sliver:SliverLayoutBuilder(builder:(context,constraints)=>SliverGrid(delegate:SliverChildBuilderDelegate((context,i){final item=items[i];return Card(clipBehavior:Clip.antiAlias,child:InkWell(onTap:item.tap,child:Padding(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Container(padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:const Color(0xFFEAF4EF),borderRadius:BorderRadius.circular(12)),child:Icon(item.icon,color:const Color(0xFF145B48))),const SizedBox(height:14),Text(item.title,style:const TextStyle(fontSize:17,fontWeight:FontWeight.w700)),const SizedBox(height:6),Expanded(child:Text(item.note,style:const TextStyle(color:Color(0xFF627570)))),const Row(children:[Text('Open workspace',style:TextStyle(color:Color(0xFF145B48),fontWeight:FontWeight.w600)),Spacer(),Icon(Icons.arrow_forward,size:18,color:Color(0xFF145B48))])]))));},childCount:items.length),gridDelegate:SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:constraints.crossAxisExtent>1000?3:constraints.crossAxisExtent>600?2:1,mainAxisExtent:240,crossAxisSpacing:16,mainAxisSpacing:16)))),
        if(items.isEmpty)const SliverToBoxAdapter(child:Padding(padding:EdgeInsets.all(24),child:Text('No matching tasks. Try another search.'))),
      ]))]);
    }));
  }
}
class _Task {const _Task(this.title,this.note,this.icon,this.tap);final String title,note;final IconData icon;final VoidCallback tap;}

class DepartmentRecords extends StatefulWidget {
  const DepartmentRecords({super.key,required this.title,required this.load});
  final String title;
  final Future<List<dynamic>> Function() load;
  @override State<DepartmentRecords> createState()=>_DepartmentRecordsState();
}
class _DepartmentRecordsState extends State<DepartmentRecords>{
  late Future<List<dynamic>> data=widget.load();String query='';
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(widget.title),actions:[IconButton(tooltip:'Refresh',onPressed:()=>setState(()=>data=widget.load()),icon:const Icon(Icons.refresh))]),body:Column(children:[Padding(padding:const EdgeInsets.all(18),child:TextField(decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'Search records'),onChanged:(v)=>setState(()=>query=v.toLowerCase()))),Expanded(child:FutureBuilder<List<dynamic>>(future:data,builder:(context,s){if(s.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());if(s.hasError)return Center(child:Column(mainAxisSize:MainAxisSize.min,children:[const Text('Could not load records. Please retry.'),TextButton(onPressed:()=>setState(()=>data=widget.load()),child:const Text('Retry'))]));final rows=(s.data??[]).where((r)=>r.toString().toLowerCase().contains(query)).toList();if(rows.isEmpty)return const Center(child:Text('No records to show.'));return ListView.separated(padding:const EdgeInsets.all(18),itemCount:rows.length,separatorBuilder:(_,__)=>const SizedBox(height:10),itemBuilder:(context,i){final r=Map<String,dynamic>.from(rows[i] as Map);return Card(child:ExpansionTile(title:Text('${r['name']??r['title']??r['report_date']??r['id']}'),subtitle:Text('${r['status']??r['description']??r['work_done']??''}',maxLines:2,overflow:TextOverflow.ellipsis),children:[for(final e in r.entries.where((e)=>e.value!=null))ListTile(dense:true,title:Text(e.key.replaceAll('_',' ')),subtitle:Text('${e.value}'))]));});}))]));
}
