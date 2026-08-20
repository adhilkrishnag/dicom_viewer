/// Value Representations (VR) in DICOM PS3.5 Section 6.2.
enum ValueRepresentation {
  /// Application Entity (16 bytes max).
  ae,

  /// Age String (4 bytes fixed, e.g., '018M').
  as,

  /// Attribute Tag (4 bytes fixed, 16-bit group + 16-bit element).
  at,

  /// Code String (16 bytes max).
  cs,

  /// Date (8 bytes fixed, YYYYMMDD).
  da,

  /// Decimal String (16 bytes max).
  ds,

  /// Date Time (26 bytes max, YYYYMMDDHHMMSS.FFFFFF&ZZXX).
  dt,

  /// Floating Point Single (4 bytes fixed, IEEE 754:1985 32-bit).
  fl,

  /// Floating Point Double (8 bytes fixed, IEEE 754:1985 64-bit).
  fd,

  /// Integer String (12 bytes max, named `isVR` because `is` is a Dart keyword).
  isVR,

  /// Long String (64 chars max).
  lo,

  /// Long Text (10240 chars max).
  lt,

  /// Other Byte (byte string).
  ob,

  /// Other Double (64-bit floating point words).
  od,

  /// Other Float (32-bit floating point words).
  of,

  /// Other Long (32-bit signed/unsigned words).
  ol,

  /// Other Word (16-bit words).
  ow,

  /// Person Name (64 chars max per component group).
  pn,

  /// Short String (16 chars max).
  sh,

  /// Signed Long (4 bytes fixed, 32-bit 2's complement).
  sl,

  /// Signed Short (2 bytes fixed, 16-bit 2's complement).
  ss,

  /// Short Text (1024 chars max).
  st,

  /// Time (14 bytes max, HHMMSS.FFFFFF).
  tm,

  /// Unlimited Characters (2^32-2 bytes max).
  uc,

  /// Unique Identifier / UID (64 bytes max).
  ui,

  /// Unsigned Long (4 bytes fixed, 32-bit unsigned int).
  ul,

  /// Unknown (any byte string, used when VR is not defined).
  un,

  /// Unsigned Short (2 bytes fixed, 16-bit unsigned int).
  us,

  /// Unlimited Text (2^32-2 bytes max).
  ut,

  /// Sequence of Items (contains nested data sets).
  sq,

  /// Unknown / unparsed VR code.
  unknown,
}

/// Extension providing utility accessors and parsing for [ValueRepresentation].
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
