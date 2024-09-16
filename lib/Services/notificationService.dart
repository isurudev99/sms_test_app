import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:sms_test_app/Pages/chatpage.dart';
import 'package:sms_test_app/db/messagesDB.dart';
import 'package:sms_test_app/main.dart';

// @pragma('vm:entry-point')
class NotificationService {
  @pragma('vm:entry-point')
  static Future<void> initNotification() async {
    AwesomeNotifications().initialize(
      null,
      [
        NotificationChannel(
          channelGroupKey: "High_Importance_Channel",
          channelKey: 'High_Importance_Channel',
          channelName: 'Basic_Notifications',
          channelDescription: 'Notification channel for basic tests',
          defaultColor: const Color(0xFF9D50DD),
          ledColor: Colors.white,
          playSound: true,
          enableVibration: true,
          importance: NotificationImportance.Max,
          channelShowBadge: true,
          criticalAlerts: true,
        ),
      ],
      channelGroups: [
        NotificationChannelGroup(
          channelGroupKey: "High_Importance_Channel_group",
          channelGroupName: "Group 1",
        ),
      ],
      debug: true,
    );

    await AwesomeNotifications().isNotificationAllowed().then((isAllowed) {
      if (!isAllowed) {
        AwesomeNotifications().requestPermissionToSendNotifications();
      }
    });

    await AwesomeNotifications().setListeners(
      onActionReceivedMethod: onActionReceivedMethod,
      onNotificationCreatedMethod: onNotificationCreatedMethod,
      onNotificationDisplayedMethod: onNotificationDisplayedMethod,
      onDismissActionReceivedMethod: onDismissActionReceivedMethod,
    );
  }

  // this is the method that will be called when the notification is created
  @pragma("vm:entry-point")
  static Future<void> onNotificationCreatedMethod(
      ReceivedNotification receivedNotification) async {
    debugPrint("onNotificationCreatedMethod: ${receivedNotification.id}");
  }

  // this is the method that will be called when the notification is Displayed
  @pragma("vm:entry-point")
  static Future<void> onNotificationDisplayedMethod(
      ReceivedNotification receivedNotification) async {
    debugPrint("onNotificationDisplayedMethod: ${receivedNotification.id}");
  }

  // this is the method that will be called when the notification is Dismissed
  @pragma("vm:entry-point")
  static Future<void> onDismissActionReceivedMethod(
      ReceivedAction receivedAction) async {
    debugPrint("onDismissActionReceivedMethod: ${receivedAction.id}");
  }

  // // use this method when user taps on notifications
  // static Future<void> onActionReceivedMethod(
  //     ReceivedAction receivedAction) async {
  //   debugPrint("onNotificationRecivedMethod: ${receivedAction.id}");
  //   final payload = receivedAction.payload ?? {};
  //   debugPrint("payload: $payload");
  //   if (payload["delete_message"] == "true") {
  //     MyApp.navigatorKey.currentState?.push(
  //       MaterialPageRoute(
  //         builder: (context) => const MyApp(),
  //       ),
  //     );
  //   }
  // }

  @pragma("vm:entry-point")
  static Future<void> onActionReceivedMethod(
      ReceivedAction receivedAction) async {
    debugPrint("onNotificationReceivedMethod: ${receivedAction.id}");

    final payload = receivedAction.payload ?? {};
    debugPrint("payload: $payload");

    final String? messageId = payload["messageId"];
    int intid = int.parse(messageId!);

    String? senderNumber = payload["currentUserNumber"];
    final contactName = payload["ContactName"];

    final actionKey = receivedAction.buttonKeyPressed;
    debugPrint('action type is: $actionKey');

    if (actionKey == 'delete_button') {
      debugPrint("Delete button was pressed");
      // Call your delete message logic with intId as the message ID
      await SMSDatabase.instance.deleteMessageRecord(intid);
    } else if (actionKey == 'mark_as_read_button') {
      debugPrint("Mark as Read button was pressed");
      // Call your mark as read logic with intId as the message ID
      await SMSDatabase.instance.updateIsReadStatusOfMessages(intid);
    } else {
      // Open the required ChatPage with sender and receiver numbers
      MyApp.navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => ChatPage(
            currentUserNumber: "9999999999",
            receiverNumber: senderNumber ?? "9999999999",
            receiverName: contactName, // Provide the receiver's name
          ),
        ),
      );
    }
  }

  @pragma('vm:entry-point')
  static Future<void> showNotification({
    final String? messageAddress,
    final String? body,
    final String? contactName,
    final String? summary,
    final Map<String, String>? payload,
    final ActionType actionType = ActionType.Default,
    final NotificationLayout notificationLayout = NotificationLayout.Default,
    required bool apiValue,
    required final bool isSenttoAPI,
    final NotificationCategory? notificationCategory,
    final String? bigPicture,
    final List<NotificationActionButton>? actionButtons,
    final bool scheduled = false,
    final int? interval,
  }) async {
    assert(!scheduled || (scheduled && interval != null));
    String? title = contactName ?? messageAddress;

    Color? backgroundColor = apiValue && isSenttoAPI
        ? Colors.red
        : isSenttoAPI
            ? const Color.fromARGB(255, 97, 178, 245)
            : const Color.fromARGB(255, 250, 207, 143);

    final actionButtons = [
      NotificationActionButton(
        key: 'delete_button',
        label: 'Delete',
        actionType: ActionType.SilentAction,
        color: Colors.red,
      ),
      NotificationActionButton(
        key: 'mark_as_read_button',
        label: 'Mark as Read',
        actionType: ActionType.SilentAction,
        color: Colors.blue,
      ),
    ];

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: -1,
        channelKey: 'High_Importance_Channel',
        title: title,
        body: body,
        backgroundColor: backgroundColor,
        actionType: actionType,
        notificationLayout: notificationLayout,
        summary: summary,
        category: notificationCategory,
        bigPicture: bigPicture,
        payload: payload,
      ),
      actionButtons: actionButtons,
      schedule: scheduled
          ? NotificationInterval(
              interval: interval,
              timeZone:
                  await AwesomeNotifications().getLocalTimeZoneIdentifier(),
              preciseAlarm: true,
              // allowWhileIdle: true,
            )
          : null,
    );
  }
}
