import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:aegis/main.dart' as app;
import 'package:aegis/models/enums/workplace_screen.dart';
import 'package:aegis/services/app_config.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('App-tests', () {
    testWidgets('Test screens with state', (tester) async {
      WidgetsFlutterBinding.ensureInitialized();
      await AppConfig.load();
      await tester.pumpWidget(const app.Aegis());
      await tester.pumpAndSettle();

      final sideNavEdit = find.byKey(ValueKey(WorkplaceScreen.edit));
      {
        await tester.press(sideNavEdit);
        await tester.pumpAndSettle();

        final editDispositivos = find.byKey(ValueKey("edit_section_Dispositivos"));
        final editGrupos = find.byKey(ValueKey("edit_section_Grupos"));
        final editReglas = find.byKey(ValueKey("edit_section_Reglas"));

        await tester.press(editDispositivos);
        final editDispositivosRouters = find.byKey(ValueKey("edit_section_Routers"));

        await tester.press(editDispositivosRouters);
        final editDispositivosRoutersXochimilco = find.byKey(ValueKey("edit_section_Xochimilco-lan"));
      }
      


    });
  });
}