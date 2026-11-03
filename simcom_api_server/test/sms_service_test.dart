import 'package:simcom_modem/simcom_modem.dart';
import 'package:simcom_modem/testing.dart';
import 'package:simcom_api_server/src/data/message_store.dart';
import 'package:simcom_api_server/src/generated/message.dart';
import 'package:simcom_api_server/src/services/sms_service.dart';
import 'package:test/test.dart';

class FakeMessageStore implements MessageStore {
  final List<Message> rows = [];
  int _nextId = 1;

  @override
  Future<List<Message>> findAll() async => List.of(rows);

  @override
  Future<Message?> findById(int id) async {
    for (final row in rows) {
      if (row.id == id) return row;
    }
    return null;
  }

  @override
  Future<Message?> findByFingerprint({
    required String messageType,
    required String messageContents,
    required String messageDate,
    required String messageTime,
  }) async {
    for (final row in rows) {
      if (row.messageType == messageType &&
          row.messageContents == messageContents &&
          row.messageDate == messageDate &&
          row.messageTime == messageTime) {
        return row;
      }
    }
    return null;
  }

  @override
  Future<Message> insert(Message message) async {
    message.id = _nextId++;
    rows.add(message);
    return message;
  }

  @override
  Future<Message> update(Message message) async => message;

  @override
  Future<void> delete(Message message) async {
    rows.removeWhere((row) => row.id == message.id);
  }

  @override
  Future<List<Message>> findInSimMemory() async {
    return rows.where((row) => row.inSimMemory == true).toList();
  }
}

class FakeSms extends Sms {
  FakeSms()
    : super(
        ModemSettings(
          at: At(
            com: '/dev/fake',
            baudRate: 115200,
            transport: FakeTransport(),
          ),
        ),
      );

  final List<int> deleted = [];
  final List<(String, String)> sent = [];
  List<ParsedMessage> inbox = const [];
  bool sendSucceeds = true;

  @override
  Future<List<ParsedMessage>> receiveMessages() async => inbox;

  @override
  Future<bool> sendMessage(String phoneNumber, String textMessage) async {
    sent.add((phoneNumber, textMessage));
    return sendSucceeds;
  }

  @override
  Future<bool> deleteMessage(int messageIndex) async {
    deleted.add(messageIndex);
    return true;
  }
}

void main() {
  late FakeSms sms;
  late FakeMessageStore store;
  late SmsService service;

  setUp(() {
    sms = FakeSms();
    store = FakeMessageStore();
    service = SmsService(sms: sms, store: store);
  });

  ParsedMessage incoming({
    String type = 'REC READ',
    String contents = 'Hello',
    String date = '2026-01-02',
    String time = '03:04:05',
    String? index = '4',
    bool inSimMemory = true,
  }) {
    return ParsedMessage(
      messageIndex: index,
      messageType: type,
      messageOriginatingAddress: '+31641600986',
      messageDate: date,
      messageTime: time,
      messageContents: contents,
      isPartial: false,
      inSimMemory: inSimMemory,
    );
  }

  test('listMessages persists new messages and returns every row', () async {
    sms.inbox = [incoming(), incoming(contents: 'Second')];

    final messages = await service.listMessages();

    expect(messages, hasLength(2));
    expect(store.rows, hasLength(2));
  });

  test('listMessages does not duplicate identical messages', () async {
    sms.inbox = [incoming()];

    await service.listMessages();
    await service.listMessages();

    expect(store.rows, hasLength(1));
  });

  test('createMessage updates inSimMemory for an existing row', () async {
    await service.createMessage(incoming());

    final updated = await service.createMessage(incoming(inSimMemory: false));

    expect(store.rows, hasLength(1));
    expect(updated.inSimMemory, isFalse);
  });

  test('sendMessage marks the stored row as sent', () async {
    final message = await service.sendMessage(
      number: '+31612345678',
      text: 'Hi there',
      now: DateTime(2026, 1, 2, 3, 4, 5),
    );

    expect(message.messageType, 'SENT');
    expect(message.messageDestinationAddress, '+31612345678');
    expect(message.messageDate, '2026-01-02');
    expect(message.messageTime, '03:04:05');
    expect(message.isSent, isTrue);
    expect(store.rows.single.isSent, isTrue);
  });

  test(
    'does not resend a parsed SENT message with unknown sent state',
    () async {
      final parsed = ParsedMessage(
        messageIndex: '4',
        messageType: 'SENT',
        messageDestinationAddress: '+31612345678',
        messageDate: '2026-01-02',
        messageTime: '03:04:05',
        messageContents: 'Already sent',
        isPartial: false,
        inSimMemory: true,
      );

      final message = await service.createMessage(parsed);

      expect(message.isSent, isNull);
      expect(sms.sent, isEmpty);
    },
  );

  test('sendMessage throws when the modem rejects the message', () async {
    sms.sendSucceeds = false;

    expect(
      () => service.sendMessage(number: '+31612345678', text: 'Hi'),
      throwsA(isA<SmsDeliveryException>()),
    );
  });

  test('deleteMessage removes SIM messages through the modem', () async {
    final message = await service.createMessage(incoming());

    final deleted = await service.deleteMessage(message.id!);

    expect(deleted, isTrue);
    expect(sms.deleted, [4]);
    expect(store.rows, isEmpty);
  });

  test('deleteMessage refuses a SIM row without a modem index', () async {
    final message = await service.createMessage(incoming(index: null));

    await expectLater(
      service.deleteMessage(message.id!),
      throwsA(isA<ModemDeleteException>()),
    );
    expect(store.rows, hasLength(1));
    expect(sms.deleted, isEmpty);
  });

  test('deleteMessage returns false for an unknown id', () async {
    expect(await service.deleteMessage(99), isFalse);
  });

  test('deleteMessage keeps the row when the modem fails', () async {
    final message = await service.createMessage(incoming());
    final failing = _FailingDeleteSms();
    final failingService = SmsService(sms: failing, store: store);

    expect(
      () => failingService.deleteMessage(message.id!),
      throwsA(isA<ModemDeleteException>()),
    );
    expect(store.rows, hasLength(1));
  });

  test('cleanupSimMessages clears the in-SIM flag', () async {
    await service.createMessage(incoming(index: '4'));
    await service.createMessage(incoming(index: '5', contents: 'Second'));

    await service.cleanupSimMessages();

    expect(sms.deleted, [4, 5]);
    expect(store.rows.every((row) => row.inSimMemory == false), isTrue);
  });

  test('cleanup leaves rows without a modem index in place', () async {
    await service.createMessage(incoming(index: null));

    await service.cleanupSimMessages();

    expect(store.rows.single.inSimMemory, isTrue);
    expect(sms.deleted, isEmpty);
  });

  test('Sms reads the modem timezone when parsing, not at construction', () {
    final modem = ModemSettings(
      at: At(
        com: '/dev/fake',
        baudRate: 115200,
        transport: FakeTransport(),
      ),
    );
    final sms = Sms(modem);

    expect(sms.parser.timezone, isNull);
    modem.timezone = 2;
    expect(sms.parser.timezone, 2);
  });
}

class _FailingDeleteSms extends FakeSms {
  @override
  Future<bool> deleteMessage(int messageIndex) async => false;
}
