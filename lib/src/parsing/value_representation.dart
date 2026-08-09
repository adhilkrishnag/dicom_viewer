/// Value Representations (VR) in DICOM PS3.5.
enum ValueRepresentation {
  ae, // Application Entity
  as, // Age String
  at, // Attribute Tag
  cs, // Code String
  da, // Date
  ds, // Decimal String
  dt, // Date Time
  fl, // Floating Point Single (4 bytes)
  fd, // Floating Point Double (8 bytes)
  isVR, // Integer String ("is" reserved keyword in Dart)
  lo, // Long String
  lt, // Long Text
  ob, // Other Byte
  od, // Other Double
  of, // Other Float
  ol, // Other Long
  ow, // Other Word
  pn, // Person Name
  sh, // Short String
  sl, // Signed Long
  ss, // Signed Short
  st, // Short Text
  tm, // Time
  uc, // Unlimited Characters
  ui, // Unique Identifier (UID)
  ul, // Unsigned Long
  un, // Unknown
  us, // Unsigned Short
  ut, // Unlimited Text
  sq, // Sequence of Items
  unknown,
}

extension ValueRepresentationX on ValueRepresentation {
  /// Two-character VR code string (e.g., 'DS', 'OW').
  String get code {
    if (this == ValueRepresentation.isVR) return 'IS';
    return name.toUpperCase();
  }

  /// Whether this VR uses a 32-bit (4-byte) value length header in Explicit VR mode.
  /// VRs with 2-byte value length: AE, AS, AT, CS, DA, DS, DT, FL, FD, IS, LO, LT, PN, SH, SL, SS, ST, TM, UI, UL, US.
  /// VRs with 4-byte value length (with 2 reserved bytes preceding): OB, OD, OF, OL, OW, SQ, UC, UN, UT.
  bool get isLongHeader {
    switch (this) {
      case ValueRepresentation.ob:
      case ValueRepresentation.od:
      case ValueRepresentation.of:
      case ValueRepresentation.ol:
      case ValueRepresentation.ow:
      case ValueRepresentation.sq:
      case ValueRepresentation.uc:
      case ValueRepresentation.un:
      case ValueRepresentation.ut:
        return true;
      default:
        return false;
    }
  }

  /// Parse 2-byte VR string into enum.
  static ValueRepresentation parse(String code) {
    switch (code.toUpperCase()) {
      case 'AE':
        return ValueRepresentation.ae;
      case 'AS':
        return ValueRepresentation.as;
      case 'AT':
        return ValueRepresentation.at;
      case 'CS':
        return ValueRepresentation.cs;
      case 'DA':
        return ValueRepresentation.da;
      case 'DS':
        return ValueRepresentation.ds;
      case 'DT':
        return ValueRepresentation.dt;
      case 'FL':
        return ValueRepresentation.fl;
      case 'FD':
        return ValueRepresentation.fd;
      case 'IS':
        return ValueRepresentation.isVR;
      case 'LO':
        return ValueRepresentation.lo;
      case 'LT':
        return ValueRepresentation.lt;
      case 'OB':
        return ValueRepresentation.ob;
      case 'OD':
        return ValueRepresentation.od;
      case 'OF':
        return ValueRepresentation.of;
      case 'OL':
        return ValueRepresentation.ol;
      case 'OW':
        return ValueRepresentation.ow;
      case 'PN':
        return ValueRepresentation.pn;
      case 'SH':
        return ValueRepresentation.sh;
      case 'SL':
        return ValueRepresentation.sl;
      case 'SS':
        return ValueRepresentation.ss;
      case 'ST':
        return ValueRepresentation.st;
      case 'TM':
        return ValueRepresentation.tm;
      case 'UC':
        return ValueRepresentation.uc;
      case 'UI':
        return ValueRepresentation.ui;
      case 'UL':
        return ValueRepresentation.ul;
      case 'UN':
        return ValueRepresentation.un;
      case 'US':
        return ValueRepresentation.us;
      case 'UT':
        return ValueRepresentation.ut;
      case 'SQ':
        return ValueRepresentation.sq;
      default:
        return ValueRepresentation.unknown;
    }
  }
}
