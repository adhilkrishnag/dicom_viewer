import 'package:dicom_viewer/dicom_viewer.dart';
import 'package:flutter_test/flutter_test.dart';

import '../generate_fixture.dart';

void main() {
  group('Multi-Valued Windowing Clinical Presets Tests', () {
    test(
      'DicomDataset correctly exposes multi-valued windowCenterPresets and windowWidthPresets',
      () {
        // Create DICOM with multi-valued DS strings "40\\800" and "400\\2000" (Brain and Bone)
        final bytes = SyntheticDicomGenerator.create(
          width: 16,
          height: 16,
          windowCenterString: r'40\800',
          windowWidthString: r'400\2000',
        );

        final dataset = DicomDataset.fromBytes(bytes);

        expect(dataset.windowCenter, equals(40.0));
        expect(dataset.windowWidth, equals(400.0));

        expect(dataset.windowCenterPresets, equals([40.0, 800.0]));
        expect(dataset.windowWidthPresets, equals([400.0, 2000.0]));
      },
    );
  });
}
