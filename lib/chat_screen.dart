import 'package:flutter/material.dart';
import 'db_helper.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ChatMessage {
  final int? id;
  final String sender; // the user or the AI
  final String text;
  final String timestamp;

  ChatMessage({
    this.id,
    required this.sender,
    required this.text,
    required this.timestamp,
  });

  // Convert to map for easy to store into DB
  Map<String, dynamic> toMap() {
    return {
      'sender': sender,
      'text': text,
      'timestamp': timestamp,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'],
      sender: map['sender'],
      text: map['text'],
      timestamp: map['timestamp'],
    );
  }
}

class ChatScreen extends StatefulWidget {
  final String? targetDay;
  const ChatScreen({super.key, this.targetDay});

  @override
  State<ChatScreen> createState() => ChatScreenState();
}

class ChatScreenState extends State<ChatScreen> {
  // chat message lists (right now store in memory)
  final List<ChatMessage> _messages = [];
  // TextField controller, use for getting the context from the input
  final TextEditingController _textController = TextEditingController();
  // Text focus control
  final FocusNode _inputFocusNode = FocusNode();
  // Controller for the memories timeline
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener = ItemPositionsListener.create();

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _textController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  void focusInput() {
    _inputFocusNode.requestFocus();
  }

  void _scrollToBottom() {
    if (_messages.isEmpty || !_itemScrollController.isAttached) return;

    _itemScrollController.scrollTo(
      index: _messages.length - 1,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Future<void> _loadMessages() async {
    final data = await DBHelper.getAllMessages();

    setState(() {
      _messages
        ..clear()
        ..addAll(data.map((e) => ChatMessage.fromMap(e)));
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_messages.isEmpty || !_itemScrollController.isAttached) return;

      if (widget.targetDay != null) {
        final day = widget.targetDay!;
        final idx = _messages.indexWhere((m) => m.timestamp.startsWith(day));

        if (idx != -1) {
          _itemScrollController.scrollTo(
            index: idx,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            alignment: 0.2,
          );
          return;
        }
      }
      _scrollToBottom();
    });
  }

  // Save chat message to DB
  Future<void> _saveMessage(ChatMessage msg) async {
    await DBHelper.insertMessage(msg.toMap());
  }

  // Function call for user send message
  void _handleSend() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    // 1. add this user message into _messages list
    final now = DateTime.now().toIso8601String();
    final userMsg = ChatMessage(sender: 'user', text: text, timestamp: now);

    setState(() {
      _messages.add(userMsg);
    });
    _saveMessage(userMsg);
    // clear the input field
    _textController.clear();
    // keep cursor in input after sending
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _inputFocusNode.requestFocus();
    });
    // 2. call AI reply
    _callAIReply(text);
    // 3. scroll to the bottom
    _scrollToBottom();
  }

  Future<void> _callAIReply(String userText) async {
    // 1. create system prompt
    final systemPrompt = "You are Momo, a supportive emotional companion. "
        "Reply in a friendly, encouraging, empathetic tone. "
        "Keep responses short (1-3 sentences). "
        "If the user sounds stressed or tired, acknowledge feelings first.";
    final combinedUserMessage =
        "User says: \"$userText\"\n"
        "Respond as Momo, in gentle supportive style.";

    // 2. Gemini API key
    final geminiApiKey = dotenv.env['GEMINI_API_KEY'];
    if (geminiApiKey == null || geminiApiKey.isEmpty) {
      final now = DateTime.now().toIso8601String();
      final errorMsg = ChatMessage(
        sender: "ai",
        text: "API key is missing. Please check your .env file.",
        timestamp: now,
      );

      setState(() {
        _messages.add(errorMsg);
      });
      await _saveMessage(errorMsg);
      _scrollToBottom();
      return;
    }
    // 3. Google Gemini endpoint
    final uri = Uri.parse( "https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-lite-latest:generateContent?key=$geminiApiKey");
    try {
      final response = await http.post(
        uri,
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "contents": [
            {
              "role": "user",
              "parts": [
                {"text": systemPrompt},
                {"text": combinedUserMessage},
              ]
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Default value for the replyText if the api not works
        String replyText = "I'm here with you 💜";
        try {
          replyText = data["candidates"][0]["content"]["parts"][0]["text"];
        } catch(parseErr) {
          print("Parse AI reply error: $parseErr");
        }
        // Save to database and update UI
        final now = DateTime.now().toIso8601String();
        final aiMsg = ChatMessage(
            sender: "ai",
            text: replyText,
            timestamp: now
        );

        setState(() {
          _messages.add(aiMsg);
        });
        await _saveMessage(aiMsg);
        _scrollToBottom();
      } else {
        final now = DateTime.now().toIso8601String();
        final fallbackMsg = ChatMessage(
          sender: "ai",
          text:
          "Momo tried to think but got server error ${response.statusCode}. "
              "Even if I'm confused, I'm staying with you 💜",
          timestamp: now,
        );

        setState(() {
          _messages.add(fallbackMsg);
        });
        await _saveMessage(fallbackMsg);
        _scrollToBottom();
        print("Gemini API error ${response.statusCode}: ${response.body}");
      }
    } catch(e) {
      final now = DateTime.now().toIso8601String();
      final offlineMsg = ChatMessage(
        sender: "ai",
        text:
        "I can't reach my brain in the cloud right now, but I'm still here and I care about you 💜",
        timestamp: now,
      );

      setState(() {
        _messages.add(offlineMsg);
      });
      await _saveMessage(offlineMsg);
      _scrollToBottom();
      print("Gemini API exception: $e");
    }
  }

  void scrollToDay(String day,{String? keyword}) {
    if (_messages.isEmpty) return;

    int idx = -1;

    if (keyword != null && keyword.isNotEmpty) {
      // if have the keyword, then find the user message which contains the keyword on that day
      idx = _messages.indexWhere(
            (m) => m.timestamp.startsWith(day) &&
            m.sender == "user" &&
            m.text.toLowerCase().contains(keyword.toLowerCase()),
      );
    }

    // if not find the key word, then find the first user message on that day
    if (idx == -1) {
      idx = _messages.indexWhere(
            (m) => m.timestamp.startsWith(day) && m.sender == "user",
      );
    }

    // otherwise, find the first message on that day
    if (idx == -1) {
      idx = _messages.indexWhere(
            (m) => m.timestamp.startsWith(day),
      );
    }

    if (idx == -1) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _safeScrollTo(idx);
    });
  }

  void _safeScrollTo(int index) {
    if (!_itemScrollController.isAttached) return;
    if (index < 0 || index >= _messages.length) return;

    _itemScrollController.scrollTo(
      index: index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      alignment: 0.2,
    );
  }

  // UI bubble of a single message
  Widget _buildMessageBubble(ChatMessage msg) {
    final isUser = msg.sender == "user";

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,

      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        constraints: const BoxConstraints(maxWidth: 260),
        decoration: BoxDecoration(
          color: isUser ? Colors.deepPurple.shade100 : Colors.grey.shade200,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isUser
              ? const Radius.circular(16)
              : const Radius.circular(2),
            bottomRight: isUser
                ? const Radius.circular(2)
                : const Radius.circular(16),
          ),
        ),
        child: Text(
          msg.text,
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  // UI of chat message list area
  Widget _buildMessagesList() {
    return Expanded(
        child: ScrollablePositionedList.builder(
          itemScrollController: _itemScrollController,
          itemPositionsListener: _itemPositionsListener,
          itemCount: _messages.length,
          itemBuilder: (context, index) {
            final msg = _messages[index];
            return _buildMessageBubble(msg);
          },
        ),
    );
  }

  // UI for the input field and send button
  Widget _buildInputArea() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Colors.grey.shade300),
          ),
          color: Colors.white,
        ),
        child: Row(
          children: [
            Expanded(
                child: TextField(
                  focusNode: _inputFocusNode,
                  controller: _textController,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _handleSend(),
                  decoration: InputDecoration(
                    hintText: "Say something with Momo...",
                    hintStyle: TextStyle(
                      color: Colors.grey.shade400,
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade400, width: 2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade400, width: 2),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade400, width: 2),
                    ),
                  ),
                ),
            ),
            const SizedBox(width: 8),
            // Send button
            IconButton(
                onPressed: _handleSend,
                icon: const Icon(Icons.send),
              color: Colors.deepPurple,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Momo Chat",
                      style: TextStyle( fontSize: 32, fontFamily: "Baloo2",),
                    ),

                    IconButton(
                      tooltip: "Clear chat history",
                      icon: const Icon(Icons.delete_outline_rounded, size: 22),
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.deepPurple.shade50,
                        foregroundColor: Colors.deepPurple.shade500,
                        shape: CircleBorder(),
                      ),
                      onPressed: () async {
                        // 1. Clean the message table in DB
                        await DBHelper.clearMessages();
                        // 2. Clean the _messages list and rebuild UI
                        setState(() {
                          _messages.clear();
                        });
                      },
                    ),
                  ],
                ),
              ),
              _buildMessagesList(),
              _buildInputArea(),
            ],
          )
      )
    );
  }
}
