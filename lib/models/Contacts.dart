import 'dart:typed_data';

const String tableContacts = 'contacts';

class ContactFields {
  static final List<String> values = [
    id,
    contactName,
    phoneNumberOne,
    phoneNumbertwo,
    avatar
  ];

  static const String id = '_id';
  static const String contactName = 'contactName';
  static const String phoneNumberOne = 'phoneNumberOne';
  static const String phoneNumbertwo = 'phoneNumbertwo';
  static const String avatar = 'avatar';
}

class ContactDB {
  final int? id;
  final String contactName;
  final String phoneNumberOne;
  final String? phoneNumbertwo;
  final Uint8List? avatar; // Store the avatar image data as Uint8List

  const ContactDB({
    this.id,
    required this.contactName,
    required this.phoneNumberOne,
    this.phoneNumbertwo,
    this.avatar,
  });

  ContactDB copy({
    int? id,
    String? contactName,
    String? phoneNumberOne,
    String? phoneNumbertwo,
    Uint8List? avatar,
  }) =>
      ContactDB(
        id: id ?? this.id,
        contactName: contactName ?? this.contactName,
        phoneNumberOne: phoneNumberOne ?? this.phoneNumberOne,
        phoneNumbertwo: phoneNumbertwo ?? this.phoneNumbertwo,
        avatar: avatar ?? this.avatar,
      );

  static ContactDB fromJson(Map<String, Object?> json) => ContactDB(
        id: json[ContactFields.id] as int?,
        contactName: json[ContactFields.contactName] as String,
        phoneNumberOne: json[ContactFields.phoneNumberOne] as String,
        phoneNumbertwo: json[ContactFields.phoneNumbertwo] as String?,
        avatar: json[ContactFields.avatar] as Uint8List?,
      );

  Map<String, Object?> toJson() => {
        ContactFields.id: id,
        ContactFields.contactName: contactName,
        ContactFields.phoneNumberOne: phoneNumberOne,
        ContactFields.phoneNumbertwo: phoneNumbertwo,
        ContactFields.avatar: avatar,
      };
}

class ContactData {
  final String contactName;
  final String phoneNumberOne;
  final Uint8List? avatar;

  ContactData({
    required this.contactName,
    required this.phoneNumberOne,
    this.avatar,
  });
}
