const String tableMessages = 'messages';

class MessageFields {
  static final List<String> values = [
    /// Add all fields
    id, senderNumber, receiverNumber, contactName, messageBody, timeStamp,
    apiValue, isRead,
    isSentToAPI, callcount
  ];

  static const String id = '_id';
  static const String senderNumber = 'senderNumber';
  static const String receiverNumber = 'receiverNumber';
  static const String contactName = 'contactName';
  static const String messageBody = 'messageBody';
  static const String timeStamp = 'timeStamp';
  static const String apiValue = 'apiValue';
  static const String isRead = 'isRead';
  static const String isSentToAPI = 'isSentToAPI';
  static const String callcount = 'callcount';
}

class Message {
  final int? id;
  final String senderNumber;
  final String receiverNumber;
  final String? contactName;
  final String messageBody;
  final DateTime timeStamp;
  final bool? apiValue;
  final bool? isRead;
  final bool? isSentToAPI;
  final int? callcount;

  const Message({
    this.id,
    required this.senderNumber,
    required this.receiverNumber,
    this.contactName,
    required this.messageBody,
    required this.timeStamp,
    this.apiValue,
    this.isRead,
    this.isSentToAPI,
    this.callcount,
  });

  Message copy({
    int? id,
    String? senderNumber,
    String? receiverNumber,
    String? contactName,
    String? messageBody,
    DateTime? timeStamp,
    bool? apiValue,
    bool? isRead,
    bool? isSentToAPI,
    int? callcount,
  }) =>
      Message(
        id: id ?? this.id,
        senderNumber: senderNumber ?? this.senderNumber,
        receiverNumber: receiverNumber ?? this.receiverNumber,
        contactName: contactName ?? this.contactName,
        messageBody: messageBody ?? this.messageBody,
        timeStamp: timeStamp ?? this.timeStamp,
        apiValue: apiValue ?? this.apiValue,
        isRead: isRead ?? this.isRead,
        isSentToAPI: isSentToAPI ?? this.isSentToAPI,
        callcount: callcount ?? this.callcount,
      );

  static Message fromJson(Map<String, Object?> json) => Message(
        id: json[MessageFields.id] as int?,
        senderNumber: json[MessageFields.senderNumber].toString(),
        receiverNumber: json[MessageFields.receiverNumber].toString(),
        contactName: json[MessageFields.contactName] as String?,
        messageBody: json[MessageFields.messageBody] as String,
        timeStamp: DateTime.parse(json[MessageFields.timeStamp] as String),
        apiValue: json[MessageFields.apiValue] == 1,
        isRead: json[MessageFields.isRead] == 1,
        isSentToAPI: json[MessageFields.isSentToAPI] == 1,
        callcount: json[MessageFields.callcount] as int?,
      );

  Map<String, Object?> toJson() => {
        MessageFields.id: id,
        MessageFields.senderNumber: senderNumber,
        MessageFields.receiverNumber: receiverNumber,
        MessageFields.contactName: contactName,
        MessageFields.messageBody: messageBody,
        MessageFields.timeStamp: timeStamp.toIso8601String(),
        MessageFields.apiValue: apiValue == true ? 1 : 0,
        MessageFields.isRead: isRead == true ? 1 : 0,
        MessageFields.isSentToAPI: isSentToAPI == true ? 1 : 0,
        MessageFields.callcount: callcount,
      };
}
