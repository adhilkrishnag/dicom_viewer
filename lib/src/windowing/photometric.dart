/// Supported DICOM Photometric Interpretations.
enum PhotometricInterpretation {
  /// Monochrome image where minimum pixel value is intended to be displayed as white.
  monochrome1,

  /// Monochrome image where minimum pixel value is intended to be displayed as black.
  monochrome2,

  /// Full-color RGB image (red, green, blue color components).
  rgb,

  /// Indexed color image where single pixel sample indexes into palette lookup tables.
  paletteColor,

  /// Full-color YBR image (luminance Y, blue chroma Cb, red chroma Cr).
  /// Full-range: Y in [0, 255], Cb/Cr in [0, 255] with 128 as neutral.
  ybrFull,

  /// Partial-range YBR image (CCIR 601-2 / BT.601 limited range, retired since DICOM PS3.3-2017b).
  /// Limited range: Y in [16, 235], Cb/Cr in [16, 240] with 128 as neutral.
  ybrPartial422,

  /// Unsupported or unparsed Photometric Interpretation.
  unsupported,
}

/// Extension providing utility methods and classification for [PhotometricInterpretation].
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
        return PhotometricInterpretation.ybrFull;
      case 'YBR_PARTIAL_422':
        return PhotometricInterpretation.ybrPartial422;
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
