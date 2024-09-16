import 'dart:async';
import 'dart:convert';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
import 'package:sms_test_app/Services/notificationService.dart';
import 'package:sms_test_app/db/messagesDB.dart';
import 'package:sms_test_app/models/Contacts.dart';
import 'package:sms_test_app/models/message.dart';
import 'package:telephony/telephony.dart';
import 'package:http/http.dart' as http;

Future<int> storeMessageInDatabase(
    SmsMessage message, bool isSentToAPI, bool APIValue) async {
  // Extract the sender number without the country code
  String senderNumber = removeCountryCode(message.address!);
  final SMSDatabase database = SMSDatabase.instance;
  String? contactName = await database.searchContactName(message.address!);
  contactName ??= senderNumber;

  // Prepare the Message object to be stored in the database
  final dbMessage = Message(
    senderNumber: senderNumber, // Use the extracted sender number
    receiverNumber: '9999999999',
    contactName: contactName,
    messageBody: message.body!,
    // timeStamp: DateTime.fromMillisecondsSinceEpoch(message.date!),
    timeStamp: DateTime.fromMillisecondsSinceEpoch(
        DateTime.now().millisecondsSinceEpoch),
    apiValue: APIValue, // This will be determined later if needed
    isRead: false,
    isSentToAPI: isSentToAPI,
    callcount: 0,
  );

  try {
    // Use the SMSDatabase instance to store the message in the database
    final id = await database.create(dbMessage);
    // _messageAddedController.add(null);
    if (kDebugMode) {
      print('Message stored in the database. and ID is $id');
    }

    // triggerNotificataions(message.address, message.body, contactName);
    final connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult == ConnectivityResult.mobile ||
        connectivityResult == ConnectivityResult.wifi) {
      if (kDebugMode) {
        print('Connection is available');
      }

      String responseFromApi = await _sendMessageToAPI(message.body!);
      if (kDebugMode) {
        print('Response from API is : $responseFromApi');
      }

      if (responseFromApi == '1') {
        await SMSDatabase.instance
            .updateisSentAPIAndApiValues(id, true, true, 5);
        await notificationCallFunction(id.toString(), message.address!,
            message.body!, contactName, senderNumber, true, true);
      } else if (responseFromApi == '0') {
        await SMSDatabase.instance
            .updateisSentAPIAndApiValues(id, true, false, 5);
        await notificationCallFunction(id.toString(), message.address!,
            message.body!, contactName, senderNumber, true, false);
      } else if (responseFromApi == '2') {
        await SMSDatabase.instance
            .updateisSentAPIAndApiValues(id, false, false, 1);
        await notificationCallFunction(id.toString(), message.address!,
            message.body!, contactName, senderNumber, false, false);
      } else if (responseFromApi == '3') {
        await SMSDatabase.instance
            .updateisSentAPIAndApiValues(id, false, false, 0);
        await notificationCallFunction(id.toString(), message.address!,
            message.body!, contactName, senderNumber, false, false);
      } else {
        await SMSDatabase.instance
            .updateisSentAPIAndApiValues(id, true, false, 5);
        await notificationCallFunction(
          id.toString(),
          message.address!,
          message.body!,
          contactName,
          senderNumber,
          true,
          false,
        );
      }
    } else {
      if (kDebugMode) {
        print('Connection is not available');
      }
      await notificationCallFunction(id.toString(), message.address!,
          message.body!, contactName, senderNumber, false, false);
    }

    return id;
  } catch (e) {
    if (kDebugMode) {
      print('Error storing message in the database: $e');
    }
    return -1;
  }
}

Future<void> notificationCallFunction(
  String messageId,
  String messageAddress,
  String messageBody,
  String contactName,
  String senderNumber,
  bool isSenttoAPI,
  bool apiValue,
) async {
  await NotificationService.showNotification(
    messageAddress: messageAddress,
    body: messageBody,
    contactName: contactName,
    summary: "New Message",
    apiValue: apiValue,
    isSenttoAPI: isSenttoAPI,
    notificationLayout: NotificationLayout.Messaging,
    payload: {
      "messageId": messageId,
      "currentUserNumber": senderNumber,
      "receiverNumber": "9999999999",
      "ContactName": contactName,
    },
  );
}

Future<String> _sendMessageToAPI(String? message) async {
  if (kDebugMode) {
    print('api func called');
  }

  final connectivityResult = await (Connectivity().checkConnectivity());
  if (connectivityResult == ConnectivityResult.mobile ||
      connectivityResult == ConnectivityResult.wifi) {
    if (kDebugMode) {
      print('Connection is available');
    }
    String apiUrl = 'https://mlapp-b4cte3m7pq-tl.a.run.app/cybersmish/post';

    // Create the request body
    Map<String, dynamic> requestBody = {'text': message};

    // Send the POST request to the API
    http.Response response = await http.post(
      Uri.parse(apiUrl),
      body: jsonEncode(requestBody),
      headers: {'Content-Type': 'application/json'},
    );

    // Check the response status code and handle accordingly
    if (response.statusCode == 200) {
      // Successful API request

      if (kDebugMode) {
        print('Message sent to API successfully.');
      }

      // Extract the API response from the response body
      Map<String, dynamic> responseBody = jsonDecode(response.body);
      String apiResponse = responseBody['predictions'].toString();

      return apiResponse;
    }
    if (response.statusCode == 500) {
      if (kDebugMode) {
        print(
            'Failed to send message to API. Status code: ${response.statusCode}');
      }
      return '0';
    } else {
      return '2';
    }
  } else {
    if (kDebugMode) {
      print('The Internet connection is not available.');
    }
    return '3';
  }
}

Future<List<Message>> fetchMessagesInChatFromDatabase(
    receiverNumber, currentUserNumber) async {
  try {
    List<Message> messages = [];
    final List<Message> fetchedMessages = await SMSDatabase.instance
        .readAllChatMessages(receiverNumber, currentUserNumber);

    messages = fetchedMessages;
    return messages;
  } catch (e) {
    if (kDebugMode) {
      print('Error fetching messages from the database: $e');
    }
    return [];
  }
}

Future<void> storeCurrentUserSendMessages(
  String senderNumber,
  String receiverNumber,
  String messageBody,
  bool APIValue,
  bool isSentToAPI,
) async {
  // Extract the sender number without the country code
  String modifiedsenderNumber = removeCountryCode(receiverNumber);

  final SMSDatabase database = SMSDatabase.instance;
  if (kDebugMode) {
    print("reciverNumber: $receiverNumber");
  }
  String? contactName = await database.searchContactName(receiverNumber);
  if (kDebugMode) {
    print('DB name recivername: $contactName');
  }
  contactName ??= modifiedsenderNumber;

  // Prepare the Message object to be stored in the database
  final dbMessage = Message(
    senderNumber: senderNumber, // Use the extracted sender number
    receiverNumber: modifiedsenderNumber,
    contactName: contactName,
    messageBody: messageBody,
    timeStamp: DateTime.fromMillisecondsSinceEpoch(
        DateTime.now().millisecondsSinceEpoch),
    apiValue: APIValue, // This will be determined later if needed
    isRead: true,
    isSentToAPI: isSentToAPI,
    callcount: 6,
  );

  try {
    // Use the SMSDatabase instance to store the message in the database
    await database.storeSentMessages(dbMessage);
    // _messageAddedController.add(null);

    if (kDebugMode) {
      print('Message stored in the database.');
    }
  } catch (e) {
    if (kDebugMode) {
      print('Error storing message in the database: $e');
    }
  }
}

// Function to remove the country code from the sender number
String removeCountryCode(String phoneNumber) {
  // Remove brackets
  phoneNumber = phoneNumber.replaceAll(
    RegExp(r'[()-]'),
    '', // Replace with an empty string
  );
  return phoneNumber;
}

// Function to fetch messages from the database
Future<Map<String, Map<String, dynamic>>> fetchChatListFromDatabase() async {
  try {
    // Use the SMSDatabase instance to read all messages from the database
    final SMSDatabase database = SMSDatabase.instance;
    Map<String, Map<String, dynamic>> fetchedMessages =
        await database.readAllSendersWithTimestampsAndMessages();
    // print(fetchedMessages);
    return fetchedMessages;
  } catch (e) {
    // print('Error fetching messages from the database: $e');
    return {};
  }
}

// =====================Handle Contacts=====================

Future<void> storeContactsToDatabase() async {
  try {
    final List<Contact> contacts = await ContactsService.getContacts();
    final SMSDatabase database = SMSDatabase.instance;

    for (var contact in contacts) {
      if (contact.displayName != null && contact.phones != null) {
        for (var phone in contact.phones!) {
          String phoneNumber =
              removeCountryCode(phone.value!).replaceAll(' ', '');
          final dbContact = ContactDB(
            contactName: contact.displayName!,
            phoneNumberOne: phoneNumber,
            phoneNumbertwo:
                '', // You might want to modify this to handle multiple phone numbers
            avatar: contact.avatar,
          );

          await database.storeContacts(dbContact);
        }
      }
    }
    if (kDebugMode) {
      print('Contacts stored in the database.');
    }
    // triggerNotificataions(message.address, message.body);
  } catch (e) {
    if (kDebugMode) {
      print('Error storing contacts in the database: $e');
    }
  }
}

Future<void> updateContactOnDatabase() async {
  try {
    final SMSDatabase database = SMSDatabase.instance;
    // first delete all contacts from database.
    await database.deleteAllContacts();
    await storeContactsToDatabase();

    if (kDebugMode) {
      print('Contacts are updated on the database.');
    }
    // triggerNotificataions(message.address, message.body);
  } catch (e) {
    if (kDebugMode) {
      print('Error storing contacts in the database: $e');
    }
  }
}

Future<List<ContactData>> fetchContactListFromDatabase() async {
  try {
    // Use the SMSDatabase instance to read all messages from the database
    final SMSDatabase database = SMSDatabase.instance;

    List<ContactData> fetchedContacts =
        await database.readAllContactsFromTable();

    if (kDebugMode) {
      print('Featched contacts from the database are: $fetchedContacts');
    }

    return fetchedContacts;
  } catch (e) {
    if (kDebugMode) {
      print('Error fetching messages from the database: $e');
    }
    return [];
  }
}
