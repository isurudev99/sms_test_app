// import 'dart:convert';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sms_test_app/Services/messageServices.dart';
// import 'package:sms_test_app/Services/messageServices.dart';
import 'package:sms_test_app/db/messagesDB.dart';
import 'package:sms_test_app/models/message.dart';
import 'package:telephony/telephony.dart';
import 'package:http/http.dart' as http;

// ignore: must_be_immutable
class ChatPage extends StatefulWidget {
  String currentUserNumber;
  String receiverNumber;
  String? receiverName;

  ChatPage(
      {Key? key,
      required this.currentUserNumber,
      required this.receiverNumber,
      this.receiverName})
      : super(key: key);

  @override
  // ignore: library_private_types_in_public_api
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  Telephony telephony = Telephony.instance;
  List<Message> messages = [];
  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    initialFetchingMessagesWithAPICheck();

    // Listen for new messages and update the UI accordingly
    SMSDatabase.instance.onChatPageAdded.listen((Message? message) async {
      // await SMSDatabase.instance.updateIsReadStatusOfMessages(message!.id);
      fetchMessagesFromDatabase();
    });
  }

  // @override
  // void dispose() {
  //   // Close the StreamController when the state is disposed
  //   SMSDatabase.instance.close();
  //   super.dispose();
  // }

  Future<void> initialFetchingMessagesWithAPICheck() async {
    print('initialFetchingMessagesWithAPICheck is called now');

    final List<Message> fetchedMessages = await fetchMessagesInChatFromDatabase(
        widget.receiverNumber, widget.currentUserNumber);
    setState(() {
      messages = fetchedMessages;
    });

    for (int i = 0; i < fetchedMessages.length; i++) {
      final message = fetchedMessages[i];
      debugPrint(
          'On chat page:   id: ${message.id}, Message: ${message.messageBody}, Time: ${message.timeStamp}, APIvalue:${message.apiValue}, isRead:${message.isRead}, isSentToAPI:${message.isSentToAPI}, callcount:${message.callcount}');

      int timegap = (DateTime.fromMillisecondsSinceEpoch(
              DateTime.now().millisecondsSinceEpoch))
          .difference(message.timeStamp)
          .inMinutes;

      if (kDebugMode) {
        print('time gap from minitues is: $timegap');
      }

      if (message.isSentToAPI == false &&
          message.receiverNumber == widget.currentUserNumber &&
          message.callcount! < 5) {
        // messagesToSendToAPI.add(message);
        if (timegap < 5 && message.callcount! > 2) {
        } else {
          String responseFromApi = await _sendMessageToAPI(message.messageBody);
          // print('Response from API is : $responseFromApi');

          int newcallcount = message.callcount!;

          if (responseFromApi == '1') {
            // phishing response
            await SMSDatabase.instance
                .updateisSentAPIAndApiValues(message.id, true, true, 5);
          } else if (responseFromApi == '0') {
            await SMSDatabase.instance
                // legitimate response
                .updateisSentAPIAndApiValues(message.id, true, false, 5);
          } else if (responseFromApi == '2') {
            // if another status code is returned rather than 500
            await SMSDatabase.instance.updateisSentAPIAndApiValues(
                message.id, false, false, newcallcount + 1);
          } else if (responseFromApi == '3') {
            // at no internet connection
            await SMSDatabase.instance.updateisSentAPIAndApiValues(
                message.id, false, false, newcallcount);
          } else {
            // if 500 status got
            await SMSDatabase.instance
                .updateisSentAPIAndApiValues(message.id, true, false, 5);
          }
        }
      }

      if (message.isSentToAPI == true &&
          message.receiverNumber == widget.currentUserNumber &&
          message.isRead == false) {
        // print('recivernumber ${widget.currentUserNumber}');
        await SMSDatabase.instance.updateIsReadStatusOfMessages(message.id);
      }
    }
  }

  Future<void> sendSMS(String SMSMessage) async {
    final bool? permissionsGranted =
        await Telephony.instance.requestPhoneAndSmsPermissions;

    if (permissionsGranted != null && permissionsGranted) {
      try {
        String recivernumberString = widget.receiverNumber.toString();

        telephony.sendSms(
            to: recivernumberString,
            message: SMSMessage,
            statusListener: (s) => print(s.name));

        if (kDebugMode) {
          print('SMS sent successfully');
        }
      } catch (e) {
        if (kDebugMode) {
          print('Failed to send SMS: $e');
        }
      }
    }
    if (!mounted) return;
  }

  Future<void> fetchMessagesFromDatabase() async {
    print('\n\n\n\nFetch messages form database is called\n\n\n\n');
    try {
      if (!mounted) {
        return; // Check if the widget is still mounted
      }
      final List<Message> fetchedMessages =
          await fetchMessagesInChatFromDatabase(
              widget.receiverNumber, widget.currentUserNumber);
      if (!mounted) {
        return; // Check if the widget is still mounted
      }
      setState(() {
        messages = fetchedMessages;
      });
    } catch (e) {
      if (!mounted) {
        return; // Check if the widget is still mounted
      }
      debugPrint('Error fetching messages from the database: $e');
    }
  }

  Future<String> _sendMessageToAPI(String? message) async {
    if (kDebugMode) {
      print('api func called');
    }
    // Create the API URL
    // String apiUrl = 'http://10.0.2.2:8000/cybersmish';

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
        // Set the flag to true after successful API request
        // messagesSentToAPI = true;
        // Return the API response
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
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No Internet Connection. Please Enable Internet'),
        ),
      );
      if (kDebugMode) {
        print('The Internet connection is not available.');
      }
      return '3';
    }
  }

  void _sendMessage() async {
    String messageText = _messageController.text.trim();
    if (messageText.isNotEmpty) {
      String senderNumber = widget.currentUserNumber;
      String receiverNumber = widget.receiverNumber;
      try {
        await sendSMS(messageText);
        // print('Message sent to sendSMS function message is: $messageText');
      } catch (e) {
        // print('Failed to send SMS from _sendMessage function: $e');
      }

      await storeCurrentUserSendMessages(
          senderNumber, receiverNumber, messageText, false, true);

      // Clear the message box after sending the message
      _messageController.clear();

      // Fetch updated messages from the database
      await fetchMessagesFromDatabase();
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Navigate back to the SMSListener page
        Navigator.of(context).popUntil((route) => route.isFirst);
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.receiverName != null
                ? widget.receiverName.toString()
                : widget.receiverNumber.toString(),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                reverse: true, // Scroll to bottom initially
                child: Column(
                  children: messages.map((message) {
                    bool isSentByMe =
                        message.senderNumber == widget.currentUserNumber;
                    bool isSentToapiTrue = message.isSentToAPI == true;
                    bool isApiValueTrue = message.apiValue == true;
                    return MessageBubble(
                      message: message.messageBody,
                      isSentByMe: isSentByMe,
                      isSentToapiTrue: isSentToapiTrue,
                      isApiValueTrue: isApiValueTrue,
                      id: message.id,
                    );
                  }).toList(),
                ),
              ),
            ),
            _buildMessageBox(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBox() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 2,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(20.0),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: TextField(
                  controller: _messageController,
                  maxLines: null,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Type your message...',
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: _sendMessage,
            icon: const Icon(Icons.send),
            color: Theme.of(context).primaryColor,
          ),
        ],
      ),
    );
  }
}

class MessageBubble extends StatelessWidget {
  final int? id;
  final String message;
  final bool isSentByMe;
  final bool isSentToapiTrue;
  final bool isApiValueTrue;

  const MessageBubble({
    Key? key,
    required this.message,
    required this.isSentByMe,
    required this.isSentToapiTrue,
    required this.isApiValueTrue,
    required this.id,
  }) : super(key: key);

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Message'),
          content: const Text('Are you sure you want to delete this message?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                // Call the delete function from the database
                await SMSDatabase.instance.deleteMessageRecord(id);

                // Refresh the message list
                // ignore: use_build_context_synchronously
                Navigator.pop(context);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () {
        _showDeleteDialog(context);
      },
      child: Column(
        children: [
          Align(
            alignment:
                isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin:
                  const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: isSentToapiTrue
                    ? (isApiValueTrue
                        ? const Color.fromARGB(255, 227, 21, 21)
                        : (isSentByMe ? Colors.blueAccent : Colors.grey[300]))
                    : const Color.fromARGB(255, 250, 207, 143),
                borderRadius: BorderRadius.circular(16.0),
                boxShadow: [
                  BoxShadow(
                    color: const Color.fromARGB(255, 135, 134, 134)
                        .withOpacity(0.3),
                    spreadRadius: 2,
                    blurRadius: 4,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: isSentByMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: TextStyle(
                      color: isSentByMe || isApiValueTrue
                          ? Colors.white
                          : Colors.black,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(
                      height:
                          4), // Add spacing between message and "Verified" or "Not verified"
                  Text(
                    isSentToapiTrue
                        ? (isApiValueTrue ? 'Malicious' : 'Verified')
                        : 'Not verified',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
