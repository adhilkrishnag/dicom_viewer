import 'package:dicom_viewer_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App launches successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const DicomViewerExampleApp());
    expect(find.text('DICOM Viewer Demo v0.2.0'), findsOneWidget);
  });
}
