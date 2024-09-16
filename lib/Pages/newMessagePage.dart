import 'package:contacts_service/contacts_service.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sms_test_app/Pages/chatpage.dart';

class NewMessagePage extends StatefulWidget {
  const NewMessagePage({super.key, Key});

  @override
  State<NewMessagePage> createState() => _NewMessagePageState();
}

class _NewMessagePageState extends State<NewMessagePage> {
  List<Contact> contacts = [];
  bool isLoading = true;

  TextEditingController toController = TextEditingController();

  String selectedToNumber = ''; // Variable to save the selected "To" number

  bool showContactsList = true; // Initially show the contact list

  @override
  void initState() {
    super.initState();
    _fetchContacts();
  }

  Future<void> _fetchContacts() async {
    final PermissionStatus status = await Permission.contacts.request();

    if (status.isGranted) {
      try {
        List<Contact> contacts =
            (await ContactsService.getContacts()).toList();
        setState(() {
          contacts = contacts;
          isLoading = false;
        });
      } catch (e) {
        print('Error fetching contacts: $e');
        setState(() {
          isLoading = false;
        });
      }
    } else {
      setState(() {
        isLoading = false;
      });
      print('Permission denied to access contacts.');
    }
  }

  Widget _buildContactList() {
    // Filter contacts based on the search query
    final filteredContacts = contacts.where((contact) {
      final query = toController.text.toLowerCase();
      return contact.displayName?.toLowerCase().contains(query) == true ||
          (contact.phones?.isNotEmpty == true &&
              contact.phones!.any((phone) =>
                  phone.value?.toLowerCase().contains(query) == true));
    }).toList();

    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    } else {
      return ListView.builder(
        shrinkWrap: true,
        itemCount: filteredContacts.length,
        itemBuilder: (context, index) {
          final Contact contact = filteredContacts[index];
          return ListTile(
            title: Text(contact.displayName ?? 'No name'),
            subtitle: Text(contact.phones?.elementAt(0).value ?? 'No phone'),
            leading: (contact.avatar != null && contact.avatar!.isNotEmpty)
                ? CircleAvatar(
                    backgroundImage: MemoryImage(contact.avatar!),
                  )
                : CircleAvatar(
                    child: Text(contact.initials()),
                  ),
            onTap: () {
              final selectedPhone = contact.phones?.elementAt(0).value ?? '';
              final selectedNumber = selectedPhone.isNotEmpty
                  ? selectedPhone.replaceAll(RegExp(r'[^\d]'), '')
                  : '';
              final receiverName = contact.displayName ?? 'Unknown';

              if (selectedNumber.isNotEmpty) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ChatPage(
                      currentUserNumber:
                          '9999999999', // Set your current user number here
                      receiverNumber: selectedNumber,
                      receiverName: receiverName,
                    ),
                  ),
                );
              }
            },
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Message'),
      ),
      body: Stack(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: <Widget>[
                TextFormField(
                  controller: toController,
                  decoration: InputDecoration(
                    hintText: 'To',
                    filled: true,
                    fillColor: const Color.fromARGB(220, 214, 229,
                        249), // Set the background color to light gray
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                          30), // Make it round at the curves
                      borderSide: BorderSide.none, // Remove the border
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  ),
                  onChanged: (_) {
                    setState(() {
                      showContactsList = true;
                    });
                  },
                  onEditingComplete: () {
                    final enteredNumber = toController.text;
                    if (enteredNumber.isNotEmpty) {
                      // Remove non-numeric characters from the entered number
                      final cleanedNumber =
                          enteredNumber.replaceAll(RegExp(r'[^\d]'), '');

                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => ChatPage(
                            currentUserNumber: '9999999999',
                            receiverNumber:
                                cleanedNumber, // Use the cleaned number
                          ),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          if (showContactsList)
            Positioned(
              top: 80,
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                color: Colors.white,
                child: _buildContactList(),
              ),
            ),
        ],
      ),
    );
  }
}
