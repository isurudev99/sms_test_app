import 'dart:convert';
// import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sms_test_app/Pages/SMSListner.dart';
import 'package:background_fetch/background_fetch.dart' as bg;
import 'package:sms_test_app/Services/messageServices.dart';
import 'package:telephony/telephony.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'Services/notificationService.dart';

@pragma('vm:entry-point')
Future<void> onBackgroundMessage(SmsMessage message) async {
  if (kDebugMode) {
    print("onBackgroundMessage called in main.dart");
  }

  await storeMessageInDatabase(message, false, false);
}

// @pragma('vm:entry-point')
void backgroundFetchHeadlessTask(bg.HeadlessTask task) async {
  if (kDebugMode) {
    print('backgroundFetchHeadlessTask called');
  }
  var taskId = task.taskId;
  if (taskId == task.taskId) {
    // print(task.taskId);
    if (kDebugMode) {
      print('[BackgroundFetch] Headless event received.');
    }
    await NotificationService.initNotification();
    Telephony telephony = Telephony.instance;
    // print("initPlatformState main");
    telephony.listenIncomingSms(
      onNewMessage: (SmsMessage message) async {
        await storeMessageInDatabase(message, false, false);
      },
      onBackgroundMessage: onBackgroundMessage,
    );
  }
}

// Send message to API
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

void main() async {
  await NotificationService.initNotification();

  PermissionStatus permission = await Permission.contacts.status;
  if (permission != PermissionStatus.granted &&
      permission != PermissionStatus.permanentlyDenied) {
    await Permission.contacts.request();
    updateContactOnDatabase();
  } else {}

  runApp(const MyApp());

  // Registering backgroundFetch to receive events after app is terminated.
  // Requires {stopOnTerminate: false, enableHeadless: true}
  bg.BackgroundFetch.registerHeadlessTask(
      backgroundFetchHeadlessTask); // Use the bg prefix

  // Initialize background_fetch
  bg.BackgroundFetch.configure(
    bg.BackgroundFetchConfig(
      minimumFetchInterval: 15, // Fetch interval in minutes
      stopOnTerminate: false,
      startOnBoot: true,
      enableHeadless: true,
      requiresBatteryNotLow: false,
      requiresCharging: false,
      requiresStorageNotLow: false,
      requiresDeviceIdle: false,
      requiredNetworkType: bg.NetworkType.NONE, // Use the bg prefix
    ),
    (taskId) async {
      // This callback is called when the app is running
      // Use it to perform tasks if needed
      bg.BackgroundFetch.finish(taskId); // Use the bg prefix
    },
    (taskId) {
      // This callback is called when the background task times out
      bg.BackgroundFetch.finish(taskId); // Use the bg prefix
    },
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      home: const SMSListner(),
    );
  }
}
