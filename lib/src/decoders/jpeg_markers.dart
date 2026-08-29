/// JPEG marker constants per ITU-T T.81 / ISO/IEC 10918-1.
class JpegMarker {
  /// Start of Image (0xFFD8).
  static const int soi = 0xD8;

  /// Start of Frame: Baseline DCT (0xFFC0).
  static const int sof0 = 0xC0;

  /// Start of Frame: Extended Sequential DCT (0xFFC1).
  static const int sof1 = 0xC1;

  /// Start of Frame: Progressive DCT (0xFFC2).
  static const int sof2 = 0xC2;

  /// Start of Frame: Lossless Sequential Huffman (0xFFC3).
  static const int sof3 = 0xC3;

  /// Define Huffman Table (0xFFC4).
  static const int dht = 0xC4;

  /// Restart interval 0 marker (0xFFD0).
  static const int rst0 = 0xD0;

  /// Restart interval 7 marker (0xFFD7).
  static const int rst7 = 0xD7;

  /// End of Image (0xFFD9).
  static const int eoi = 0xD9;

  /// Start of Scan (0xFFDA).
  static const int sos = 0xDA;

  /// Define Quantization Table (0xFFDB).
  static const int dqt = 0xDB;

  /// Define Restart Interval (0xFFDD).
  static const int dri = 0xDD;

  /// Application Data 0 (0xFFE0).
  static const int app0 = 0xE0;

  /// Application Data 15 (0xFFEF).
  static const int app15 = 0xEF;

  /// Comment (0xFFFE).
  static const int com = 0xFE;
}
