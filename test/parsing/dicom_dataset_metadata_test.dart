import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dicom_viewer/dicom_viewer.dart';
import 'package:flutter_test/flutter_test.dart';

DicomDataElement _strElem(DicomTag tag, ValueRepresentation vr, String value) {
  final bytes = Uint8List.fromList(utf8.encode(value));
  return DicomDataElement(
    tag: tag,
    vr: vr,
    valueLength: bytes.length,
    valueBytes: bytes,
  );
}

void main() {
  group('DicomDataset Metadata Tests (v0.3.0 Scope)', () {
    test('All metadata getters return expected values when present', () {
      final dataset = DicomDataset([
        _strElem(
          DicomTag.studyInstanceUid,
          ValueRepresentation.ui,
          '1.2.840.113619.2.55.1.1',
        ),
        _strElem(DicomTag.studyTime, ValueRepresentation.tm, '134530.123456'),
        _strElem(
          DicomTag.seriesInstanceUid,
          ValueRepresentation.ui,
          '1.2.840.113619.2.55.1.2',
        ),
        _strElem(DicomTag.seriesNumber, ValueRepresentation.isVR, '3'),
        _strElem(
          DicomTag.sopClassUid,
          ValueRepresentation.ui,
          '1.2.840.10008.5.1.4.1.1.2',
        ),
        _strElem(
          DicomTag.sopInstanceUid,
          ValueRepresentation.ui,
          '1.2.840.113619.2.55.1.2.1',
        ),
        _strElem(DicomTag.instanceNumber, ValueRepresentation.isVR, '42'),
        _strElem(DicomTag.acquisitionDate, ValueRepresentation.da, '20231115'),
        _strElem(
          DicomTag.acquisitionTime,
          ValueRepresentation.tm,
          '134600.000000',
        ),
        _strElem(
          DicomTag.institutionName,
          ValueRepresentation.lo,
          'General Hospital',
        ),
        _strElem(
          DicomTag.manufacturer,
          ValueRepresentation.lo,
          'Acme Medical Systems',
        ),
        _strElem(DicomTag.sliceThickness, ValueRepresentation.ds, '2.5'),
        _strElem(
          DicomTag.pixelSpacing,
          ValueRepresentation.ds,
          '0.703125\\0.703125',
        ),
      ]);

      expect(dataset.studyInstanceUid, '1.2.840.113619.2.55.1.1');
      expect(dataset.studyTime, '134530.123456');
      expect(dataset.seriesInstanceUid, '1.2.840.113619.2.55.1.2');
      expect(dataset.seriesNumber, 3);
      expect(dataset.sopClassUid, '1.2.840.10008.5.1.4.1.1.2');
      expect(dataset.sopInstanceUid, '1.2.840.113619.2.55.1.2.1');
      expect(dataset.instanceNumber, 42);
      expect(dataset.acquisitionDate, '20231115');
      expect(dataset.acquisitionTime, '134600.000000');
      expect(dataset.institutionName, 'General Hospital');
      expect(dataset.manufacturer, 'Acme Medical Systems');
      expect(dataset.sliceThickness, 2.5);
      expect(dataset.pixelSpacing, [0.703125, 0.703125]);
    });

    test('All new metadata getters return null when attributes are absent', () {
      final dataset = DicomDataset([]);

      expect(dataset.studyInstanceUid, isNull);
      expect(dataset.studyTime, isNull);
      expect(dataset.seriesInstanceUid, isNull);
      expect(dataset.seriesNumber, isNull);
      expect(dataset.sopClassUid, isNull);
      expect(dataset.sopInstanceUid, isNull);
      expect(dataset.instanceNumber, isNull);
      expect(dataset.acquisitionDate, isNull);
      expect(dataset.acquisitionTime, isNull);
      expect(dataset.institutionName, isNull);
      expect(dataset.manufacturer, isNull);
      expect(dataset.sliceThickness, isNull);
      expect(dataset.pixelSpacing, isNull);
      expect(dataset.getDoubleList(DicomTag.windowCenter), isNull);
      expect(dataset.getStringList(DicomTag.studyDescription), isNull);
    });

    group('Pixel Spacing strict two-value semantics', () {
      test('valid identical spacing: "0.75\\0.75" -> [0.75, 0.75]', () {
        final dataset = DicomDataset([
          _strElem(DicomTag.pixelSpacing, ValueRepresentation.ds, '0.75\\0.75'),
        ]);
        expect(dataset.pixelSpacing, [0.75, 0.75]);
      });

      test('valid anisotropic spacing: "1.25\\0.85" -> [1.25, 0.85]', () {
        final dataset = DicomDataset([
          _strElem(DicomTag.pixelSpacing, ValueRepresentation.ds, '1.25\\0.85'),
        ]);
        expect(dataset.pixelSpacing, [1.25, 0.85]);
      });

      test('single value is malformed -> returns null', () {
        final dataset = DicomDataset([
          _strElem(DicomTag.pixelSpacing, ValueRepresentation.ds, '0.75'),
        ]);
        expect(dataset.pixelSpacing, isNull);
      });

      test('three values is malformed -> returns null', () {
        final dataset = DicomDataset([
          _strElem(
            DicomTag.pixelSpacing,
            ValueRepresentation.ds,
            '0.75\\0.75\\0.75',
          ),
        ]);
        expect(dataset.pixelSpacing, isNull);
      });

      test('second value malformed: "0.75\\INVALID" -> returns null', () {
        final dataset = DicomDataset([
          _strElem(
            DicomTag.pixelSpacing,
            ValueRepresentation.ds,
            '0.75\\INVALID',
          ),
        ]);
        expect(dataset.pixelSpacing, isNull);
      });

      test('first value malformed: "INVALID\\0.75" -> returns null', () {
        final dataset = DicomDataset([
          _strElem(
            DicomTag.pixelSpacing,
            ValueRepresentation.ds,
            'INVALID\\0.75',
          ),
        ]);
        expect(dataset.pixelSpacing, isNull);
      });

      test('both values malformed: "INVALID\\INVALID" -> returns null', () {
        final dataset = DicomDataset([
          _strElem(
            DicomTag.pixelSpacing,
            ValueRepresentation.ds,
            'INVALID\\INVALID',
          ),
        ]);
        expect(dataset.pixelSpacing, isNull);
      });

      test('empty value -> returns null', () {
        final dataset = DicomDataset([
          _strElem(DicomTag.pixelSpacing, ValueRepresentation.ds, ''),
        ]);
        expect(dataset.pixelSpacing, isNull);
      });
    });

    group('Numeric parsing and graceful error handling', () {
      test('valid integer strings for seriesNumber and instanceNumber', () {
        final dataset = DicomDataset([
          _strElem(DicomTag.seriesNumber, ValueRepresentation.isVR, ' 12 '),
          _strElem(DicomTag.instanceNumber, ValueRepresentation.isVR, '0045'),
        ]);
        expect(dataset.seriesNumber, 12);
        expect(dataset.instanceNumber, 45);
      });

      test('malformed integer strings return null gracefully', () {
        final dataset = DicomDataset([
          _strElem(DicomTag.seriesNumber, ValueRepresentation.isVR, 'ABC'),
          _strElem(
            DicomTag.instanceNumber,
            ValueRepresentation.isVR,
            'NOT_A_NUM',
          ),
        ]);
        expect(dataset.seriesNumber, isNull);
        expect(dataset.instanceNumber, isNull);
      });

      test('valid decimal string for sliceThickness', () {
        final dataset = DicomDataset([
          _strElem(DicomTag.sliceThickness, ValueRepresentation.ds, '3.75'),
        ]);
        expect(dataset.sliceThickness, 3.75);
      });

      test(
        'malformed decimal string for sliceThickness returns null gracefully',
        () {
          final dataset = DicomDataset([
            _strElem(
              DicomTag.sliceThickness,
              ValueRepresentation.ds,
              'INVALID_DS',
            ),
          ]);
          expect(dataset.sliceThickness, isNull);
        },
      );
    });

    group('SOP UID semantics & distinct tag isolation', () {
      test(
        'sopClassUid and sopInstanceUid do NOT fallback to MediaStorage UIDs',
        () {
          // Dataset contains ONLY Media Storage tags in Group 0002, and NO Group 0008 SOP tags
          final dataset = DicomDataset([
            _strElem(
              DicomTag.mediaStorageSopClassUid,
              ValueRepresentation.ui,
              '1.2.840.10008.5.1.4.1.1.2',
            ),
            _strElem(
              DicomTag.mediaStorageSopInstanceUid,
              ValueRepresentation.ui,
              '1.2.840.113619.2.55.1.2.1',
            ),
          ]);

          // Must return null, NOT the media storage UIDs
          expect(dataset.sopClassUid, isNull);
          expect(dataset.sopInstanceUid, isNull);

          // Explicit lookup of media storage tags still works
          expect(
            dataset.getString(DicomTag.mediaStorageSopClassUid),
            '1.2.840.10008.5.1.4.1.1.2',
          );
          expect(
            dataset.getString(DicomTag.mediaStorageSopInstanceUid),
            '1.2.840.113619.2.55.1.2.1',
          );
        },
      );

      test(
        'sopClassUid and sopInstanceUid read directly from Group 0008 tags',
        () {
          final dataset = DicomDataset([
            _strElem(
              DicomTag.sopClassUid,
              ValueRepresentation.ui,
              '1.2.840.10008.5.1.4.1.1.4',
            ),
            _strElem(
              DicomTag.sopInstanceUid,
              ValueRepresentation.ui,
              '1.2.840.113619.2.55.9.9.9',
            ),
            _strElem(
              DicomTag.mediaStorageSopClassUid,
              ValueRepresentation.ui,
              'DIFFERENT_CLASS_UID',
            ),
            _strElem(
              DicomTag.mediaStorageSopInstanceUid,
              ValueRepresentation.ui,
              'DIFFERENT_INSTANCE_UID',
            ),
          ]);

          expect(dataset.sopClassUid, '1.2.840.10008.5.1.4.1.1.4');
          expect(dataset.sopInstanceUid, '1.2.840.113619.2.55.9.9.9');
        },
      );
    });

    group('Generic list helpers', () {
      test('getDoubleList returns parsed list or null', () {
        final dataset = DicomDataset([
          _strElem(DicomTag.windowCenter, ValueRepresentation.ds, '40\\800'),
        ]);
        expect(dataset.getDoubleList(DicomTag.windowCenter), [40.0, 800.0]);
        expect(dataset.getDoubleList(DicomTag.windowWidth), isNull);
      });

      test('getStringList returns parsed list or null', () {
        final dataset = DicomDataset([
          _strElem(
            DicomTag.studyDescription,
            ValueRepresentation.lo,
            'HEAD\\BRAIN\\CONTRAST',
          ),
        ]);
        expect(dataset.getStringList(DicomTag.studyDescription), [
          'HEAD',
          'BRAIN',
          'CONTRAST',
        ]);
        expect(dataset.getStringList(DicomTag.seriesDescription), isNull);
      });
    });

    group('Real DICOM Fixtures metadata verification', () {
      test('CT_small.dcm metadata verification', () async {
        final file = File('test/fixtures/CT_small.dcm');
        final bytes = await file.readAsBytes();
        final dataset = DicomDataset.fromBytes(bytes);

        expect(dataset.modality, 'CT');
        expect(dataset.rows, 128);
        expect(dataset.columns, 128);
        expect(dataset.bitsAllocated, 16);
        expect(dataset.rescaleSlope, 1.0);
        expect(dataset.rescaleIntercept, -1024.0);

        // Check metadata getters on CT_small.dcm
        expect(dataset.sopClassUid, isNotNull);
        expect(dataset.sopInstanceUid, isNotNull);
        expect(dataset.studyInstanceUid, isNotNull);
        expect(dataset.seriesInstanceUid, isNotNull);
      });

      test('MR_small.dcm metadata verification', () async {
        final file = File('test/fixtures/MR_small.dcm');
        final bytes = await file.readAsBytes();
        final dataset = DicomDataset.fromBytes(bytes);

        expect(dataset.modality, 'MR');
        expect(dataset.rows, 64);
        expect(dataset.columns, 64);
        expect(dataset.bitsAllocated, 16);
        expect(dataset.sopClassUid, isNotNull);
        expect(dataset.sopInstanceUid, isNotNull);
      });

      test(
        'OBXXXX1A_rle_2frame.dcm multi-frame RLE metadata verification',
        () async {
          final file = File('test/fixtures/rle/OBXXXX1A_rle_2frame.dcm');
          final bytes = await file.readAsBytes();
          final dataset = DicomDataset.fromBytes(bytes);

          expect(dataset.numberOfFrames, 2);
          expect(dataset.rows, 600);
          expect(dataset.columns, 800);
          expect(dataset.photometricInterpretation, 'PALETTE COLOR');
          expect(dataset.sopClassUid, isNotNull);
          expect(dataset.sopInstanceUid, isNotNull);
        },
      );

      test(
        'emri_small_RLE.dcm multi-frame RLE metadata verification',
        () async {
          final file = File('test/fixtures/rle/emri_small_RLE.dcm');
          final bytes = await file.readAsBytes();
          final dataset = DicomDataset.fromBytes(bytes);

          expect(dataset.numberOfFrames, 10);
          expect(dataset.rows, 64);
          expect(dataset.columns, 64);
          expect(dataset.photometricInterpretation, 'MONOCHROME2');
          expect(dataset.sopClassUid, isNotNull);
          expect(dataset.sopInstanceUid, isNotNull);
        },
      );
    });

    group('Existing behavior regression tests', () {
      test(
        'all existing 27 DicomDataset getters retain expected behavior and defaults',
        () {
          final emptyDataset = DicomDataset([]);

          expect(
            emptyDataset.transferSyntaxUid,
            TransferSyntax.explicitVRLittleEndian,
          );
          expect(emptyDataset.patientName, 'Anonymous');
          expect(emptyDataset.patientId, '');
          expect(emptyDataset.studyDate, '');
          expect(emptyDataset.modality, 'UNKNOWN');
          expect(emptyDataset.studyDescription, '');
          expect(emptyDataset.seriesDescription, '');
          expect(emptyDataset.numberOfFrames, 1);
          expect(emptyDataset.rows, 0);
          expect(emptyDataset.columns, 0);
          expect(emptyDataset.samplesPerPixel, 1);
          expect(emptyDataset.bitsAllocated, 16);
          expect(emptyDataset.bitsStored, 16);
          expect(emptyDataset.highBit, 15);
          expect(emptyDataset.planarConfiguration, 0);
          expect(emptyDataset.pixelPaddingValue, isNull);
          expect(emptyDataset.pixelPaddingRangeLimit, isNull);
          expect(emptyDataset.isLittleEndian, isTrue);
          expect(emptyDataset.pixelRepresentation, 0);
          expect(emptyDataset.isSigned, isFalse);
          expect(emptyDataset.photometricInterpretation, 'MONOCHROME2');
          expect(emptyDataset.rescaleSlope, 1.0);
          expect(emptyDataset.rescaleIntercept, 0.0);
          expect(emptyDataset.windowCenter, isNull);
          expect(emptyDataset.windowWidth, isNull);
          expect(emptyDataset.windowCenterPresets, isEmpty);
          expect(emptyDataset.windowWidthPresets, isEmpty);
          expect(emptyDataset.encapsulatedData, isNull);
          expect(emptyDataset.pixelDataBytes, isNull);
        },
      );
    });
  });
}
