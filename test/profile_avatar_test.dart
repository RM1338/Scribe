import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:scribe/providers/settings_provider.dart';
import 'package:scribe/screens/profile_screen.dart';
import 'package:scribe/theme/app_theme.dart';
import 'package:scribe/widgets/profile_avatar.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SettingsProvider> _provider([Map<String, Object> prefs = const {}]) async {
  SharedPreferences.setMockInitialValues(prefs);
  return SettingsProvider(await SharedPreferences.getInstance());
}

Future<void> _pump(WidgetTester tester, SettingsProvider settings) {
  return tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: settings,
      child: const MaterialApp(home: Scaffold(body: ProfileAvatar())),
    ),
  );
}

CircleAvatar _avatar(WidgetTester tester) =>
    tester.widget<CircleAvatar>(find.byType(CircleAvatar));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders the swatch the user picked', (tester) async {
    final ochre = AppColors.profileSwatches.last;
    final settings = await _provider({
      'userColorValue': ochre.toARGB32(),
      'userName': 'Ronel',
    });

    await _pump(tester, settings);

    expect(_avatar(tester).backgroundColor, ochre);
    expect(find.text('R'), findsOneWidget);
  });

  testWidgets('falls back to the default swatch, not an off-palette color',
      (tester) async {
    // 0xFF4A9FD9 was the old default: a blue that is not in the swatch list,
    // so the picker could never show it as selected.
    final settings = await _provider({'userColorValue': 0xFF4A9FD9});

    await _pump(tester, settings);

    expect(_avatar(tester).backgroundColor, AppColors.profileSwatches.first);
    expect(find.text('S'), findsOneWidget);
  });

  testWidgets('repaints when the color changes', (tester) async {
    final settings = await _provider({'userName': 'Ronel'});
    await _pump(tester, settings);
    expect(_avatar(tester).backgroundColor, AppColors.profileSwatches.first);

    final terracotta = AppColors.profileSwatches[3];
    settings.userColorValue = terracotta.toARGB32();
    await tester.pump();

    expect(_avatar(tester).backgroundColor, terracotta);
  });

  testWidgets('tapping it opens Edit Profile', (tester) async {
    final settings = await _provider({'userName': 'Ronel'});
    await _pump(tester, settings);
    expect(find.byType(ProfileScreen), findsNothing);

    await tester.tap(find.byType(ProfileAvatar));
    await tester.pumpAndSettle();

    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.text('Edit Profile'), findsOneWidget);
  });

  testWidgets('an explicit onTap overrides the default navigation',
      (tester) async {
    final settings = await _provider();
    var tapped = 0;

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
        child: MaterialApp(
          home: Scaffold(body: ProfileAvatar(onTap: () => tapped++)),
        ),
      ),
    );

    await tester.tap(find.byType(ProfileAvatar));
    await tester.pumpAndSettle();

    expect(tapped, 1);
    expect(find.byType(ProfileScreen), findsNothing);
  });
}
