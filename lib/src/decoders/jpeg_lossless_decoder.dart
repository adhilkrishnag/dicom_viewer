import 'dart:typed_data';

import '../pixel_data/encapsulated_pixel_data.dart';
import '../pixel_data/pixel_data_info.dart';
import 'frame_codec.dart';
import 'huffman_table.dart';
import 'jpeg_bit_reader.dart';
import 'jpeg_framing_strategy.dart';
import 'jpeg_markers.dart';

/// Pure-Dart DICOM JPEG Lossless, Non-Hierarchical, First-Order Prediction (Process 14, Selection Value 1)
/// frame decoder for Transfer Syntax UID `1.2.840.10008.1.2.4.70`.
///
/// Complies with DICOM PS3.5 Section 8.2.1, ITU-T T.81 / ISO/IEC 10918-1 Annex H.
class JpegLosslessDecoder implements DicomFrameCodec {
  /// Creates a [JpegLosslessDecoder] instance.
  const JpegLosslessDecoder();

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
    if (frameBytes.length < 4) {
      throw const FormatException(
        'Truncated JPEG stream: insufficient bytes for SOI marker.',
      );
    }

    if (frameBytes[0] != 0xFF || frameBytes[1] != JpegMarker.soi) {
      throw const FormatException(
        'Invalid JPEG stream: missing Start of Image (SOI) marker.',
      );
    }

    int offset = 2;
    int? precision;
    int? height;
    int? width;
    int? numComponents;
    final Map<int, HuffmanTable> huffmanTables = {};
    int restartInterval = 0;
    int? predictorSelection;
    int pointTransform = 0;
    int? dcTableId;

    final length = frameBytes.length;

    // --- 1. Parse JPEG Marker Headers up to SOS ---
    while (offset < length) {
      // Find 0xFF marker prefix
      if (frameBytes[offset] != 0xFF) {
        offset++;
        continue;
      }

      while (offset < length && frameBytes[offset] == 0xFF) {
        offset++;
      }

      if (offset >= length) {
        throw const FormatException(
          'Unexpected end of JPEG stream while reading markers.',
        );
      }

      final marker = frameBytes[offset++];

      // Markers without length parameter
      if (marker == JpegMarker.soi ||
          (marker >= JpegMarker.rst0 && marker <= JpegMarker.rst7) ||
          marker == JpegMarker.eoi) {
        continue;
      }

      if (offset + 2 > length) {
        throw const FormatException(
          'Truncated JPEG stream reading marker segment length.',
        );
      }

      final segmentLength = (frameBytes[offset] << 8) | frameBytes[offset + 1];
      if (segmentLength < 2 || offset + segmentLength > length) {
        throw FormatException(
          'Invalid JPEG segment length $segmentLength for marker 0x${marker.toRadixString(16)}.',
        );
      }

      final segmentDataStart = offset + 2;
      final segmentDataEnd = offset + segmentLength;

      if (marker == JpegMarker.sof3) {
        // Start of Frame (Lossless Sequential Huffman)
        if (segmentLength < 8) {
          throw const FormatException('Malformed SOF3 marker segment.');
        }
        precision = frameBytes[segmentDataStart];
        height =
            (frameBytes[segmentDataStart + 1] << 8) |
            frameBytes[segmentDataStart + 2];
        width =
            (frameBytes[segmentDataStart + 3] << 8) |
            frameBytes[segmentDataStart + 4];
        numComponents = frameBytes[segmentDataStart + 5];

        if (precision < 2 || precision > 16) {
          throw UnsupportedError(
            'Unsupported JPEG Lossless sample precision: $precision bits (expected 2..16).',
          );
        }

        if (numComponents != 1) {
          throw UnsupportedError(
            'Unsupported JPEG Lossless component count: $numComponents. '
            'Task 3 supports single-component grayscale.',
          );
        }
      } else if (marker == JpegMarker.sof0 ||
          marker == JpegMarker.sof1 ||
          marker == JpegMarker.sof2) {
        throw UnsupportedError(
          'Unsupported JPEG process: marker 0x${marker.toRadixString(16)}. '
          'Only SOF3 (Lossless SV1) is supported in this codec.',
        );
      } else if (marker == JpegMarker.dht) {
        // Define Huffman Table
        int dhtOffset = segmentDataStart;
        while (dhtOffset < segmentDataEnd) {
          final tableInfo = frameBytes[dhtOffset++];
          final tableClass = (tableInfo >> 4) & 0x0F;
          final tableId = tableInfo & 0x0F;

          if (dhtOffset + 16 > segmentDataEnd) {
            throw const FormatException('Truncated DHT marker segment.');
          }

          final bits = frameBytes.sublist(dhtOffset, dhtOffset + 16);
          dhtOffset += 16;

          int symbolCount = 0;
          for (final count in bits) {
            symbolCount += count;
          }

          if (dhtOffset + symbolCount > segmentDataEnd) {
            throw const FormatException(
              'Truncated DHT marker segment reading Huffman symbols.',
            );
          }

          final huffval = frameBytes.sublist(
            dhtOffset,
            dhtOffset + symbolCount,
          );
          dhtOffset += symbolCount;

          huffmanTables[tableId] = HuffmanTable(
            tableClass: tableClass,
            destinationId: tableId,
            bits: bits,
            huffval: huffval,
          );
        }
      } else if (marker == JpegMarker.dri) {
        // Define Restart Interval
        if (segmentLength < 4) {
          throw const FormatException('Malformed DRI marker segment.');
        }
        restartInterval =
            (frameBytes[segmentDataStart] << 8) |
            frameBytes[segmentDataStart + 1];
      } else if (marker == JpegMarker.sos) {
        // Start of Scan
        if (segmentLength < 6) {
          throw const FormatException('Malformed SOS marker segment.');
        }
        final ns = frameBytes[segmentDataStart];
        if (ns != 1) {
          throw UnsupportedError(
            'Unsupported scan component count $ns in Lossless SOS (expected 1).',
          );
        }

        // Component selector: frameBytes[segmentDataStart + 1]
        final tableMapping = frameBytes[segmentDataStart + 2];
        dcTableId = (tableMapping >> 4) & 0x0F;

        predictorSelection = frameBytes[segmentDataStart + 3];
        // Spectral selection end: frameBytes[segmentDataStart + 4] (0)
        final approx = frameBytes[segmentDataStart + 5];
        pointTransform = approx & 0x0F;

        if (predictorSelection != 1) {
          throw UnsupportedError(
            'Unsupported JPEG Lossless predictor selection $predictorSelection. '
            'Transfer Syntax 1.2.840.10008.1.2.4.70 supports Selection Value 1 (Predictor 1) only.',
          );
        }

        if (pointTransform >= (precision ?? 16)) {
          throw FormatException(
            'Invalid point transform $pointTransform for precision $precision.',
          );
        }

        // Entropy-coded bitstream begins immediately after SOS segment
        offset = segmentDataEnd;
        break;
      } else {
        // Skip metadata / comment / application segments (APPn, COM, etc.)
      }

      offset = segmentDataEnd;
    }

    if (precision == null || height == null || width == null) {
      throw const FormatException(
        'Missing SOF3 frame header before SOS in JPEG stream.',
      );
    }

    if (predictorSelection == null || dcTableId == null) {
      throw const FormatException('Missing SOS header in JPEG stream.');
    }

    final table = huffmanTables[dcTableId];
    if (table == null) {
      throw FormatException(
        'Referenced Huffman table ID $dcTableId was not defined in DHT segments.',
      );
    }

    // --- 2. Entropy-Coded DPCM Predictor 1 Reconstruction ---
    final reader = JpegBitReader(frameBytes, offset: offset);
    final totalPixels = width * height;
    final mask = (1 << precision) - 1;
    final int initialPredictor = 1 << (precision - pointTransform - 1);

    int samplesUntilRestart = restartInterval;
    int expectedRestartMarker = 0;

    // Buffer storing unshifted reconstructed samples for row prediction
    final Int32List prevRow = Int32List(width);

    // Destination uncompressed raw bytes
    final bytesPerSample = (precision <= 8) ? 1 : 2;
    final Uint8List outputBytes = Uint8List(totalPixels * bytesPerSample);
    final ByteData outputBd = ByteData.sublistView(outputBytes);

    int outIndex = 0;

    for (int r = 0; r < height; r++) {
      int prevSampleInRow = 0;

      for (int c = 0; c < width; c++) {
        // Handle restart interval boundary if configured
        bool isRestart = false;
        if (restartInterval > 0 && samplesUntilRestart == 0) {
          final m = reader.readRestartMarker();
          final expectedCode = JpegMarker.rst0 + expectedRestartMarker;
          if (m != expectedCode) {
            throw FormatException(
              'Restart marker mismatch: got 0x${m.toRadixString(16)}, '
              'expected 0x${expectedCode.toRadixString(16)}.',
            );
          }
          expectedRestartMarker = (expectedRestartMarker + 1) & 0x07;
          samplesUntilRestart = restartInterval;
          isRestart = true;
        }

        // Determine Predictor Px per ITU-T T.81 Annex H.1.2
        int px;
        if (isRestart) {
          // Reset predictor to initial value after restart marker
          px = initialPredictor;
        } else if (c == 0) {
          if (r == 0) {
            // First sample of the scan: 2^(P - Pt - 1)
            px = initialPredictor;
          } else {
            // First column of subsequent lines: sample immediately above (B)
            px = prevRow[0];
          }
        } else {
          // Predictor 1: sample immediately to the left (A)
          px = prevSampleInRow;
        }

        // Decode difference DIFF from Huffman code and additional bits
        final diff = _decodeDifference(table, reader);

        // Reconstruct sample Rx before point transform (modulo 2^P)
        final rx = (px + diff) & mask;
        prevSampleInRow = rx;
        prevRow[c] = rx;

        // Apply point transform scaling
        final sample = (rx << pointTransform) & mask;

        // Write sample into output byte buffer (little endian for 16-bit)
        if (bytesPerSample == 1) {
          outputBytes[outIndex++] = sample & 0xFF;
        } else {
          outputBd.setUint16(outIndex * 2, sample, Endian.little);
          outIndex++;
        }

        if (restartInterval > 0) {
          samplesUntilRestart--;
        }
      }
    }

    return outputBytes;
  }

  /// Decodes difference value from Huffman category and magnitude bits (ITU-T T.81 Annex F.1.2.1 / F.2.2.1).
  static int _decodeDifference(HuffmanTable table, JpegBitReader reader) {
    final s = table.decode(reader);
    if (s == 0) {
      return 0;
    }
    if (s == 16) {
      // In 16-bit precision, category 16 has 0 magnitude bits and represents difference 32768 (ISO/IEC 10918-1 Table F.1)
      return 32768;
    }

    final v = reader.readBits(s);
    final half = 1 << (s - 1);
    if (v >= half) {
      return v;
    } else {
      return v - ((1 << s) - 1);
    }
  }
}
