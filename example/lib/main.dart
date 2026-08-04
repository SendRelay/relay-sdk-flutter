import 'dart:convert';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:relay_flutter/relay_flutter.dart';

void main() {
  // Enable logging for debugging
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    debugPrint('${record.level.name}: ${record.time}: ${record.message}');
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Relay Flutter SDK Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const TaskTrackerScreen(),
    );
  }
}

class TaskTrackerScreen extends StatefulWidget {
  const TaskTrackerScreen({super.key});

  @override
  State<TaskTrackerScreen> createState() => _TaskTrackerScreenState();
}

class _TaskTrackerScreenState extends State<TaskTrackerScreen> {
  late RelayRealtimeClient _relay;
  final TextEditingController _taskIdController = TextEditingController();
  final List<String> _listeningTasks = [];
  final Map<String, TaskStatus> _taskStatuses = {};
  final Map<String, Location?> _riderLocations = {};
  ConnectionState _connectionState = ConnectionState.disconnected;

  @override
  void initState() {
    super.initState();

    // Initialize Relay client
    _relay = RelayRealtimeClient(
      getToken: _fetchTokenFromBackend,
      autoRefresh: true,
      logger: Logger('RelaySDK'),
    );

    // Setup event listeners
    _setupEventListeners();
  }

  /// Fetch WebSocket token from your backend
  Future<String> _fetchTokenFromBackend(List<String> taskIds) async {
    // TODO: Replace with your actual backend endpoint
    const backendUrl = 'https://your-backend.com/api/relay/token';

    try {
      final response = await http.post(
        Uri.parse(backendUrl),
        headers: {
          'Content-Type': 'application/json',
          // Add your authentication header here
          // 'Authorization': 'Bearer $userToken',
        },
        body: jsonEncode({'taskIds': taskIds}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['token'] as String;
      } else {
        throw Exception('Failed to fetch token: ${response.statusCode}');
      }
    } catch (error) {
      debugPrint('Error fetching token: $error');
      rethrow;
    }
  }

  void _setupEventListeners() {
    // Task lifecycle events
    _relay.onTaskAssigned.listen((event) {
      setState(() {
        _taskStatuses[event.taskId] = event.status;
      });
      _showSnackBar('Task ${event.taskId} assigned to rider ${event.riderId}');
    });

    _relay.onTaskInProgress.listen((event) {
      setState(() {
        _taskStatuses[event.taskId] = event.status;
      });
      _showSnackBar('Task ${event.taskId} in progress');
    });

    _relay.onTaskCompleted.listen((event) {
      setState(() {
        _taskStatuses[event.taskId] = event.status;
      });
      _showSnackBar('Task ${event.taskId} completed!', isSuccess: true);
    });

    _relay.onTaskFailed.listen((event) {
      setState(() {
        _taskStatuses[event.taskId] = event.status;
      });
      _showSnackBar('Task ${event.taskId} failed: ${event.reason}',
          isError: true);
    });

    // Rider location updates
    _relay.onRiderLocationUpdate.listen((event) {
      setState(() {
        _riderLocations[event.taskId] = event.location;
      });
    });

    // Connection events
    _relay.onConnectionOpen.listen((_) {
      setState(() {
        _connectionState = ConnectionState.connected;
      });
      _showSnackBar('Connected to Relay', isSuccess: true);
    });

    _relay.onConnectionClose.listen((_) {
      setState(() {
        _connectionState = ConnectionState.disconnected;
      });
      _showSnackBar('Disconnected from Relay');
    });

    _relay.onConnectionReconnecting.listen((event) {
      setState(() {
        _connectionState = ConnectionState.reconnecting;
      });
      _showSnackBar('Reconnecting (attempt ${event.attempt})...');
    });

    _relay.onConnectionError.listen((event) {
      _showSnackBar('Connection error: ${event.error}', isError: true);
    });
  }

  Future<void> _listenToTask() async {
    final taskId = _taskIdController.text.trim();
    if (taskId.isEmpty) {
      _showSnackBar('Please enter a task ID', isError: true);
      return;
    }

    if (_listeningTasks.contains(taskId)) {
      _showSnackBar('Already listening to task $taskId');
      return;
    }

    try {
      await _relay.listen(taskId);
      setState(() {
        _listeningTasks.add(taskId);
        _taskStatuses[taskId] = TaskStatus.pending;
      });
      _taskIdController.clear();
      _showSnackBar('Listening to task $taskId', isSuccess: true);
    } catch (error) {
      _showSnackBar('Failed to listen to task: $error', isError: true);
    }
  }

  Future<void> _stopListening(String taskId) async {
    try {
      await _relay.stopListening(taskId);
      setState(() {
        _listeningTasks.remove(taskId);
        _taskStatuses.remove(taskId);
        _riderLocations.remove(taskId);
      });
      _showSnackBar('Stopped listening to task $taskId');
    } catch (error) {
      _showSnackBar('Failed to stop listening: $error', isError: true);
    }
  }

  void _showSnackBar(String message,
      {bool isSuccess = false, bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess
            ? Colors.green
            : isError
                ? Colors.red
                : null,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _relay.dispose();
    _taskIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Relay Flutter SDK Example'),
        actions: [
          _buildConnectionStatusChip(),
          const SizedBox(width: 16),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Task ID input
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Track a Task',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _taskIdController,
                      decoration: const InputDecoration(
                        labelText: 'Task ID',
                        hintText: 'Enter task ID (e.g., task-123)',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _listenToTask(),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _listenToTask,
                      icon: const Icon(Icons.add),
                      label: const Text('Start Tracking'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Active tasks list
            const Text(
              'Active Tasks',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: _listeningTasks.isEmpty
                  ? const Center(
                      child: Text('No active tasks\nAdd a task ID above'),
                    )
                  : ListView.builder(
                      itemCount: _listeningTasks.length,
                      itemBuilder: (context, index) {
                        final taskId = _listeningTasks[index];
                        final status = _taskStatuses[taskId];
                        final location = _riderLocations[taskId];

                        return Card(
                          child: ListTile(
                            leading: _buildStatusIcon(status),
                            title: Text(taskId),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Status: ${status?.value ?? "UNKNOWN"}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (location != null)
                                  Text(
                                    'Rider: ${location.latitude.toStringAsFixed(4)}, '
                                    '${location.longitude.toStringAsFixed(4)}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => _stopListening(taskId),
                              tooltip: 'Stop tracking',
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionStatusChip() {
    Color color;
    IconData icon;
    String label;

    switch (_connectionState) {
      case ConnectionState.connected:
        color = Colors.green;
        icon = Icons.check_circle;
        label = 'Connected';
        break;
      case ConnectionState.connecting:
        color = Colors.orange;
        icon = Icons.sync;
        label = 'Connecting';
        break;
      case ConnectionState.reconnecting:
        color = Colors.orange;
        icon = Icons.sync;
        label = 'Reconnecting';
        break;
      case ConnectionState.disconnected:
      case ConnectionState.disconnecting:
        color = Colors.red;
        icon = Icons.cloud_off;
        label = 'Disconnected';
        break;
    }

    return Chip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(label, style: TextStyle(color: color, fontSize: 12)),
      backgroundColor: color.withOpacity(0.1),
    );
  }

  Widget _buildStatusIcon(TaskStatus? status) {
    if (status == null) {
      return const Icon(Icons.help_outline, color: Colors.grey);
    }

    switch (status) {
      case TaskStatus.pending:
        return const Icon(Icons.pending, color: Colors.grey);
      case TaskStatus.offered:
        return const Icon(Icons.notifications_active, color: Colors.orange);
      case TaskStatus.assigned:
        return const Icon(Icons.person, color: Colors.blue);
      case TaskStatus.inProgress:
        return const Icon(Icons.directions_bike, color: Colors.purple);
      case TaskStatus.completed:
        return const Icon(Icons.check_circle, color: Colors.green);
      case TaskStatus.failed:
        return const Icon(Icons.error, color: Colors.red);
      case TaskStatus.cancelled:
        return const Icon(Icons.cancel, color: Colors.red);
      case TaskStatus.paymentFailed:
        return const Icon(Icons.warning_amber_rounded, color: Colors.deepOrange);
    }
  }
}
