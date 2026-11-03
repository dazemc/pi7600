import 'dart:convert';

/// SMS status values used by `AT+CMGL`.
String status(String value) {
  switch (value) {
    case '0':
      return 'REC UNREAD';
    case '1':
      return 'REC READ';
    case '2':
      return 'STO UNSENT';
    case '3':
      return 'STO SENT';
    default:
      return 'UNKNOWN';
  }
}

/// A decoded SMS message, independent of the persistence layer.
class ParsedMessage {
  const ParsedMessage({
    this.messageIndex,
    required this.messageType,
    this.messageOriginatingAddress,
    this.messageDestinationAddress,
    required this.messageDate,
    required this.messageTime,
    required this.messageContents,
    this.partialKey,
    this.partialCount,
    this.partialIndex,
    required this.isPartial,
    this.inSimMemory = true,
    this.isSent,
  });

  final String? messageIndex;
  final String messageType;
  final String? messageOriginatingAddress;
  final String? messageDestinationAddress;
  final String messageDate;
  final String messageTime;
  final String messageContents;
  final String? partialKey;
  final int? partialCount;
  final int? partialIndex;
  final bool isPartial;
  final bool? inSimMemory;
  final bool? isSent;
}

/// Decode modem SMS buffers in text or PDU mode.
class SmsParser {
  SmsParser({this.timezone});

  /// Modem timezone offset in hours. Added to decoded PDU timestamps.
  final int? timezone;

  List<ParsedMessage> parseSms(String smsBuffer, {bool pduMode = false}) {
    if (pduMode) return parsePdu(smsBuffer);
    return _parseText(smsBuffer);
  }

  List<ParsedMessage> _parseText(String smsBuffer) {
    try {
      final start = smsBuffer.indexOf('+CMGL');
      final end = smsBuffer.lastIndexOf('\r\n\r\nOK\r\n');
      if (start < 0 || end < 0) return const [];
      var readMessages = smsBuffer.substring(start, end);
      final chunks = readMessages.split('+CMGL: ');
      if (chunks.length <= 1) return const [];

      final messages = <ParsedMessage>[];
      for (final chunk in chunks.skip(1)) {
        final headerEnd = chunk.indexOf('\r\n');
        if (headerEnd < 0) continue;
        final header = chunk
            .substring(0, headerEnd)
            .replaceAll('"', '')
            .split(',');
        if (header.length < 6) continue;
        var contents = chunk.substring(headerEnd + 2);
        if (contents.endsWith('\r\n')) {
          contents = contents.substring(0, contents.length - 2);
        }
        final timeWithoutZone = header[5].length >= 3
            ? header[5].substring(0, header[5].length - 3)
            : header[5];
        final parsed = _parseTimestamp('${header[4]} $timeWithoutZone');
        messages.add(
          ParsedMessage(
            messageIndex: header[0],
            messageType: header[1],
            messageOriginatingAddress: header[2],
            messageDestinationAddress: header[3],
            messageDate: _formatDate(parsed),
            messageTime: _formatTime(parsed),
            messageContents: contents,
            isPartial: false,
            inSimMemory: true,
          ),
        );
      }
      return messages;
    } on Object {
      return const [];
    }
  }

  List<ParsedMessage> parsePdu(String pduBuffer) {
    if (pduBuffer.isEmpty) return const [];
    final chunks = pduBuffer.split('+CMGL: ');
    if (chunks.length <= 1) return const [];

    final messages = <ParsedMessage>[];
    for (final entry in chunks.skip(1)) {
      final lines = entry.split('\n');
      if (lines.length < 2) continue;
      final head = lines[0].trim().split(',');
      if (head.length < 2) continue;
      final encoded = lines[1].trim();
      if (encoded.isEmpty) continue;
      try {
        final decoded = decodeDeliverPdu(encoded);
        final local = decoded.timestamp.add(
          Duration(hours: timezone ?? 0),
        );
        messages.add(
          ParsedMessage(
            messageIndex: head[0],
            messageType: status(head[1]),
            messageOriginatingAddress: decoded.sender,
            messageDate: _formatDate(local),
            messageTime: _formatTime(local),
            messageContents: decoded.content,
            partialKey: decoded.partialKey,
            partialCount: decoded.partialCount,
            partialIndex: decoded.partialIndex,
            isPartial: decoded.partialKey != null,
            inSimMemory: true,
          ),
        );
      } on Object {
        // Skip malformed PDUs; the rest of the buffer is still useful.
      }
    }
    return messages;
  }

  static DateTime _parseTimestamp(String value) {
    final match = RegExp(
      r'^(\d{2})/(\d{2})/(\d{2}) (\d{2}):(\d{2}):(\d{2})$',
    ).firstMatch(value);
    if (match == null) return DateTime(1970);
    return DateTime(
      2000 + int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      int.parse(match.group(4)!),
      int.parse(match.group(5)!),
      int.parse(match.group(6)!),
    );
  }

  static String _formatDate(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }

  static String _formatTime(DateTime value) {
    return '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}:'
        '${value.second.toString().padLeft(2, '0')}';
  }
}

class DecodedDeliver {
  const DecodedDeliver({
    required this.sender,
    required this.content,
    required this.timestamp,
    this.partialKey,
    this.partialCount,
    this.partialIndex,
  });

  final String sender;
  final String content;
  final DateTime timestamp;
  final String? partialKey;
  final int? partialCount;
  final int? partialIndex;
}

/// Decode an SMS-DELIVER PDU (hex string) into its fields.
DecodedDeliver decodeDeliverPdu(String hex) {
  final bytes = _hexToBytes(hex);
  var offset = 0;

  final smscLength = bytes[offset++];
  offset += smscLength;

  final firstOctet = bytes[offset++];
  final mti = firstOctet & 0x03;
  if (mti != 0) {
    throw FormatException('Unsupported PDU type (MTI=$mti)');
  }
  final hasUserDataHeader = (firstOctet & 0x40) != 0;

  final addressLength = bytes[offset++];
  final typeOfAddress = bytes[offset++];
  final addressBytes = (addressLength + 1) ~/ 2;
  final address = bytes.sublist(offset, offset + addressBytes);
  offset += addressBytes;
  final sender = _decodeAddress(address, typeOfAddress, addressLength);

  offset++; // TP-PID
  final dcs = bytes[offset++];

  final timestamp = _decodeTimestamp(bytes.sublist(offset, offset + 7));
  offset += 7;

  final userDataLength = bytes[offset++];
  final alphabet = _alphabetFor(dcs);
  final userDataBytes = alphabet == _Alphabet.septets
      ? (userDataLength * 7 + 7) ~/ 8
      : userDataLength;
  final userData = bytes.sublist(
    offset,
    (offset + userDataBytes).clamp(0, bytes.length),
  );

  String? partialKey;
  int? partialCount;
  int? partialIndex;
  var textSeptetOffset = 0;
  var textByteOffset = 0;

  if (hasUserDataHeader && userData.isNotEmpty) {
    final headerLength = userData[0];
    final header = userData.sublist(
      1,
      (1 + headerLength).clamp(0, userData.length),
    );
    final headerInfo = _parseUserDataHeader(header);
    partialKey = headerInfo.reference;
    partialCount = headerInfo.total;
    partialIndex = headerInfo.sequence;
    textByteOffset = 1 + headerLength;
    textSeptetOffset = (textByteOffset * 8 + 6) ~/ 7;
  }

  final content = switch (alphabet) {
    _Alphabet.septets => _decode7Bit(
      userData,
      userDataLength - textSeptetOffset,
      bitOffset: textSeptetOffset * 7,
    ),
    _Alphabet.ucs2 => _decodeUcs2(
      userData.sublist(
        textByteOffset.clamp(0, userData.length),
      ),
    ),
    _Alphabet.eightBit => latin1.decode(
      userData.sublist(textByteOffset.clamp(0, userData.length)),
      allowInvalid: true,
    ),
  };

  return DecodedDeliver(
    sender: sender,
    content: content,
    timestamp: timestamp,
    partialKey: partialKey,
    partialCount: partialCount,
    partialIndex: partialIndex,
  );
}

enum _Alphabet { septets, eightBit, ucs2 }

_Alphabet _alphabetFor(int dcs) {
  if (dcs & 0xC0 == 0x00) {
    return switch (dcs & 0x0F) {
      0x00 => _Alphabet.septets,
      0x04 => _Alphabet.eightBit,
      0x08 => _Alphabet.ucs2,
      _ => _Alphabet.septets,
    };
  }
  if (dcs & 0xF0 == 0x40) {
    return (dcs & 0x0F) < 0x08 ? _Alphabet.septets : _Alphabet.eightBit;
  }
  if (dcs & 0xF0 == 0x50) {
    return _Alphabet.ucs2;
  }
  if (dcs & 0xF0 == 0x60) {
    return _Alphabet.septets;
  }
  if (dcs & 0xF0 == 0x70) {
    return _Alphabet.eightBit;
  }
  if (dcs & 0xF0 == 0xE0) {
    return _Alphabet.ucs2;
  }
  return _Alphabet.eightBit;
}

class _HeaderInfo {
  const _HeaderInfo({this.reference, this.total, this.sequence});

  final String? reference;
  final int? total;
  final int? sequence;
}

_HeaderInfo _parseUserDataHeader(List<int> header) {
  var index = 0;
  while (index + 1 < header.length) {
    final iei = header[index];
    final length = header[index + 1];
    final data = header.sublist(
      index + 2,
      (index + 2 + length).clamp(0, header.length),
    );
    if (iei == 0x00 && data.length >= 3) {
      return _HeaderInfo(
        reference: data[0].toString(),
        total: data[1],
        sequence: data[2],
      );
    }
    if (iei == 0x08 && data.length >= 4) {
      return _HeaderInfo(
        reference: ((data[0] << 8) | data[1]).toString(),
        total: data[2],
        sequence: data[3],
      );
    }
    index += 2 + length;
  }
  return const _HeaderInfo();
}

String _decodeAddress(List<int> bytes, int typeOfAddress, int digits) {
  if (typeOfAddress & 0x70 == 0x50) {
    return _decode7Bit(bytes, digits);
  }
  final buffer = StringBuffer();
  if (typeOfAddress & 0x70 == 0x10) {
    buffer.write('+');
  }
  var remaining = digits;
  for (final byte in bytes) {
    if (remaining <= 0) break;
    final low = byte & 0x0F;
    final high = (byte >> 4) & 0x0F;
    if (low != 0x0F) buffer.write(low.toRadixString(16).toUpperCase());
    remaining--;
    if (remaining <= 0) break;
    if (high != 0x0F) buffer.write(high.toRadixString(16).toUpperCase());
    remaining--;
  }
  return buffer.toString();
}

DateTime _decodeTimestamp(List<int> bytes) {
  if (bytes.length < 7) return DateTime.utc(1970);
  final year = _bcd(bytes[0]);
  final month = _bcd(bytes[1]);
  final day = _bcd(bytes[2]);
  final hour = _bcd(bytes[3]);
  final minute = _bcd(bytes[4]);
  final second = _bcd(bytes[5]);

  final fullYear = year >= 90 ? 1900 + year : 2000 + year;
  final local = DateTime.utc(fullYear, month, day, hour, minute, second);

  // The service-centre timestamp is local time with a BCD quarter-hour offset
  // in the last octet. Convert it to UTC, matching smspdudecoder's
  // `Date.decode` used by the Python service. [SmsParser] then applies the
  // modem timezone.
  final swapped = ((bytes[6] & 0x0F) << 4) | ((bytes[6] >> 4) & 0x0F);
  final negative = (swapped & 0x80) != 0;
  final quarterHours = ((swapped >> 4) & 0x07) * 10 + (swapped & 0x0F);
  final offset = Duration(
    minutes: 15 * quarterHours * (negative ? -1 : 1),
  );
  return local.subtract(offset);
}

int _bcd(int value) => (value & 0x0F) * 10 + ((value >> 4) & 0x0F);

String _decode7Bit(List<int> data, int septets, {int bitOffset = 0}) {
  final buffer = StringBuffer();
  final totalBits = data.length * 8;
  var bit = bitOffset;
  var count = 0;
  while (count < septets && bit + 7 <= totalBits) {
    var value = 0;
    for (var i = 0; i < 7; i++) {
      final byteIndex = (bit + i) ~/ 8;
      final bitIndex = (bit + i) % 8;
      if ((data[byteIndex] >> bitIndex) & 1 == 1) {
        value |= 1 << i;
      }
    }
    buffer.write(_decodeSeptet(value));
    bit += 7;
    count++;
  }
  return buffer.toString();
}

String _decodeUcs2(List<int> data) {
  if (data.length < 2) return '';
  final evenLength = data.length - (data.length % 2);
  final codeUnits = <int>[];
  for (var i = 0; i + 1 < evenLength; i += 2) {
    codeUnits.add((data[i] << 8) | data[i + 1]);
  }
  return String.fromCharCodes(codeUnits);
}

String _decodeSeptet(int value) {
  if (value == 0x1B) return '';
  final char = _gsm7Bit[value];
  if (char != null) return char;
  return '\uFFFD';
}

const _gsm7Bit = <int, String>{
  0x00: '@',
  0x01: '£',
  0x02: r'$',
  0x03: '¥',
  0x04: 'è',
  0x05: 'é',
  0x06: 'ù',
  0x07: 'ì',
  0x08: 'ò',
  0x09: 'Ç',
  0x0A: '\n',
  0x0B: 'Ø',
  0x0C: 'ø',
  0x0D: '\r',
  0x0E: 'Å',
  0x0F: 'å',
  0x10: 'Δ',
  0x11: '_',
  0x12: 'Φ',
  0x13: 'Γ',
  0x14: 'Λ',
  0x15: 'Ω',
  0x16: 'Π',
  0x17: 'Ψ',
  0x18: 'Σ',
  0x19: 'Θ',
  0x1A: 'Ξ',
  0x1B: '\u001b',
  0x1C: 'Æ',
  0x1D: 'æ',
  0x1E: 'ß',
  0x1F: 'É',
  0x20: ' ',
  0x21: '!',
  0x22: '"',
  0x23: '#',
  0x24: '¤',
  0x25: '%',
  0x26: '&',
  0x27: "'",
  0x28: '(',
  0x29: ')',
  0x2A: '*',
  0x2B: '+',
  0x2C: ',',
  0x2D: '-',
  0x2E: '.',
  0x2F: '/',
  0x30: '0',
  0x31: '1',
  0x32: '2',
  0x33: '3',
  0x34: '4',
  0x35: '5',
  0x36: '6',
  0x37: '7',
  0x38: '8',
  0x39: '9',
  0x3A: ':',
  0x3B: ';',
  0x3C: '<',
  0x3D: '=',
  0x3E: '>',
  0x3F: '?',
  0x40: '¡',
  0x41: 'A',
  0x42: 'B',
  0x43: 'C',
  0x44: 'D',
  0x45: 'E',
  0x46: 'F',
  0x47: 'G',
  0x48: 'H',
  0x49: 'I',
  0x4A: 'J',
  0x4B: 'K',
  0x4C: 'L',
  0x4D: 'M',
  0x4E: 'N',
  0x4F: 'O',
  0x50: 'P',
  0x51: 'Q',
  0x52: 'R',
  0x53: 'S',
  0x54: 'T',
  0x55: 'U',
  0x56: 'V',
  0x57: 'W',
  0x58: 'X',
  0x59: 'Y',
  0x5A: 'Z',
  0x5B: 'Ä',
  0x5C: 'Ö',
  0x5D: 'Ñ',
  0x5E: 'Ü',
  0x5F: '§',
  0x60: '¿',
  0x61: 'a',
  0x62: 'b',
  0x63: 'c',
  0x64: 'd',
  0x65: 'e',
  0x66: 'f',
  0x67: 'g',
  0x68: 'h',
  0x69: 'i',
  0x6A: 'j',
  0x6B: 'k',
  0x6C: 'l',
  0x6D: 'm',
  0x6E: 'n',
  0x6F: 'o',
  0x70: 'p',
  0x71: 'q',
  0x72: 'r',
  0x73: 's',
  0x74: 't',
  0x75: 'u',
  0x76: 'v',
  0x77: 'w',
  0x78: 'x',
  0x79: 'y',
  0x7A: 'z',
  0x7B: 'ä',
  0x7C: 'ö',
  0x7D: 'ñ',
  0x7E: 'ü',
  0x7F: 'à',
};

List<int> _hexToBytes(String hex) {
  final normalized = hex.replaceAll(RegExp(r'\s'), '');
  if (normalized.length.isOdd) {
    throw const FormatException('Odd-length PDU');
  }
  final result = List<int>.filled(normalized.length ~/ 2, 0);
  for (var i = 0; i < result.length; i++) {
    result[i] = int.parse(normalized.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return result;
}
