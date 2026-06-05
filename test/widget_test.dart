import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/main.dart';

void main() {
  testWidgets('La pantalla de login se renderiza', (tester) async {
    await tester.pumpWidget(const ClientePortalApp());

    expect(find.text('Mis Trámites'), findsOneWidget);
    expect(find.text('Ingresar'), findsOneWidget);
  });
}
