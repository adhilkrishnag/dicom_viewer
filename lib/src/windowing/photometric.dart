/// Supported DICOM Photometric Interpretations.
enum PhotometricInterpretation {
  monochrome1,
  monochrome2,
  rgb,
  paletteColor,
  ybrFull,
  unsupported,
}

extension PhotometricInterpretationX on PhotometricInterpretation {
  /// Parse string tag value into enum.
  static PhotometricInterpretation parse(String value) {
    switch (value.trim().toUpperCase()) {
      case 'MONOCHROME1':
        return PhotometricInterpretation.monochrome1;
      case 'MONOCHROME2':
        return PhotometricInterpretation.monochrome2;
      case 'RGB':
        return PhotometricInterpretation.rgb;
      case 'PALETTE COLOR':
        return PhotometricInterpretation.paletteColor;
      case 'YBR_FULL':
      case 'YBR_FULL_422':
      case 'YBR_PARTIAL_422':
        return PhotometricInterpretation.ybrFull;
      default:
        return PhotometricInterpretation.unsupported;
    }
  }

  /// Whether 0 represents maximum brightness (white) instead of black.
  bool get isInverted => this == PhotometricInterpretation.monochrome1;

  /// Whether this is a grayscale mode.
  bool get isMonochrome =>
      this == PhotometricInterpretation.monochrome1 ||
      this == PhotometricInterpretation.monochrome2;
}
