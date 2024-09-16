import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sms_test_app/models/Contacts.dart';
import 'package:sqflite/sqflite.dart';
import '../models/message.dart';

class SMSDatabase {
  static final SMSDatabase instance = SMSDatabase._init();

  static Database? _database;

  SMSDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await initDB('messagesDB.db');

    return _database!;
  }

//
//
//
//
  // Add a StreamController to notify when a new message is inserted
  final _messageAddedController = StreamController<void>.broadcast();
  Stream<void> get onMessageAdded => _messageAddedController.stream;

  final _chatpageController = StreamController<Message?>.broadcast();
  Stream<Message?> get onChatPageAdded => _chatpageController.stream;
//
//
//
//

  Future<Database> initDB(String filePath) async {
    final dbPath = await getDatabasesPath();

    final path = dbPath + filePath;
    // print(path);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const nameType = 'TEXT';
    const boolType = 'BOOLEAN';
    const numberType = 'INTEGER NOT NULL';
    const String blobType = 'BLOB';

    await db.execute('''
CREATE TABLE $tableMessages (
  ${MessageFields.id} $idType,
  ${MessageFields.senderNumber} $numberType,
  ${MessageFields.receiverNumber} $numberType,
  ${MessageFields.contactName} $nameType,
  ${MessageFields.messageBody} $textType,
  ${MessageFields.timeStamp} $textType,
  ${MessageFields.apiValue} $boolType,
  ${MessageFields.isRead} $boolType,
  ${MessageFields.isSentToAPI} $boolType,
  ${MessageFields.callcount} $numberType
)''');

    await db.execute('''
CREATE TABLE $tableContacts (
  ${ContactFields.id} $idType,
  ${ContactFields.contactName} $textType,
  ${ContactFields.phoneNumberOne} $textType,  -- Change to textType to store phone numbers as strings
  ${ContactFields.phoneNumbertwo} $textType,  -- Change to textType to store phone numbers as strings
  ${ContactFields.avatar} $blobType  -- Use BLOB to store binary data (avatar)
)''');
  }

// =============================== CONTACTS TABLE FUNCTIONS ===========================================
  Future<ContactDB> storeContacts(ContactDB contacts) async {
    final db = await instance.database;

    final id = await db.insert(tableContacts, contacts.toJson());
    return contacts.copy(id: id);
  }

  Future<List<ContactData>> readAllContactsFromTable() async {
    final db = await instance.database;

    final result = await db.query(tableContacts);

    return result.map((json) {
      final contactDB = ContactDB.fromJson(json);
      return ContactData(
        contactName: contactDB.contactName,
        phoneNumberOne: contactDB.phoneNumberOne,
        avatar: contactDB.avatar,
      );
    }).toList();
  }

  Future<int> deleteAllContacts() async {
    final db = await instance.database;

    return await db.delete(tableContacts);
  }

  Future<String?> searchContactName(String phoneNumber) async {
    final db = await instance.database;

    if (kDebugMode) {
      print("searchContactName called Number is $phoneNumber");
    }

    final result = await db.rawQuery('''
    SELECT
      ${ContactFields.contactName} AS senderName
    FROM $tableContacts
    WHERE
      substr(${ContactFields.phoneNumberOne}, -9) = substr(?, -9) OR
      substr(${ContactFields.phoneNumbertwo}, -9) = substr(?, -9)
  ''', [phoneNumber, phoneNumber]);

    if (result.isNotEmpty) {
      if (kDebugMode) {
        print(
            "database found number: ${result.first['senderName'] as String?}");
      }
      return result.first['senderName'] as String?;
    } else {
      return null; // Return null if the contact name is not found in the database
    }
  }

// =============================== MESSAGES TABLE FUNCTIONS ===========================================
  Future<int> create(Message message) async {
    final db = await instance.database;

    final id = await db.insert(tableMessages, message.toJson());
    if (kDebugMode) {
      print('stored id is $id');
    }
    // Notify the StreamBuilder that a new message has been inserted
    if (kDebugMode) {
      print('message controller execured');
    }
    // _messageAddedController.add(null);
    // _chatpageController.add(null);
    _chatpageController.add(message);

    // return message.copy(id: id);
    return id;
  }

  Future<int> storeSentMessages(Message message) async {
    final db = await instance.database;
    final storedid = await db.insert(tableMessages, message.toJson());
    // Notify the StreamBuilder that a new message has been inserted
    _chatpageController.add(message);

    // return message.copy(id: id);
    return storedid;
  }

  Future<Message> readMessage(int id) async {
    final db = await instance.database;

    final maps = await db.query(
      tableMessages,
      columns: MessageFields.values,
      where: '${MessageFields.id} = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Message.fromJson(maps.first);
    } else {
      throw Exception('ID $id not found');
    }
  }

  Future<List<Message>> readAllFromTable() async {
    final db = await instance.database;

    const orderBy = '${MessageFields.timeStamp} desc';
    final result = await db.query(tableMessages, orderBy: orderBy);

    return result.map((json) => Message.fromJson(json)).toList();
  }

  Future<List<Message>> readAllChatMessages(
      String currentReceiverNumber, String currentUserNumber) async {
    final db = await instance.database;

    // ex: current receiver number = Mohan, current user number = Me
    // read Messages sent by Mohan to Me
    const orderBy = '${MessageFields.id} ASC';

    final result = await db.rawQuery(
        'SELECT * FROM $tableMessages WHERE (substr(${MessageFields.senderNumber}, -9) = substr(?, -9) AND substr(${MessageFields.receiverNumber}, -9) = substr(?, -9)) OR (substr(${MessageFields.senderNumber}, -9) = substr(?, -9) AND substr(${MessageFields.receiverNumber}, -9) = substr(?, -9)) ORDER BY $orderBy',
        [
          currentReceiverNumber,
          currentUserNumber,
          currentUserNumber,
          currentReceiverNumber
        ]);

    return result.map((json) => Message.fromJson(json)).toList();
  }

  Future<Map<String, Map<String, dynamic>>>
      readAllSendersWithTimestampsAndMessages() async {
    final db = await instance.database;

    final result = await db.rawQuery('''
    SELECT
      number,
      MAX(timestamp) AS timestamp,
      contactName,
      message,
      isRead,
      apiValue, 
      isSentToAPI
    FROM (
      SELECT
        substr(${MessageFields.senderNumber}, -9) AS number,
        ${MessageFields.timeStamp} AS timestamp,
        ${MessageFields.contactName} AS contactName,
        ${MessageFields.messageBody} AS message,
        ${MessageFields.isRead} AS isRead,
        ${MessageFields.apiValue} AS apiValue,
        ${MessageFields.isSentToAPI} AS isSentToAPI
      FROM $tableMessages
      WHERE ${MessageFields.senderNumber} != 9999999999

      UNION ALL

      SELECT
        substr(${MessageFields.receiverNumber}, -9) AS number,
        ${MessageFields.timeStamp} AS timestamp,
        ${MessageFields.contactName} AS contactName,
        ${MessageFields.messageBody} AS message,
        ${MessageFields.isRead} AS isRead,
        ${MessageFields.apiValue} AS apiValue,
        ${MessageFields.isSentToAPI} AS isSentToAPI
      FROM $tableMessages
      WHERE ${MessageFields.receiverNumber} != 9999999999
    )
    GROUP BY number, contactName, message, isRead, apiValue, isSentToAPI
    ORDER BY timestamp DESC
  ''');

    // Create a map to store the result
    final numbersToData = <String, Map<String, dynamic>>{};

    for (final row in result) {
      final number = row['number'].toString();
      final contactName = row['contactName'].toString();
      final timestampString = row['timestamp'].toString();
      final message = row['message'].toString();
      final isRead = row['isRead'] == 1; // Convert to bool
      final apiValue = row['apiValue'] == 1; // Convert to bool
      final isSentToAPI = row['isSentToAPI'] == 1; // Convert to bool

      final timestamp = DateTime.parse(timestampString);

      // Check if the number is already in the map and update if the timestamp is newer
      if (!numbersToData.containsKey(number) ||
          timestamp.isAfter(numbersToData[number]!['timestamp'])) {
        numbersToData[number] = {
          'contactName': contactName,
          'timestamp': timestamp,
          'message': message,
          'isRead': isRead,
          'apiValue': apiValue,
          'isSentToAPI': isSentToAPI,
        };
      }
    }

    _messageAddedController.add(null);

    return numbersToData;
  }

  // update issenttoAPI values method
  Future<void> updateIsSentToAPIValue(int? messageId, bool newValue) async {
    final db = await instance.database;

    db.update(
      tableMessages,
      {
        MessageFields.isSentToAPI: newValue ? 1 : 0
      }, // Convert boolean to int (0 or 1)
      where: '${MessageFields.id} = ?',
      whereArgs: [messageId],
    );
    _chatpageController.add(null);
  }

  // update both apivalues and issenttoAPI values method
  Future<void> updateisSentAPIAndApiValues(
      int? messageId, bool issenttoapi, bool apivalue, int callcount) async {
    if (kDebugMode) {
      print('Print from updateisSentAPIAndApiValues method'
          'message id is $messageId, issenttoapi $issenttoapi, apivalue: $apivalue ,callcount is $callcount');
    }
    final db = await instance.database;

    db.update(
      tableMessages,
      {
        MessageFields.isSentToAPI: issenttoapi ? true : false,
        MessageFields.apiValue: apivalue ? true : false,
        MessageFields.callcount: callcount,
      }, // Convert boolean to int (0 or 1)
      where: '${MessageFields.id} = ?',
      whereArgs: [messageId],
    );
    _chatpageController.add(null);
  }

  Future<int> updateIsReadStatusOfMessages(int? messageId) async {
    debugPrint(
        "updateIsReadStatusOfMessages called and message id is: $messageId");
    final db = await instance.database;
    final id = db.update(
      tableMessages,
      {MessageFields.isRead: true},
      where: '${MessageFields.id} = ?',
      whereArgs: [messageId],
    );
    _chatpageController.add(null);
    return id;
  }

  // update a record by ID
  Future<int> update(Message message) async {
    final db = await instance.database;

    return db.update(
      tableMessages,
      message.toJson(),
      where: '${MessageFields.id} = ?',
      whereArgs: [message.id],
    );
  }

  // delete all records in the table
  Future<int> deleteAll() async {
    final db = await instance.database;

    return await db.delete(tableMessages);
  }

  // delete chat thread from the database
  Future<void> deleteChatThread(String senderNumber) async {
    final db = await instance.database;

    await db.delete(
      tableMessages,
      where:
          // '${MessageFields.senderNumber} = ? OR ${MessageFields.receiverNumber} = ?',
          'substr(${MessageFields.senderNumber}, -9) = ? OR substr(${MessageFields.receiverNumber}, -9) = ?',
      whereArgs: [senderNumber, senderNumber],
    );
    _messageAddedController.add(null);
  }

// delete single message from the database
  Future<void> deleteMessageRecord(int? id) async {
    final db = await instance.database;

    await db.delete(
      tableMessages,
      where: '${MessageFields.id} = ?',
      whereArgs: [id],
    );
    _chatpageController.add(null);
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
