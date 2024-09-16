// ignore_for_file: use_build_context_synchronously
import 'dart:async';
import 'dart:convert';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sms_test_app/Pages/chatpage.dart';
import 'package:sms_test_app/Pages/contactlist.dart';
import 'package:sms_test_app/Services/messageServices.dart';
import 'package:sms_test_app/db/messagesDB.dart';
import 'package:sms_test_app/main.dart';
import 'package:telephony/telephony.dart';
import 'package:http/http.dart' as http;

class SMSListner extends StatefulWidget {
  const SMSListner({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _SMSListnerState createState() => _SMSListnerState();
}

class _SMSListnerState extends State<SMSListner> {
  Telephony telephony = Telephony.instance;
  // List<SmsMessage> messages = [];
  List<int> readedmessages = [];
  String currentUserMobileNumber =
      '9999999999'; // Variable to store current user's mobile number
  List<int> fetchedMessages = [];

  Stream<Map<String, Map<String, dynamic>>> getMessageStream() async* {
    // Listen to the onMessageAdded stream to get notified when a new message is inserted

    await for (var _ in SMSDatabase.instance.onMessageAdded) {
      // Fetch updated sender/receiver data (numbers, timestamps, and messages) from the database and yield them
      final senderData =
          await SMSDatabase.instance.readAllSendersWithTimestampsAndMessages();
      // print(senderData.keys);
      // print(senderData.values);
      yield senderData;
    }
  }

  @override
  void initState() {
    super.initState();
    // getMessageStream();
    AwesomeNotifications().isNotificationAllowed().then((isAllowed) {
      if (kDebugMode) {
        print("Notification permission is allowed");
      }
      if (!isAllowed) {
        showDialog(
            context: context,
            builder: (context) => AlertDialog(
                  title: const Text('Allow Notifications'),
                  content: const Text(
                      'You will need to enable notifications for this app to receive messages'),
                  actions: [
                    TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: const Text('Cancel')),
                    TextButton(
                        onPressed: () {
                          AwesomeNotifications()
                              .requestPermissionToSendNotifications()
                              .then((_) {
                            Navigator.pop(context);
                          });
                        },
                        child: const Text('Allow'))
                  ],
                ));
      }
    });
    initPlatformState();
  }

  Future<void> initPlatformState() async {
    final bool? permissionsGranted =
        await Telephony.instance.requestPhoneAndSmsPermissions;

    if (permissionsGranted != null && permissionsGranted) {
      telephony.listenIncomingSms(
          onNewMessage: (SmsMessage message) async {
            await storeMessageInDatabase(message, false, false);
          },
          onBackgroundMessage: onBackgroundMessage);
    }

    // Fetch messages from the database and store them in the messages list
    await fetchChatListFromDatabase();

    if (!mounted) return;
  }

  @override
  void dispose() {
    // Close the StreamController when the state is disposed
    SMSDatabase.instance.close();
    super.dispose();
  }

  // @pragma('vm:entry-point')

// Send message to API before rendering it to user
  Future<String> _sendMessageToAPI(String? message) async {
    print('api func called');
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

  // Method to refresh messages by fetching them from the database again
  void refreshMessages() async {
    // Show a loading indicator while fetching messages
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Center(child: Text('CyberSmish')),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              // Delete all messages from the database
              await SMSDatabase.instance.deleteAll();
            },
          ),
        ],
      ),
      body: StreamBuilder<Map<String, Map<String, dynamic>>>(
        // initialData: {}, // Provide an empty map as initial data
        stream: getMessageStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Error'),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.connectionState == ConnectionState.active) {
            // Stream has data, so we can display the list
            Map<String, Map<String, dynamic>> senderData = snapshot.data!;

            return ListView.builder(
              itemCount: senderData.length,
              itemBuilder: (context, index) {
                String senderNumber = senderData.keys.elementAt(index);
                String? contactName = senderData[senderNumber]!['contactName'];

                DateTime timestamp = senderData[senderNumber]!['timestamp'];
                // Format the timestamp as 'date/month'
                String formattedTimestamp =
                    '${timestamp.day}/${timestamp.month}';

                // Retrieve the message from your data source
                String message = senderData[senderNumber]!['message'];
                bool isRead = senderData[senderNumber]!['isRead'];
                bool apiValue = senderData[senderNumber]!['apiValue'];
                bool isSenttoAPI = senderData[senderNumber]!['isSentToAPI'];

                Color messageColor = apiValue
                    ? Colors.red
                    : const Color.fromARGB(255, 98, 98, 98);

                Color? avatrColor = apiValue && isSenttoAPI
                    ? Colors.red
                    : isSenttoAPI
                        ? const Color.fromARGB(255, 97, 178, 245)
                        : const Color.fromARGB(255, 250, 207, 143);

                Color? circleColor = isRead
                    ? Colors.white
                    : apiValue && isSenttoAPI
                        ? Colors.red
                        : isSenttoAPI
                            ? const Color.fromARGB(255, 97, 178, 245)
                            : const Color.fromARGB(255, 250, 207, 143);

                return InkWell(
                  onLongPress: () async {
                    bool deleteConfirmed = await showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text('Delete Confirmation'),
                          content: Text(
                              'Are you sure you want to delete all messages from $contactName?'),
                          actions: <Widget>[
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text('DELETE'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('CANCEL'),
                            ),
                          ],
                        );
                      },
                    );

                    if (deleteConfirmed) {
                      // Call the deleteAllBySenderNumber function here
                      // var deletedNumber = removeCountryCode(senderNumber);
                      SMSDatabase.instance.deleteChatThread(senderNumber);

                      if (kDebugMode) {
                        print('senderData: $senderData');
                      }

                      // setState(() {
                      //   // Remove the item from the list
                      //   senderData.remove(senderNumber);
                      // });

                      // Show a snackbar to indicate that messages have been deleted
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Messages with $contactName have been deleted.'),
                        ),
                      );
                    }
                  },
                  onTap: () {
                    if (kDebugMode) {
                      print('Button tapped: $contactName');
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatPage(
                          currentUserNumber: currentUserMobileNumber,
                          receiverNumber: senderNumber,
                          receiverName: contactName ?? senderNumber,
                        ),
                      ),
                    );
                  },
                  splashColor: Colors.blue,
                  child: Card(
                    elevation: 0,
                    margin:
                        const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4.0),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        // backgroundColor: apiValue
                        //     ? Colors.red
                        //     : const Color.fromARGB(255, 97, 178, 245),
                        backgroundColor: avatrColor,
                        child: const Icon(
                          Icons.person,
                          color: Colors.white,
                        ),
                      ),
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            contactName ?? senderNumber,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16, // Increase the font size
                            ),
                          ),
                          Text(
                            formattedTimestamp,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey, // Change the timestamp color
                            ),
                          ),
                        ],
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      subtitle: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              message,
                              style: TextStyle(
                                fontSize: 14,
                                color:
                                    messageColor, // Change the message text color
                              ),
                              maxLines: 1, // Text fades out when it doesn't fit
                            ),
                          ),
                          Icon(
                            Icons.circle,
                            color: circleColor,
                            size: 15.0,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          } else {
            // Still waiting for data from the stream, display a loading indicator
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ContactPage(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
