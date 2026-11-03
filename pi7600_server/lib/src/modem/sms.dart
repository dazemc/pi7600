import 'dart:convert';

import 'package:pi7600_server/src/modem/at.dart';
import 'package:pi7600_server/src/modem/pdu.dart';
import 'package:pi7600_server/src/modem/settings.dart';

/// Send, receive, and delete SMS messages through the modem.
class Sms {
  Sms(this.settings, {this.parserOverride});

  final ModemSettings settings;

  /// Optional parser override for tests. When unset, a parser is created at
  /// parse time so it picks up the timezone loaded by [ModemSettings.initialize].
  final SmsParser? parserOverride;

  SmsParser get parser =>
      parserOverride ?? SmsParser(timezone: settings.timezone);

  static const int timeout = 3;
  static const int sendTimeout = 15;

  /// Read all messages from SIM storage in PDU mode.
  Future<List<ParsedMessage>> receiveMessages() async {
    final previousMode = await settings.getDataMode();
    if (previousMode != true) {
      await settings.setDataMode(0);
    }
    try {
      final answer = await settings.sendAt('AT+CMGL=4', 'OK', timeout);
      if (At.isError(answer)) return const [];
      return parser.parsePdu(answer);
    } finally {
      if (previousMode == false) {
        await settings.setDataMode(1);
      }
    }
  }

  Future<List<ParsedMessage>> readMessage(String messageType) {
    return receiveMessages();
  }

  /// Send a text message, restoring the previous modem mode afterwards.
  Future<bool> sendMessage(String phoneNumber, String textMessage) async {
    final previousMode = await settings.getDataMode();
    await settings.setDataMode(1);
    try {
      final answer = await settings.sendAt(
        'AT+CMGS="$phoneNumber"',
        '>',
        timeout,
      );
      if (At.isError(answer)) return false;

      await settings.at.writeData([...utf8.encode(textMessage), 0x1A]);
      final response = await settings.at.readUntil('OK', sendTimeout);
      return !At.isError(response);
    } finally {
      if (previousMode == true) {
        await settings.setDataMode(0);
      }
    }
  }

  /// Delete a message by its modem index.
  Future<bool> deleteMessage(int messageIndex) async {
    final response = await settings.sendAt(
      'AT+CMGD=$messageIndex',
      'OK',
      timeout,
    );
    return !At.isError(response);
  }
}
