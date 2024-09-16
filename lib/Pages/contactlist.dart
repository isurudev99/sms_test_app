import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
// import 'package:permission_handler/permission_handler.dart';
import 'package:sms_test_app/Pages/chatpage.dart';
import 'package:sms_test_app/Services/messageServices.dart';
import 'package:sms_test_app/models/Contacts.dart';

class ContactPage extends StatefulWidget {
  const ContactPage({super.key});

  @override
  _ContactPageState createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage> {
  List<ContactData> contacts = []; // Replace with your list of contacts
  List<ContactData> filteredContacts = []; // Store filtered contacts

  TextEditingController searchController = TextEditingController();
  String newNumber = ''; // Store the newly entered number

  @override
  void initState() {
    super.initState();
    _askPermissions();
  }

  Future<void> _askPermissions() async {
    PermissionStatus permissionStatus = await _getContactPermission();
    if (permissionStatus == PermissionStatus.granted) {
      // Permission granted, you can proceed
      _loadContacts(); // Load contacts when permission is granted
    } else {
      _handleInvalidPermissions(permissionStatus);
    }
  }

  void navigateToChatPage(ContactData contact) {
    // String senderNumber = (contact.phoneNumberOne);
    String senderNumber = removeCountryCode(contact.phoneNumberOne);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChatPage(
          currentUserNumber:
              '9999999999', // Replace with your current user's number
          receiverNumber: senderNumber,
          receiverName: contact.contactName.isNotEmpty
              ? contact.contactName
              : contact.phoneNumberOne,
        ),
      ),
    );
  }

  void handleSearchSubmitted(String value) {
    setState(() {
      newNumber = value;
    });
    navigateToChatPage(ContactData(
      contactName: '', // You can set a name here or leave it empty
      phoneNumberOne: newNumber,
    ));
  }

  Future<PermissionStatus> _getContactPermission() async {
    PermissionStatus permission = await Permission.contacts.status;
    if (permission != PermissionStatus.granted &&
        permission != PermissionStatus.permanentlyDenied) {
      PermissionStatus permissionStatus = await Permission.contacts.request();
      return permissionStatus;
    } else {
      return permission;
    }
  }

  void _handleInvalidPermissions(PermissionStatus permissionStatus) {
    if (permissionStatus == PermissionStatus.denied) {
      const snackBar = SnackBar(
        content: Text('Access to contact data denied'),
      );
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
    } else if (permissionStatus == PermissionStatus.permanentlyDenied) {
      const snackBar = SnackBar(
        content: Text('Contact data not available on device'),
      );
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
    }
  }

  Future<void> _loadContacts() async {
    // Fetch contact data from the database
    List<ContactData> fetchedContacts = await fetchContactListFromDatabase();

    setState(() {
      contacts = fetchedContacts; // Update the contacts list
    });
  }

  void filterContacts(String query) {
    setState(() {
      filteredContacts = contacts.where((contact) {
        final name = contact.contactName.toLowerCase();
        final number = contact.phoneNumberOne.toLowerCase();
        final searchLower = query.toLowerCase();
        return name.contains(searchLower) || number.contains(searchLower);
      }).toList();
    });
  }

//
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New message'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              setState(() {
                _isLoading = true; // Set loading state to true
              });

              // Call a function to extract and store contacts here
              await updateContactOnDatabase();

              setState(() {
                _isLoading =
                    false; // Set loading state to false after execution
              });

              _loadContacts(); // Reload contacts when refreshing
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                labelText: 'To:',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: filterContacts,
              onSubmitted: handleSearchSubmitted, // Handle submission
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    // Show loading indicator while loading
                    child: CircularProgressIndicator(),
                  )
                : ListView.builder(
                    itemCount: searchController.text.isNotEmpty
                        ? filteredContacts.length
                        : contacts.length,
                    itemBuilder: (context, index) {
                      final contact = searchController.text.isNotEmpty
                          ? filteredContacts[index]
                          : contacts[index];
                      final initials = contact.contactName.isNotEmpty
                          ? contact.contactName.substring(0, 2).toUpperCase()
                          : '?';

                      return ListTile(
                        onTap: () => navigateToChatPage(contact),
                        leading: CircleAvatar(
                          backgroundColor: Colors.blueAccent.shade200,
                          foregroundColor: Colors.white,
                          child: Text(
                            initials,
                            style: const TextStyle(fontSize: 18.0),
                          ),
                        ),
                        title: Text(contact.contactName),
                        subtitle: Text(contact.phoneNumberOne),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
