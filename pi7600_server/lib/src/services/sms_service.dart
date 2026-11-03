import 'dart:developer' as developer;

import 'package:simcom_modem/simcom_modem.dart';
import 'package:pi7600_server/src/data/message_store.dart';
import 'package:pi7600_server/src/generated/message.dart';

class SmsDeliveryException implements Exception {
  SmsDeliveryException(this.message);

  final Message message;
}

class ModemDeleteException implements Exception {
  ModemDeleteException(this.messageIndex);

  final int messageIndex;
}

/// Business logic for persisting and sending SMS messages.
class SmsService {
  SmsService({required this.sms, required this.store});

  final Sms sms;
  final MessageStore store;

  /// Fetch messages from the modem, persist new ones, and return all rows.
  Future<List<Message>> listMessages() async {
    final parsed = await sms.receiveMessages();
    for (final message in parsed) {
      try {
        await createMessage(message);
      } on Object catch (error) {
        developer.log(
          'Unable to persist SMS message: $error',
          name: 'pi7600.sms',
        );
      }
    }
    return store.findAll();
  }

  /// Persist a decoded message, sending outgoing messages when needed.
  Future<Message> createMessage(ParsedMessage message) async {
    final existing = await store.findByFingerprint(
      messageType: message.messageType,
      messageContents: message.messageContents,
      messageDate: message.messageDate,
      messageTime: message.messageTime,
    );

    if (existing != null) {
      if (existing.inSimMemory != message.inSimMemory) {
        existing.inSimMemory = message.inSimMemory;
        return store.update(existing);
      }
      return existing;
    }

    var row = await store.insert(
      Message(
        messageIndex: message.messageIndex,
        messageType: message.messageType,
        messageOriginatingAddress: message.messageOriginatingAddress,
        messageDestinationAddress: message.messageDestinationAddress,
        messageDate: message.messageDate,
        messageTime: message.messageTime,
        messageContents: message.messageContents,
        partialKey: message.partialKey,
        partialCount: message.partialCount,
        partialIndex: message.partialIndex,
        isPartial: message.isPartial,
        inSimMemory: message.inSimMemory,
        isSent: message.isSent,
      ),
    );

    if (message.messageType == 'SENT' && row.isSent != true) {
      final destination = message.messageDestinationAddress;
      if (destination == null) {
        throw SmsDeliveryException(row);
      }
      final sent = await sms.sendMessage(destination, message.messageContents);
      if (!sent) {
        throw SmsDeliveryException(row);
      }
      row.isSent = true;
      row = await store.update(row);
    }

    return row;
  }

  /// Create and send an outgoing SMS.
  Future<Message> sendMessage({
    required String number,
    required String text,
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    return createMessage(
      ParsedMessage(
        messageIndex: null,
        messageType: 'SENT',
        messageOriginatingAddress: null,
        messageDestinationAddress: number,
        messageDate: _date(timestamp),
        messageTime: _time(timestamp),
        messageContents: text,
        isPartial: false,
        inSimMemory: false,
        isSent: false,
      ),
    );
  }

  /// Delete a message by database id. Returns `false` when it does not exist.
  Future<bool> deleteMessage(int id) async {
    final message = await store.findById(id);
    if (message == null) return false;

    if (message.inSimMemory == true && message.messageIndex != null) {
      final index = int.tryParse(message.messageIndex!);
      if (index != null) {
        final deleted = await sms.deleteMessage(index);
        if (!deleted) {
          throw ModemDeleteException(index);
        }
      }
    }

    await store.delete(message);
    return true;
  }

  /// Remove all messages that are still stored on the SIM.
  Future<void> cleanupSimMessages() async {
    final messages = await store.findInSimMemory();
    for (final message in messages) {
      if (message.messageIndex != null) {
        final index = int.tryParse(message.messageIndex!);
        if (index != null) {
          final deleted = await sms.deleteMessage(index);
          if (!deleted) {
            developer.log(
              'Unable to delete modem message ${message.messageIndex}',
              name: 'pi7600.sms',
            );
            continue;
          }
        }
      }
      message.inSimMemory = false;
      await store.update(message);
    }
  }

  static String _date(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }

  static String _time(DateTime value) {
    return '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}:'
        '${value.second.toString().padLeft(2, '0')}';
  }
}
