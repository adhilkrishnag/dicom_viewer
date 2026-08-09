import 'package:dicom_viewer_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App launches successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const DicomViewerExampleApp());
    expect(find.text('dicom_viewer v0.1.0'), findsOneWidget);
  });
}
