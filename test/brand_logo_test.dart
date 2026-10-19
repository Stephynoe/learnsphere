import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learnsphere/widgets/brand_logo.dart';

void main() {
  for (final width in [320.0, 1280.0]) {
    testWidgets('brand images fit a $width pixel header', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              title: const BrandLogo(height: 36),
              actions: const [
                Icon(Icons.notifications_outlined),
                SizedBox(width: 48),
              ],
            ),
            body: const Column(
              children: [
                BrandLogo(height: 64),
                BrandLogo(symbol: true, height: 28),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final images = tester.widgetList<Image>(find.byType(Image));
      expect(images.length, 3);
      expect(
        images.every((image) => image.semanticLabel == 'LearnSphere'),
        isTrue,
      );
      expect(images.every((image) => image.fit == BoxFit.contain), isTrue);
    });
  }
}
