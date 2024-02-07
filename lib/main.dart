import 'dart:async';
import 'package:flutter/material.dart';
import 'package:call_log/call_log.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Call Log App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const CallLogScreen(),
    );
  }
}

class CallLogScreen extends StatefulWidget {
  const CallLogScreen({Key? key}) : super(key: key);

  @override
  _CallLogScreenState createState() => _CallLogScreenState();
}

class _CallLogScreenState extends State<CallLogScreen> {
  List<CallLogEntry> _callLogs = [];
  List<CallLogEntry> _filteredCallLogs = [];
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _checkPermissionAndLoadCallLogs();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _checkPermissionAndLoadCallLogs() async {
    final permissionStatus = await Permission.phone.request();
    if (permissionStatus.isGranted) {
      _loadCallLogs();
    } else {
      print('Phone permission denied.');
    }
  }

  Future<void> _loadCallLogs() async {
    try {
      final callLogs = await CallLog.get();
      setState(() {
        _callLogs = callLogs.toList();
        _filteredCallLogs = List.from(_callLogs); // Initialize filtered list
      });
    } catch (e) {
      print('Failed to get call logs: $e');
    }
  }

  void _filterCallLogs(String query) {
    setState(() {
      if (query.isEmpty) {
        // If query is empty, show all call logs
        _filteredCallLogs = List.from(_callLogs);
      } else {
        // Filter call logs by name or number containing the query as a substring
        _filteredCallLogs = _callLogs.where((log) {
          final name = log.name ?? '';
          final number = log.number ?? '';
          return name.toLowerCase().contains(query.toLowerCase()) ||
              number.contains(query);
        }).toList();
      }
    });
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _filterCallLogs(_searchController.text);
    });
  }

  void _navigateToRecentCalls() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecentCallsScreen(callLogs: _callLogs),
      ),
    );
  }

  void _navigateToAllContacts() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AllContactsScreen(callLogs: _callLogs),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Call Log'),
        actions: [
          IconButton(
            icon: Icon(Icons.access_time),
            onPressed: _navigateToRecentCalls,
          ),
          IconButton(
            icon: Icon(Icons.contacts),
            onPressed: _navigateToAllContacts,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search',
                hintText: 'Search by name or number',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: _filteredCallLogs.isEmpty
                ? const Center(
                    child: Text('No call logs available.'),
                  )
                : ListView.builder(
                    itemCount: _filteredCallLogs.length,
                    itemBuilder: (context, index) {
                      final callLog = _filteredCallLogs[index];
                      return ListTile(
                        leading: const Icon(Icons.phone),
                        title: Text(callLog.name ?? 'Unknown'),
                        subtitle: Text(
                          '${callLog.number ?? 'Unknown'} - ${DateTime.fromMillisecondsSinceEpoch(callLog.timestamp!)}',
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class RecentCallsScreen extends StatelessWidget {
  final List<CallLogEntry> callLogs;

  const RecentCallsScreen({Key? key, required this.callLogs}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final sortedCallLogs = callLogs.toList()
      ..sort((a, b) => b.timestamp!.compareTo(a.timestamp!));

    return Scaffold(
      appBar: AppBar(
        title: Text('Recent Calls'),
      ),
      body: ListView.builder(
        itemCount: sortedCallLogs.length,
        itemBuilder: (context, index) {
          final callLog = sortedCallLogs[index];
          return ListTile(
            leading: const Icon(Icons.phone),
            title: Text(callLog.name ?? 'Unknown'),
            subtitle: Text(
              '${callLog.number ?? 'Unknown'} - ${DateTime.fromMillisecondsSinceEpoch(callLog.timestamp!)}',
            ),
          );
        },
      ),
    );
  }
}

class AllContactsScreen extends StatelessWidget {
  final List<CallLogEntry> callLogs;

  const AllContactsScreen({Key? key, required this.callLogs}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final contactsMap = <String, List<CallLogEntry>>{};
    callLogs.forEach((log) {
      final key = log.name ?? '';
      if (!contactsMap.containsKey(key)) {
        contactsMap[key] = [];
      }
      contactsMap[key]!.add(log);
    });

    final sortedKeys = contactsMap.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: Text('All Contacts'),
      ),
      body: ListView.builder(
        itemCount: sortedKeys.length,
        itemBuilder: (context, index) {
          final key = sortedKeys[index];
          final logs = contactsMap[key]!;
          return ExpansionTile(
            title: Text(key),
            children: logs.map((log) {
              return ListTile(
                leading: const Icon(Icons.phone),
                title: Text(log.name ?? 'Unknown'),
                subtitle: Text(
                  '${log.number ?? 'Unknown'} - ${DateTime.fromMillisecondsSinceEpoch(log.timestamp!)}',
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
