import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    if (!Platform.isLinux && !Platform.isMacOS && !Platform.isWindows) {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      
      const InitializationSettings initializationSettings =
          InitializationSettings(android: initializationSettingsAndroid);
      
      await flutterLocalNotificationsPlugin.initialize(initializationSettings);
    }
  } catch (e) {
    print("Bildirim başlatılamadı: $e");
  }

  final prefs = await SharedPreferences.getInstance();
  final savedName = prefs.getString('my_name');
  runApp(SimpleChatApp(initialName: savedName));
}

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class SimpleChatApp extends StatelessWidget {
  final String? initialName;
  const SimpleChatApp({super.key, this.initialName});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: initialName != null && initialName!.isNotEmpty
          ? ChatScreen(myUsername: initialName!)
          : const LoginScreen(),
    );
  }
}

// LOGIN SCREEN
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _controller = TextEditingController();

  void _saveAndEnter() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('my_name', name);

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => ChatScreen(myUsername: name)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Enter Your Name to Start", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextField(
                controller: _controller,
                decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "Username"),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveAndEnter,
                child: const Text("Connect"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MessageItem {
  final String sender;
  final String text;
  final bool isGroup;
  final String target;
  Timer? expiryTimer;

  MessageItem({
    required this.sender,
    required this.text,
    required this.isGroup,
    required this.target,
    this.expiryTimer,
  });
}

class ChatScreen extends StatefulWidget {
  final String myUsername;
  const ChatScreen({super.key, required this.myUsername});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  WebSocketChannel? _channel;
  final TextEditingController _msgController = TextEditingController();
  final TextEditingController _targetController = TextEditingController();
  final TextEditingController _groupController = TextEditingController();
  
  String? _currentChatTarget; 
  bool _isGroupChat = false;
  
  final List<MessageItem> _messages = [];
  final List<String> _logs = [];
  
  List<String> _groupMembers = [];
  String? _systemNotification;

  late AnimationController _clockController;

  @override
  void initState() {
    super.initState();
    _clockController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    _connectWebSocket();
  }

  Future<void> _showPhoneNotification({required String title, required String body}) async {
    if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) return;

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'chat_channel_id',
      'Chat Notifications',
      channelDescription: 'New message notifications',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
    );
    
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    
    int notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await flutterLocalNotificationsPlugin.show(
      notificationId,
      title,
      body,
      platformChannelSpecifics,
    );
  }

  void _connectWebSocket() {
    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('wss://websocket-server-c1w9.onrender.com'),
      );

      _channel!.sink.add(jsonEncode({
        "type": "register",
        "sender": widget.myUsername,
      }));

      _channel!.stream.listen((message) {
        try {
          final data = jsonDecode(message);
          
          if (data['type'] == 'message') {
            final sender = data['sender'];
            final text = data['text'];
            _addDisappearingMessage(sender: sender, text: text, isGroup: false, target: sender);

            if (_currentChatTarget != sender || _isGroupChat) {
              _showPhoneNotification(title: "New DM from $sender", body: text);
            }
          } 
          else if (data['type'] == 'group_message') {
            final sender = data['sender'];
            final text = data['text'];
            final group = data['group'];
            _addDisappearingMessage(sender: sender, text: text, isGroup: true, target: group);

            if (_currentChatTarget != group || !_isGroupChat) {
              _showPhoneNotification(title: "[$group] $sender", body: text);
            }
          }
          else if (data['type'] == 'presence_notification') {
            setState(() {
              _systemNotification = data['text'];
            });
            Timer(const Duration(seconds: 4), () {
              if (mounted) setState(() => _systemNotification = null);
            });
          }
          else if (data['type'] == 'group_update') {
            if (data['group'] == _currentChatTarget && _isGroupChat) {
              setState(() {
                _groupMembers = List<String>.from(data['members']);
                _systemNotification = data['notification'];
              });
              Timer(const Duration(seconds: 4), () {
                if (mounted) setState(() => _systemNotification = null);
              });
            }
          }
          else {
            setState(() {
              _logs.add("System: $message");
            });
          }
        } catch (_) {
          setState(() {
            _logs.add("Received: $message");
          });
        }
      }, onError: (err) {
        setState(() => _logs.add("Error: $err"));
      }, onDone: () {
        setState(() => _logs.add("Connection closed."));
      });
    } catch (e) {
      setState(() => _logs.add("Failed to connect: $e"));
    }
  }

  void _addDisappearingMessage({required String sender, required String text, required bool isGroup, required String target}) {
    late MessageItem item;
    final timer = Timer(const Duration(seconds: 10), () {
      if (mounted) {
        setState(() {
          _messages.remove(item);
        });
      }
    });

    item = MessageItem(
      sender: sender,
      text: text,
      isGroup: isGroup,
      target: target,
      expiryTimer: timer,
    );

    setState(() {
      _messages.add(item);
    });
  }

  void _sendMessage() {
    final text = _msgController.text.trim();
    if (text.isEmpty || _currentChatTarget == null) return;

    Map<String, dynamic> packet;
    if (_isGroupChat) {
      packet = {
        "type": "group_message",
        "sender": widget.myUsername,
        "group": _currentChatTarget,
        "text": text,
      };
    } else {
      packet = {
        "type": "message",
        "sender": widget.myUsername,
        "receiver": _currentChatTarget,
        "text": text,
      };
    }

    _channel?.sink.add(jsonEncode(packet));

    _addDisappearingMessage(
      sender: widget.myUsername,
      text: text,
      isGroup: _isGroupChat,
      target: _currentChatTarget!,
    );

    _msgController.clear();
  }

  void _setDirectTarget() {
    final target = _targetController.text.trim();
    if (target.isNotEmpty) {
      setState(() {
        _currentChatTarget = target;
        _isGroupChat = false;
        _systemNotification = null;
      });

      _channel?.sink.add(jsonEncode({
        "type": "join_dm_presence",
        "sender": widget.myUsername,
        "receiver": target,
      }));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Opened DM with: $target")),
      );
    }
  }

  void _joinGroup() {
    final group = _groupController.text.trim();
    if (group.isNotEmpty) {
      setState(() {
        _currentChatTarget = group;
        _isGroupChat = true;
        _groupMembers = [widget.myUsername];
        _systemNotification = null;
      });
      
      _channel?.sink.add(jsonEncode({
        "type": "join_group",
        "sender": widget.myUsername,
        "group": group,
      }));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Joined group: $group")),
      );
    }
  }

  @override
  void dispose() {
    _clockController.dispose();
    for (var msg in _messages) {
      msg.expiryTimer?.cancel();
    }
    _channel?.sink.close();
    _msgController.dispose();
    _targetController.dispose();
    _groupController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeMessages = _currentChatTarget == null
        ? <MessageItem>[]
        : _messages.where((m) => m.target == _currentChatTarget).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text("User: ${widget.myUsername} ${_currentChatTarget != null ? '($_isGroupChat ? Group : DM): $_currentChatTarget' : ''}"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _targetController,
                    decoration: const InputDecoration(
                      labelText: "Target Username (DM)",
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _setDirectTarget,
                  child: const Text("Chat DM"),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _groupController,
                    decoration: const InputDecoration(
                      labelText: "Group Name",
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _joinGroup,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                  child: const Text("Join Group"),
                ),
              ],
            ),
            
            if (_isGroupChat && _currentChatTarget != null) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Online Members in Group: ${_groupMembers.join(', ')}",
                  style: const TextStyle(fontSize: 12, color: Colors.amberAccent),
                ),
              ),
            ],

            const Divider(height: 15),
            
            Expanded(
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _currentChatTarget == null
                        ? Center(
                            child: Text(
                              "System Logs / Status:\n${_logs.join('\n')}",
                              style: const TextStyle(color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : ListView.builder(
                            itemCount: activeMessages.length,
                            itemBuilder: (context, index) {
                              final msg = activeMessages[index];
                              final isMe = msg.sender == widget.myUsername;
                              return Align(
                                alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isMe ? Colors.teal[800] : Colors.grey[800],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          "${msg.sender}: ${msg.text}",
                                          style: const TextStyle(fontSize: 16, color: Colors.white),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      RotationTransition(
                                        turns: _clockController,
                                        child: const Icon(Icons.access_time, size: 16, color: Colors.amberAccent),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),

                  if (_systemNotification != null)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.tealAccent, width: 1),
                        ),
                        child: Text(
                          _systemNotification!,
                          style: const TextStyle(color: Colors.tealAccent, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    decoration: InputDecoration(
                      hintText: _currentChatTarget == null ? "Select target or group first..." : "Type your message...",
                      border: const OutlineInputBorder(),
                    ),
                    enabled: _currentChatTarget != null,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.tealAccent, size: 30),
                  onPressed: _currentChatTarget != null ? _sendMessage : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
