import 'dart:typed_data';

import '../pixel_data/encapsulated_pixel_data.dart';
import '../pixel_data/pixel_data_info.dart';
import 'frame_codec.dart';
import 'huffman_table.dart';
import 'jpeg_bit_reader.dart';
import 'jpeg_framing_strategy.dart';
import 'jpeg_markers.dart';

/// Pure-Dart frame decoder for DICOM JPEG Baseline (Process 1, SOF0, 8-bit).
///
/// Transfer Syntax UID: `1.2.840.10008.1.2.4.50`.
///
/// Implements [DicomFrameCodec] per ITU-T T.81 / ISO/IEC 10918-1 Baseline Sequential DCT.
class JpegBaselineDecoder implements DicomFrameCodec {
  /// Creates a [JpegBaselineDecoder] instance.
  const JpegBaselineDecoder();

  static const List<int> _zigZag = <int>[
    0,
    1,
    8,
    16,
    9,
    2,
    3,
    10,
    17,
    24,
    32,
    25,
    18,
    11,
    4,
    5,
    12,
    19,
    26,
    33,
    40,
    48,
    41,
    34,
    27,
    20,
    13,
    6,
    7,
    14,
    21,
    28,
    35,
    42,
    49,
    56,
    57,
    50,
    43,
    36,
    29,
    22,
    15,
    23,
    30,
    37,
    44,
    51,
    58,
    59,
    52,
    45,
    38,
    31,
    39,
    46,
    53,
    60,
    61,
    54,
    47,
    55,
    62,
    63,
  ];

  // Fixed-point IDCT constants (13-bit precision) per standard IJG integer IDCT
  static const int _constBits = 13;
  static const int _pass1Bits = 2;

  static const int _fix0_298631336 = 2446;
  static const int _fix0_390180644 = 3196;
  static const int _fix0_541196100 = 4433;
  static const int _fix0_765366865 = 6270;
  static const int _fix0_899976223 = 7373;
  static const int _fix1_175875602 = 9633;
  static const int _fix1_501321110 = 12299;
  static const int _fix1_847759065 = 15137;
  static const int _fix1_961570560 = 16069;
  static const int _fix2_053119869 = 16819;
  static const int _fix2_562915447 = 20995;
  static const int _fix3_072711026 = 25172;

  @override
  Uint8List extractFramePayload(
    EncapsulatedPixelData encapsulatedData, {
    required int frameIndex,
    required int numberOfFrames,
  }) {
    return JpegFramingStrategy.extractFramePayload(
      encapsulatedData,
      frameIndex: frameIndex,
      numberOfFrames: numberOfFrames,
    );
  }

  @override
  Uint8List decodeFrame({
    required Uint8List frameBytes,
    required PixelDataInfo info,
  }) {
    return decodeJpegStream(
      frameBytes,
      expectedWidth: info.columns,
      expectedHeight: info.rows,
      expectedSamplesPerPixel: info.samplesPerPixel,
    );
  }

  /// Decompresses a standalone Baseline JPEG byte stream into raw uncompressed sample bytes.
  static Uint8List decodeJpegStream(
    Uint8List bytes, {
    int? expectedWidth,
    int? expectedHeight,
    int? expectedSamplesPerPixel,
  }) {
    if (bytes.length < 4) {
      throw const FormatException(
        'JPEG byte stream too short to contain valid headers.',
      );
    }

    if (bytes[0] != 0xFF || bytes[1] != JpegMarker.soi) {
      throw const FormatException('Invalid JPEG: Missing SOI marker (0xFFD8).');
    }

    final quantTables = <int, Int32List>{};
    final dcTables = <int, HuffmanTable>{};
    final acTables = <int, HuffmanTable>{};
    final components = <int, _BaselineComponent>{};
    final componentList = <_BaselineComponent>[];

    int precision = 0;
    int height = 0;
    int width = 0;
    int numComponents = 0;
    int restartInterval = 0;
    int offset = 2;
    int? entropyOffset;

    while (offset < bytes.length) {
      if (bytes[offset] != 0xFF) {
        offset++;
        continue;
      }

      while (offset < bytes.length && bytes[offset] == 0xFF) {
        offset++;
      }

      if (offset >= bytes.length) break;

      final marker = bytes[offset++];

      if (marker == JpegMarker.soi) {
        continue;
      } else if (marker == JpegMarker.eoi) {
        break;
      } else if (marker == JpegMarker.dqt) {
        // Define Quantization Table
        if (offset + 2 > bytes.length) {
          throw const FormatException('Truncated DQT marker segment.');
        }
        final length = (bytes[offset] << 8) | bytes[offset + 1];
        if (offset + length > bytes.length) {
          throw const FormatException('DQT segment exceeds stream bounds.');
        }
        int dqtOffset = offset + 2;
        final dqtEnd = offset + length;
        while (dqtOffset < dqtEnd) {
          final infoByte = bytes[dqtOffset++];
          final pq = infoByte >> 4;
          final tq = infoByte & 0x0F;
          if (pq != 0) {
            throw const FormatException(
              '16-bit quantization tables not supported in Baseline Sequential DCT (Process 1).',
            );
          }
          if (tq < 0 || tq > 3) {
            throw FormatException(
              'Invalid quantization table destination identifier: $tq',
            );
          }
          if (dqtOffset + 64 > dqtEnd) {
            throw const FormatException(
              'Truncated quantization table data in DQT.',
            );
          }
          final qTable = Int32List(64);
          for (int k = 0; k < 64; k++) {
            final naturalIdx = _zigZag[k];
            qTable[naturalIdx] = bytes[dqtOffset + k];
          }
          quantTables[tq] = qTable;
          dqtOffset += 64;
        }
        offset += length;
      } else if (marker == JpegMarker.sof0) {
        // Start of Frame: Baseline DCT
        if (offset + 2 > bytes.length) {
          throw const FormatException('Truncated SOF0 marker segment.');
        }
        final length = (bytes[offset] << 8) | bytes[offset + 1];
        if (offset + length > bytes.length) {
          throw const FormatException('SOF0 segment exceeds stream bounds.');
        }
        precision = bytes[offset + 2];
        height = (bytes[offset + 3] << 8) | bytes[offset + 4];
        width = (bytes[offset + 5] << 8) | bytes[offset + 6];
        numComponents = bytes[offset + 7];

        if (precision != 8) {
          throw FormatException(
            'Unsupported JPEG precision: $precision-bit (Baseline requires 8-bit).',
          );
        }
        if (height <= 0 || width <= 0) {
          throw FormatException('Invalid JPEG dimensions: ${width}x$height.');
        }
        if (numComponents != 1 && numComponents != 3) {
          throw FormatException(
            'Unsupported component count in SOF0: $numComponents (only 1 or 3 supported).',
          );
        }

        int compOffset = offset + 8;
        for (int c = 0; c < numComponents; c++) {
          if (compOffset + 3 > offset + length) {
            throw const FormatException(
              'Truncated component specifications in SOF0.',
            );
          }
          final id = bytes[compOffset];
          final hv = bytes[compOffset + 1];
          final h = hv >> 4;
          final v = hv & 0x0F;
          final qId = bytes[compOffset + 2];

          if (h < 1 || h > 4 || v < 1 || v > 4) {
            throw FormatException(
              'Invalid sampling factors in SOF0: H=$h, V=$v.',
            );
          }

          final comp = _BaselineComponent(
            id: id,
            hFactor: h,
            vFactor: v,
            quantTableId: qId,
          );
          components[id] = comp;
          componentList.add(comp);
          compOffset += 3;
        }
        offset += length;
      } else if (marker == JpegMarker.sof1 ||
          marker == JpegMarker.sof2 ||
          marker == JpegMarker.sof3) {
        throw FormatException(
          'Unsupported JPEG Process (SOF marker 0x${marker.toRadixString(16).toUpperCase()}). '
          'Only Baseline Sequential DCT (SOF0, UID 1.2.840.10008.1.2.4.50) is supported.',
        );
      } else if (marker == JpegMarker.dht) {
        // Define Huffman Table
        if (offset + 2 > bytes.length) {
          throw const FormatException('Truncated DHT marker segment.');
        }
        final length = (bytes[offset] << 8) | bytes[offset + 1];
        if (offset + length > bytes.length) {
          throw const FormatException('DHT segment exceeds stream bounds.');
        }
        int dhtOffset = offset + 2;
        final dhtEnd = offset + length;
        while (dhtOffset < dhtEnd) {
          final infoByte = bytes[dhtOffset++];
          final tableClass = infoByte >> 4;
          final destId = infoByte & 0x0F;

          if (dhtOffset + 16 > dhtEnd) {
            throw const FormatException('Truncated bit length counts in DHT.');
          }
          final bits = bytes.sublist(dhtOffset, dhtOffset + 16);
          dhtOffset += 16;

          int symbolCount = 0;
          for (final b in bits) {
            symbolCount += b;
          }

          if (dhtOffset + symbolCount > dhtEnd) {
            throw const FormatException(
              'Truncated Huffman symbol values in DHT.',
            );
          }
          final huffval = bytes.sublist(dhtOffset, dhtOffset + symbolCount);
          dhtOffset += symbolCount;

          final table = HuffmanTable(
            tableClass: tableClass,
            destinationId: destId,
            bits: bits,
            huffval: huffval,
          );

          if (tableClass == 0) {
            dcTables[destId] = table;
          } else if (tableClass == 1) {
            acTables[destId] = table;
          } else {
            throw FormatException('Invalid Huffman table class: $tableClass');
          }
        }
        offset += length;
      } else if (marker == JpegMarker.dri) {
        // Define Restart Interval
        if (offset + 2 > bytes.length) {
          throw const FormatException('Truncated DRI marker segment.');
        }
        final length = (bytes[offset] << 8) | bytes[offset + 1];
        if (length != 4) {
          throw FormatException(
            'Invalid DRI segment length: $length (expected 4).',
          );
        }
        restartInterval = (bytes[offset + 2] << 8) | bytes[offset + 3];
        offset += length;
      } else if (marker == JpegMarker.sos) {
        // Start of Scan
        if (offset + 2 > bytes.length) {
          throw const FormatException('Truncated SOS marker segment.');
        }
        final length = (bytes[offset] << 8) | bytes[offset + 1];
        if (offset + length > bytes.length) {
          throw const FormatException('SOS segment exceeds stream bounds.');
        }
        final ns = bytes[offset + 2];
        if (ns != numComponents) {
          throw FormatException(
            'Number of components in scan ($ns) does not match SOF0 ($numComponents).',
          );
        }

        int scanOffset = offset + 3;
        for (int i = 0; i < ns; i++) {
          final compId = bytes[scanOffset];
          final tables = bytes[scanOffset + 1];
          final dcId = tables >> 4;
          final acId = tables & 0x0F;

          final comp = components[compId];
          if (comp == null) {
            throw FormatException(
              'Scan component ID $compId not found in SOF0.',
            );
          }
          comp.dcTableId = dcId;
          comp.acTableId = acId;
          scanOffset += 2;
        }

        offset += length;
        entropyOffset = offset;
        break;
      } else if ((marker >= JpegMarker.app0 && marker <= JpegMarker.app15) ||
          marker == JpegMarker.com) {
        // Safely skip Application and Comment segments
        if (offset + 2 > bytes.length) {
          throw const FormatException('Truncated APP/COM segment header.');
        }
        final length = (bytes[offset] << 8) | bytes[offset + 1];
        if (offset + length > bytes.length) {
          throw const FormatException('APP/COM segment exceeds stream bounds.');
        }
        offset += length;
      } else {
        // Other unexpected marker
        if (offset + 2 <= bytes.length) {
          final length = (bytes[offset] << 8) | bytes[offset + 1];
          offset += length;
        } else {
          break;
        }
      }
    }

    if (entropyOffset == null) {
      throw const FormatException(
        'Invalid JPEG: Missing SOS (Start of Scan) marker.',
      );
    }
    if (components.isEmpty) {
      throw const FormatException(
        'Invalid JPEG: Missing SOF0 (Start of Frame) marker.',
      );
    }

    // Verify quantization tables
    for (final comp in componentList) {
      if (!quantTables.containsKey(comp.quantTableId)) {
        throw FormatException(
          'Missing Quantization Table destination index ${comp.quantTableId} referenced by component ${comp.id}.',
        );
      }
      if (!dcTables.containsKey(comp.dcTableId)) {
        throw FormatException(
          'Missing DC Huffman Table destination index ${comp.dcTableId} referenced by component ${comp.id}.',
        );
      }
      if (!acTables.containsKey(comp.acTableId)) {
        throw FormatException(
          'Missing AC Huffman Table destination index ${comp.acTableId} referenced by component ${comp.id}.',
        );
      }
    }

    // Determine MCU dimensions
    int maxH = 1;
    int maxV = 1;
    for (final comp in componentList) {
      if (comp.hFactor > maxH) maxH = comp.hFactor;
      if (comp.vFactor > maxV) maxV = comp.vFactor;
    }

    final mcuWidth = maxH * 8;
    final mcuHeight = maxV * 8;
    final mcusX = (width + mcuWidth - 1) ~/ mcuWidth;
    final mcusY = (height + mcuHeight - 1) ~/ mcuHeight;

    // Allocate internal component sample planes
    final componentPlanes = <_ComponentPlane>[];
    for (final comp in componentList) {
      final planeWidth = mcusX * comp.hFactor * 8;
      final planeHeight = mcusY * comp.vFactor * 8;
      componentPlanes.add(
        _ComponentPlane(
          width: planeWidth,
          height: planeHeight,
          samples: Uint8List(planeWidth * planeHeight),
        ),
      );
    }

    final reader = JpegBitReader(bytes, offset: entropyOffset);
    final dcPredictors = Int32List(numComponents);
    final blockBuffer = Int32List(64);
    final idctOut = Int32List(64);

    int mcuIndex = 0;
    int nextRestart = 0;

    for (int my = 0; my < mcusY; my++) {
      for (int mx = 0; mx < mcusX; mx++) {
        // Handle restart markers
        if (restartInterval > 0 &&
            mcuIndex > 0 &&
            (mcuIndex % restartInterval == 0)) {
          final marker = reader.readRestartMarker();
          final expectedMarker = JpegMarker.rst0 + nextRestart;
          if (marker != expectedMarker) {
            throw FormatException(
              'Invalid restart marker at MCU $mcuIndex: 0x${marker.toRadixString(16).toUpperCase()} '
              '(expected 0x${expectedMarker.toRadixString(16).toUpperCase()}).',
            );
          }
          nextRestart = (nextRestart + 1) % 8;
          dcPredictors.fillRange(0, dcPredictors.length, 0);
        }

        // Decode each component in MCU
        for (int c = 0; c < numComponents; c++) {
          final comp = componentList[c];
          final qTable = quantTables[comp.quantTableId]!;
          final dcTable = dcTables[comp.dcTableId]!;
          final acTable = acTables[comp.acTableId]!;
          final plane = componentPlanes[c];

          for (int v = 0; v < comp.vFactor; v++) {
            for (int h = 0; h < comp.hFactor; h++) {
              blockBuffer.fillRange(0, 64, 0);

              // 1. Decode DC coefficient
              final dcSymbol = dcTable.decode(reader);
              if (dcSymbol > 15) {
                throw FormatException(
                  'Invalid DC magnitude category: $dcSymbol',
                );
              }
              int dcDiff = 0;
              if (dcSymbol > 0) {
                final dcBits = reader.readBits(dcSymbol);
                dcDiff =
                    (dcBits < (1 << (dcSymbol - 1)))
                        ? dcBits - ((1 << dcSymbol) - 1)
                        : dcBits;
              }
              dcPredictors[c] += dcDiff;
              blockBuffer[0] = dcPredictors[c] * qTable[0];

              // 2. Decode AC coefficients (1..63 in zig-zag order)
              int k = 1;
              while (k < 64) {
                final acSymbol = acTable.decode(reader);
                if (acSymbol == 0x00) {
                  // EOB: End of Block
                  break;
                }
                final run = acSymbol >> 4;
                final size = acSymbol & 0x0F;

                if (size == 0) {
                  if (run == 15) {
                    // ZRL: 16 zero coefficients
                    k += 16;
                    continue;
                  } else {
                    throw FormatException(
                      'Invalid AC symbol (size=0, run=$run)',
                    );
                  }
                }

                k += run;
                if (k >= 64) {
                  throw FormatException(
                    'AC coefficient index ($k) exceeded 63.',
                  );
                }

                final acBits = reader.readBits(size);
                final acVal =
                    (acBits < (1 << (size - 1)))
                        ? acBits - ((1 << size) - 1)
                        : acBits;

                final naturalIdx = _zigZag[k];
                blockBuffer[naturalIdx] = acVal * qTable[naturalIdx];
                k++;
              }

              // 3. Inverse Discrete Cosine Transform (IDCT)
              _idct8x8(blockBuffer, idctOut);

              // 4. Store samples into component plane
              final blockX = (mx * comp.hFactor + h) * 8;
              final blockY = (my * comp.vFactor + v) * 8;
              for (int r = 0; r < 8; r++) {
                final planeRowStart = (blockY + r) * plane.width + blockX;
                for (int col = 0; col < 8; col++) {
                  plane.samples[planeRowStart + col] = idctOut[r * 8 + col];
                }
              }
            }
          }
        }

        mcuIndex++;
      }
    }

    // Assemble final output buffer
    if (numComponents == 1) {
      // 1-channel Grayscale (MONOCHROME2 / MONOCHROME1)
      final plane0 = componentPlanes[0];
      final output = Uint8List(width * height);
      for (int y = 0; y < height; y++) {
        final planeRowStart = y * plane0.width;
        final outRowStart = y * width;
        for (int x = 0; x < width; x++) {
          output[outRowStart + x] = plane0.samples[planeRowStart + x];
        }
      }
      return output;
    } else {
      // 3-channel RGB / YBR (Interleaved samples)
      final comp0 = componentList[0];
      final comp1 = componentList[1];
      final comp2 = componentList[2];

      final plane0 = componentPlanes[0];
      final plane1 = componentPlanes[1];
      final plane2 = componentPlanes[2];

      final output = Uint8List(width * height * 3);

      final is111 =
          comp0.hFactor == 1 &&
          comp0.vFactor == 1 &&
          comp1.hFactor == 1 &&
          comp1.vFactor == 1 &&
          comp2.hFactor == 1 &&
          comp2.vFactor == 1;

      if (is111) {
        int outIdx = 0;
        for (int y = 0; y < height; y++) {
          final row0 = y * plane0.width;
          final row1 = y * plane1.width;
          final row2 = y * plane2.width;
          for (int x = 0; x < width; x++) {
            output[outIdx++] = plane0.samples[row0 + x];
            output[outIdx++] = plane1.samples[row1 + x];
            output[outIdx++] = plane2.samples[row2 + x];
          }
        }
      } else {
        // Subsampled chroma (e.g. 4:2:2 or 4:2:0)
        int outIdx = 0;
        for (int y = 0; y < height; y++) {
          final y0 = y * comp0.vFactor ~/ maxV;
          final x0Scale = comp0.hFactor / maxH;
          final row0 = y0 * plane0.width;

          final y1 = y * comp1.vFactor ~/ maxV;
          final x1Scale = comp1.hFactor / maxH;
          final row1 = y1 * plane1.width;

          final y2 = y * comp2.vFactor ~/ maxV;
          final x2Scale = comp2.hFactor / maxH;
          final row2 = y2 * plane2.width;

          for (int x = 0; x < width; x++) {
            final x0 = (x * x0Scale).toInt();
            final x1 = (x * x1Scale).toInt();
            final x2 = (x * x2Scale).toInt();

            output[outIdx++] = plane0.samples[row0 + x0];
            output[outIdx++] = plane1.samples[row1 + x1];
            output[outIdx++] = plane2.samples[row2 + x2];
          }
        }
      }
      return output;
    }
  }

  /// High-accuracy 2D 8x8 Inverse Discrete Cosine Transform (IJG Integer IDCT).
  static void _idct8x8(Int32List input, Int32List output) {
    final ws = Int32List(64);

    // Pass 1: Columns
    for (int col = 0; col < 8; col++) {
      if (input[8 + col] == 0 &&
          input[16 + col] == 0 &&
          input[24 + col] == 0 &&
          input[32 + col] == 0 &&
          input[40 + col] == 0 &&
          input[48 + col] == 0 &&
          input[56 + col] == 0) {
        final dcval = input[col] << _pass1Bits;
        for (int row = 0; row < 8; row++) {
          ws[row * 8 + col] = dcval;
        }
        continue;
      }

      // Even part
      final z2 = input[16 + col];
      final z3 = input[48 + col];
      final z1 = (z2 + z3) * _fix0_541196100;
      final t2 = z1 + z3 * -_fix1_847759065;
      final t3 = z1 + z2 * _fix0_765366865;

      final t0 = (input[col] + input[32 + col]) << _constBits;
      final t1 = (input[col] - input[32 + col]) << _constBits;

      final tmp0 = t0 + t3;
      final tmp3 = t0 - t3;
      final tmp1 = t1 + t2;
      final tmp2 = t1 - t2;

      // Odd part
      final in1 = input[8 + col];
      final in3 = input[24 + col];
      final in5 = input[40 + col];
      final in7 = input[56 + col];

      var z1Odd = in7 + in1;
      var z2Odd = in5 + in3;
      var z3Odd = in7 + in3;
      var z4Odd = in5 + in1;
      final z5 = (z3Odd + z4Odd) * _fix1_175875602;

      var t0Odd = in7 * _fix0_298631336;
      var t1Odd = in5 * _fix2_053119869;
      var t2Odd = in3 * _fix3_072711026;
      var t3Odd = in1 * _fix1_501321110;

      z1Odd = z1Odd * -_fix0_899976223;
      z2Odd = z2Odd * -_fix2_562915447;
      z3Odd = z3Odd * -_fix1_961570560;
      z4Odd = z4Odd * -_fix0_390180644;

      z3Odd += z5;
      z4Odd += z5;

      t0Odd += z1Odd + z3Odd;
      t1Odd += z2Odd + z4Odd;
      t2Odd += z2Odd + z3Odd;
      t3Odd += z1Odd + z4Odd;

      // Combine
      ws[0 * 8 + col] =
          (tmp0 + t3Odd + (1 << (_constBits - _pass1Bits - 1))) >>
          (_constBits - _pass1Bits);
      ws[7 * 8 + col] =
          (tmp0 - t3Odd + (1 << (_constBits - _pass1Bits - 1))) >>
          (_constBits - _pass1Bits);
      ws[1 * 8 + col] =
          (tmp1 + t2Odd + (1 << (_constBits - _pass1Bits - 1))) >>
          (_constBits - _pass1Bits);
      ws[6 * 8 + col] =
          (tmp1 - t2Odd + (1 << (_constBits - _pass1Bits - 1))) >>
          (_constBits - _pass1Bits);
      ws[2 * 8 + col] =
          (tmp2 + t1Odd + (1 << (_constBits - _pass1Bits - 1))) >>
          (_constBits - _pass1Bits);
      ws[5 * 8 + col] =
          (tmp2 - t1Odd + (1 << (_constBits - _pass1Bits - 1))) >>
          (_constBits - _pass1Bits);
      ws[3 * 8 + col] =
          (tmp3 + t0Odd + (1 << (_constBits - _pass1Bits - 1))) >>
          (_constBits - _pass1Bits);
      ws[4 * 8 + col] =
          (tmp3 - t0Odd + (1 << (_constBits - _pass1Bits - 1))) >>
          (_constBits - _pass1Bits);
    }

    // Pass 2: Rows
    for (int row = 0; row < 8; row++) {
      final base = row * 8;

      // Even part
      final z2 = ws[base + 2];
      final z3 = ws[base + 6];
      final z1 = (z2 + z3) * _fix0_541196100;
      final t2 = z1 + z3 * -_fix1_847759065;
      final t3 = z1 + z2 * _fix0_765366865;

      final t0 = (ws[base + 0] + ws[base + 4]) << _constBits;
      final t1 = (ws[base + 0] - ws[base + 4]) << _constBits;

      final tmp0 = t0 + t3;
      final tmp3 = t0 - t3;
      final tmp1 = t1 + t2;
      final tmp2 = t1 - t2;

      // Odd part
      final in1 = ws[base + 1];
      final in3 = ws[base + 3];
      final in5 = ws[base + 5];
      final in7 = ws[base + 7];

      var z1Odd = in7 + in1;
      var z2Odd = in5 + in3;
      var z3Odd = in7 + in3;
      var z4Odd = in5 + in1;
      final z5 = (z3Odd + z4Odd) * _fix1_175875602;

      var t0Odd = in7 * _fix0_298631336;
      var t1Odd = in5 * _fix2_053119869;
      var t2Odd = in3 * _fix3_072711026;
      var t3Odd = in1 * _fix1_501321110;

      z1Odd = z1Odd * -_fix0_899976223;
      z2Odd = z2Odd * -_fix2_562915447;
      z3Odd = z3Odd * -_fix1_961570560;
      z4Odd = z4Odd * -_fix0_390180644;

      z3Odd += z5;
      z4Odd += z5;

      t0Odd += z1Odd + z3Odd;
      t1Odd += z2Odd + z4Odd;
      t2Odd += z2Odd + z3Odd;
      t3Odd += z1Odd + z4Odd;

      const int shift = _constBits + _pass1Bits + 3;
      const int offset = (1 << (shift - 1)) + (128 << shift);

      output[base + 0] = ((tmp0 + t3Odd + offset) >> shift).clamp(0, 255);
      output[base + 7] = ((tmp0 - t3Odd + offset) >> shift).clamp(0, 255);
      output[base + 1] = ((tmp1 + t2Odd + offset) >> shift).clamp(0, 255);
      output[base + 6] = ((tmp1 - t2Odd + offset) >> shift).clamp(0, 255);
      output[base + 2] = ((tmp2 + t1Odd + offset) >> shift).clamp(0, 255);
      output[base + 5] = ((tmp2 - t1Odd + offset) >> shift).clamp(0, 255);
      output[base + 3] = ((tmp3 + t0Odd + offset) >> shift).clamp(0, 255);
      output[base + 4] = ((tmp3 - t0Odd + offset) >> shift).clamp(0, 255);
    }
  }
}

class _BaselineComponent {
  _BaselineComponent({
    required this.id,
    required this.hFactor,
    required this.vFactor,
    required this.quantTableId,
  });

  final int id;
  final int hFactor;
  final int vFactor;
  final int quantTableId;
  int dcTableId = 0;
  int acTableId = 0;
}

class _ComponentPlane {
  _ComponentPlane({
    required this.width,
    required this.height,
    required this.samples,
  });

  final int width;
  final int height;
  final Uint8List samples;
}
