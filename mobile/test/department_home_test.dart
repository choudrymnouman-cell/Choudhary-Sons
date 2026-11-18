import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/screens/department_home.dart';
import '../lib/services/api_service.dart';

AuthSession session(String role) => AuthSession(token:'test',userId:'1',fullName:'Nouman',email:'test@example.com',role:role);

void main() {
  testWidgets('Owner switches department without changing identity', (tester) async {
    tester.view.physicalSize=const Size(1440,1000);
    tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home:DepartmentHome(session:session('owner'),onLogout:(){})));
    expect(find.text('Owner console'),findsOneWidget);
    await tester.tap(find.text('Human resources'));
    await tester.pumpAndSettle();
    expect(find.text('Employees'),findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is Text && w.data == 'Leave'),findsOneWidget);
    expect(find.text('Client billing'),findsNothing);
    expect(find.text('Owner access • All actions remain under your own account'),findsOneWidget);
    await tester.tap(find.text('Finance & accounts').first);
    await tester.pumpAndSettle();
    expect(find.text('Client billing'),findsOneWidget);
    expect(find.text('Employees'),findsNothing);
  });

  testWidgets('HR only gets assigned department and searchable tasks', (tester) async {
    await tester.pumpWidget(MaterialApp(home:DepartmentHome(session:session('hr'),onLogout:(){})));
    expect(find.byType(DropdownButtonFormField<String>),findsNothing);
    expect(find.text('New purchase order'),findsNothing);
    expect(find.text('Owner console'),findsNothing);
    await tester.enterText(find.byType(TextField),'Leave');
    await tester.pumpAndSettle();
    expect(find.byWidgetPredicate((w) => w is Text && w.data == 'Leave'),findsOneWidget);
    expect(find.text('Employees'),findsNothing);
    expect(tester.takeException(),isNull);
  });
}
