// --- FILE: chat_screen.dart (UPDATED WITH KEY FACTS STORAGE & INITIAL MESSAGE) ---
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class ChatPage extends StatefulWidget {
  final String title;

  const ChatPage({super.key, required this.title});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final ChatUser _currentUser = ChatUser(id: "user");
  final ChatUser _aiUser = ChatUser(id: "ai", firstName: "Mitra");

  late final FirebaseAI _firebaseAI;
  late final GenerativeModel _model;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  final List<ChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Speech-to-Text
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _lastWords = '';

  // Text-to-Speech
  late FlutterTts _flutterTts;
  bool _isSpeaking = false;
  bool _speechEnabled = false;

  // User Profile Data
  Map<String, dynamic>? _userProfile;
  bool _isLoadingProfile = true;

  // PERSISTENT MEMORY
  Map<String, dynamic>? _persistentMemory;
  List<Map<String, dynamic>> _recentMemories = [];
  bool _isLoadingMemory = true;
  bool _initialMessageSent = false;

  final String _systemPrompt = """
You are Mitra — a warm, kind, and friendly companion for elderly users.

Your role:
You are not an assistant or doctor.
You are a caring friend who listens, supports, motivates, and keeps the user company.

Conversation style:
- Talk like a close friend, not a chatbot
- Keep replies short and natural (1–4 lines)
- No long paragraphs unless the user asks
- Use simple, easy words
- Be positive, calm, and lively
- Sound human and caring

Emotional behavior:
- If the user feels tired, sad, lonely, or unwell:
  • First show empathy
  • Then gently encourage
- Never judge or lecture
- Never sound robotic

Daily companion behavior:
- Ask gently about:
  • how they are feeling
  • whether they rested well
  • whether they took medicine
  • whether they ate or drank water
- Give reminders softly, like a friend

Examples (tone guidance):

If user says: "I feel tired"
Reply like:
"Hey… that’s okay. Some days are like that. You’re doing well. Did you get enough rest today?"

If user says: "I am not feeling well"
Reply like:
"I’m sorry you’re feeling that way. I’m here with you. Did you take your medicine? Want to tell me what’s bothering you?"

If user is quiet or unsure:
"I’m here 😊 Tell me, how are you feeling right now?"

Motivation:
- Encourage gently
- Praise small efforts
- Use reassuring words

Language support:
- If the user writes in Malayalam, reply in Malayalam
- If the user mixes Malayalam and English, reply in the same mixed style
- Keep Malayalam simple and conversational

Malayalam tone examples:
- "എന്താ, ഇന്ന് കുറച്ച് തളർച്ചയുണ്ടോ?"
- "ചിന്തിക്കണ്ട, ഞാൻ ഇവിടെ ഉണ്ടല്ലോ 🙂"
- "മരുന്ന് എടുത്തോ?"

Important rules:
- Do NOT give medical advice
- Do NOT diagnose diseases
- Do NOT use bold text, bullet points, or formatting
- Do NOT write long explanations
- Always stay in character as Mitra

Be a caring companion — like talking to a close friend.
""";

  @override
  void initState() {
    super.initState();
    _initializeAI();
    _initializeSpeech();
    _initializeTts();
    _loadUserProfile();
    _loadPersistentMemory();
  }

  void _initializeAI() {
    _firebaseAI = FirebaseAI.vertexAI(auth: FirebaseAuth.instance);
    _model = _firebaseAI.generativeModel(model: 'gemini-2.5-flash');
  }

  // ============================================
  // LOAD USER PROFILE
  // ============================================
  Future<void> _loadUserProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final docSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (docSnapshot.exists) {
          setState(() {
            _userProfile = docSnapshot.data();
            _isLoadingProfile = false;
          });
        } else {
          setState(() {
            _isLoadingProfile = false;
          });
        }
      }
    } catch (e) {
      print('Error loading user profile: $e');
      setState(() {
        _isLoadingProfile = false;
      });
    }
    _checkAndSendInitialMessage();
  }

  // ============================================
  // LOAD PERSISTENT MEMORY
  // ============================================
  Future<void> _loadPersistentMemory() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Get key facts
        final getKeyFactsCallable = _functions.httpsCallable('getAllKeyFacts');
        final factsResult = await getKeyFactsCallable.call();

        // Get recent memories
        final getMemoriesCallable = _functions.httpsCallable(
          'getRelevantMemories',
        );
        final memoriesResult = await getMemoriesCallable.call({
          'currentMessage': 'startup',
          'limit': 5,
        });

        setState(() {
          _persistentMemory = factsResult.data['keyFacts'] ?? {};
          _recentMemories = List<Map<String, dynamic>>.from(
            memoriesResult.data['memories'] ?? [],
          );
          _isLoadingMemory = false;
        });
      }
    } catch (e) {
      print('Error loading persistent memory: $e');
      setState(() {
        _isLoadingMemory = false;
      });
    }
    _checkAndSendInitialMessage();
  }

  // ============================================
  // CHECK AND SEND INITIAL MESSAGE
  // ============================================
  void _checkAndSendInitialMessage() {
    if (!_initialMessageSent && !_isLoadingProfile && !_isLoadingMemory) {
      _sendInitialMessage();
    }
  }

  // ============================================
  // BUILD USER CONTEXT WITH MEMORY
  // ============================================
  String _buildUserContext() {
    StringBuffer context = StringBuffer();

    context.writeln("\n\n### USER PROFILE INFORMATION:");
    context.writeln(
      "Use this information to personalize your interactions with the user.\n",
    );

    // Add profile information
    if (_userProfile != null) {
      if (_userProfile!['name'] != null) {
        context.writeln("- User's Name: ${_userProfile!['name']}");
      }
      if (_userProfile!['age'] != null) {
        context.writeln("- Age: ${_userProfile!['age']}");
      }
      if (_userProfile!['interests'] != null) {
        context.writeln("- Interests: ${_userProfile!['interests']}");
      }
      if (_userProfile!['hobbies'] != null) {
        context.writeln("- Hobbies: ${_userProfile!['hobbies']}");
      }
      if (_userProfile!['skills'] != null) {
        context.writeln("- Skills: ${_userProfile!['skills']}");
      }
    }

    // Add persistent memory facts
    if (_persistentMemory != null && _persistentMemory!.isNotEmpty) {
      context.writeln("\n### LEARNED FACTS FROM PREVIOUS CONVERSATIONS:");
      _persistentMemory!.forEach((key, value) {
        context.writeln("- $key: $value");
      });
    }

    // Add recent conversation context
    if (_recentMemories.isNotEmpty) {
      context.writeln("\n### RECENT CONVERSATION CONTEXT:");
      for (int i = 0; i < _recentMemories.take(3).length; i++) {
        final memory = _recentMemories[i];
        context.writeln("- User said: ${memory['userMessage']}");
        if (memory['keyFacts'] != null && memory['keyFacts'].isNotEmpty) {
          context.writeln("  Key points: ${memory['keyFacts'].join(', ')}");
        }
      }
    }

    context.writeln(
      "\nUse all this context to provide deeply personalized responses.",
    );
    return context.toString();
  }

  // ============================================
  // STORE CONVERSATION TO MEMORY & KEY FACTS
  // ============================================
  bool _isManglish(String text) {
    final lower = text.toLowerCase();

    const manglishKeywords = [
      'ennu',
      'ente',
      'enikku',
      'njan',
      'ningal',
      'anu',
      'illa',
      'undo',
      'sukham',
      'vishamam',
      'thonnunnu',
      'eduthu',
      'kazhicho',
      'kazhichu',
      'urakkam',
      'marunnu',
      'vedana',
    ];

    return manglishKeywords.any((word) => lower.contains(word));
  }

  String? _detectMood(String message) {
    final text = message.toLowerCase();

    // English
    if (text.contains('tired') ||
        text.contains('exhausted') ||
        text.contains('weak') ||
        text.contains('sleepy')) {
      return 'tired';
    }

    if (text.contains('sad') ||
        text.contains('lonely') ||
        text.contains('low') ||
        text.contains('depressed')) {
      return 'sad';
    }

    if (text.contains('happy') ||
        text.contains('good') ||
        text.contains('fine') ||
        text.contains('great')) {
      return 'happy';
    }

    // Malayalam (basic but effective)
    if (text.contains('തളർച്ച') ||
        text.contains('ക്ഷീണം') ||
        text.contains('വേദന')) {
      return 'tired';
    }

    if (text.contains('വിഷമം') ||
        text.contains('ഒറ്റപ്പെടല്') ||
        text.contains('ദുഖം')) {
      return 'sad';
    }

    return null;
  }

  Future<void> _storeConversationMemory(
    String userMessage,
    String aiResponse,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final firestore = FirebaseFirestore.instance;
      Future<void> _storeConversationMemory(
        String userMessage,
        String aiResponse,
      ) async {
        try {
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) return;

          final firestore = FirebaseFirestore.instance;

          // ============================
          // 🧠 NEW: DETECT & STORE MOOD
          // ============================
          final String? mood = _detectMood(userMessage);

          if (mood != null) {
            await firestore.collection('users').doc(user.uid).set({
              'lastMood': mood,
              'lastMoodAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          }

          // ============================
          // EXISTING LOGIC (UNCHANGED)
          // ============================

          // Extract key facts from the conversation
          List<String> keyFacts = _extractKeyFacts(userMessage, aiResponse);

          // 1. Store the memory entry (Cloud Function)
          final storeMemoryCallable = _functions.httpsCallable(
            'storeConversationMemory',
          );
          await storeMemoryCallable.call({
            'message': userMessage,
            'response': aiResponse,
            'keyFacts': keyFacts,
          });

          // 2. Store individual key facts to Firestore
          if (keyFacts.isNotEmpty) {
            final batch = firestore.batch();

            for (String fact in keyFacts) {
              final parts = fact.split(':');
              if (parts.length >= 2) {
                final key = parts[0].trim();
                final value = parts.sublist(1).join(':').trim();

                final factRef = firestore
                    .collection('users')
                    .doc(user.uid)
                    .collection('key_facts')
                    .doc(key);

                batch.set(factRef, {
                  'value': value,
                  'updatedAt': FieldValue.serverTimestamp(),
                  'factType': key,
                }, SetOptions(merge: true));
              }
            }

            await batch.commit();
          }

          // Reload memory for future context
          await _loadPersistentMemory();
        } catch (e) {
          print('Error storing memory: $e');
        }
      }

      // Extract key facts from the conversation
      List<String> keyFacts = _extractKeyFacts(userMessage, aiResponse);

      // 1. Store the memory entry
      final storeMemoryCallable = _functions.httpsCallable(
        'storeConversationMemory',
      );
      await storeMemoryCallable.call({
        'message': userMessage,
        'response': aiResponse,
        'keyFacts': keyFacts,
      });

      // 2. Store individual key facts to Firestore
      if (keyFacts.isNotEmpty) {
        final batch = firestore.batch();

        for (String fact in keyFacts) {
          // Parse fact to extract key and value (assumes format "key: value")
          final parts = fact.split(':');
          if (parts.length >= 2) {
            final key = parts[0].trim();
            final value = parts.sublist(1).join(':').trim();

            // Store in key_facts collection
            final factRef = firestore
                .collection('users')
                .doc(user.uid)
                .collection('key_facts')
                .doc(key);

            batch.set(factRef, {
              'value': value,
              'updatedAt': FieldValue.serverTimestamp(),
              'factType': key,
            }, SetOptions(merge: true));
          }
        }

        await batch.commit();
      }

      // Reload memory for future context
      await _loadPersistentMemory();
    } catch (e) {
      print('Error storing memory: $e');
    }
  }

  // ============================================
  // EXTRACT KEY FACTS FROM CONVERSATION
  // ============================================
  List<String> _extractKeyFacts(String userMessage, String aiResponse) {
    List<String> facts = [];

    // Simple pattern matching for key facts
    final patterns = [
      RegExp(r"my (.*?) is (\w+)", caseSensitive: false),
      RegExp(r"i (love|like|enjoy|hate|dislike) (\w+)", caseSensitive: false),
      RegExp(r"my (\w+) is named (\w+)", caseSensitive: false),
      RegExp(r"i have a (\w+) named (\w+)", caseSensitive: false),
      RegExp(r"(.*?) is my (.*)", caseSensitive: false),
    ];

    for (var pattern in patterns) {
      final matches = pattern.allMatches(userMessage);
      for (var match in matches) {
        if (match.groupCount >= 2) {
          facts.add("${match.group(1)}: ${match.group(2)}");
        }
      }
    }

    return facts;
  }

  Future<void> _initializeSpeech() async {
    _speech = stt.SpeechToText();
    await _speech.initialize(
      onError: (error) => print('Speech recognition error: $error'),
      onStatus: (status) => print('Speech recognition status: $status'),
    );
  }

  Future<void> _initializeTts() async {
    _flutterTts = FlutterTts();

    await _flutterTts.setSpeechRate(0.75);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    _flutterTts.setStartHandler(() {
      setState(() => _isSpeaking = true);
    });

    _flutterTts.setCompletionHandler(() {
      setState(() => _isSpeaking = false);
    });
  }

  void _sendInitialMessage() {
    String greeting =
        "Hello! I am Mitra, your personal companion. I'm here to chat, remind you of things, and keep you company.";

    if (_userProfile != null && _userProfile!['name'] != null) {
      greeting =
          "Hello ${_userProfile!['name']}! I am Mitra, your personal companion. I'm here to chat, remind you of things, and keep you company.";
    }

    final ChatMessage introMessage = ChatMessage(
      user: _aiUser,
      createdAt: DateTime.now(),
      text: greeting,
    );

    setState(() {
      _messages.insert(0, introMessage);
      _initialMessageSent = true;
    });

    if (_speechEnabled) {
      _speak(introMessage.text);
    }
  }

  Future<void> _speak(String text) async {
    if (!_speechEnabled) return;

    // Detect Malayalam characters
    final bool isMalayalam = RegExp(r'[\u0D00-\u0D7F]').hasMatch(text);

    if (isMalayalam) {
      await _flutterTts.setLanguage("ml-IN");
    } else {
      await _flutterTts.setLanguage("en-US");
    }

    await _flutterTts.speak(text);
  }

  Future<void> _stopSpeaking() async {
    await _flutterTts.stop();
    setState(() {
      _isSpeaking = false;
    });
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (result) {
            setState(() {
              _lastWords = result.recognizedWords;
              _controller.text = _lastWords;
            });
          },
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 5),
          cancelOnError: true,
          listenMode: stt.ListenMode.confirmation,
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();

      if (_controller.text.isNotEmpty) {
        _handleSend();
      }
    }
  }

  Future<void> _handleSend([String? text]) async {
    final messageText = text ?? _controller.text;
    if (messageText.trim().isEmpty) return;

    await _stopSpeaking();

    final userMessage = ChatMessage(
      user: _currentUser,
      createdAt: DateTime.now(),
      text: messageText,
    );

    setState(() {
      _messages.insert(0, userMessage);
      _controller.clear();
    });

    _scrollToTop();

    try {
      final String completePrompt = _systemPrompt + _buildUserContext();

      final bool isManglish = _isManglish(messageText);

      final response = await _model.generateContent([
        Content.text(completePrompt),
        Content.text(
          isManglish
              ? "User message (Manglish): $messageText\nReply warmly in simple Malayalam or Manglish, like a caring friend."
              : "User message: $messageText\nReply shortly, warmly, like a caring friend.",
        ),
      ]);

      final aiText = response.text ?? "Warning: No response from Mitra.";

      final aiMessage = ChatMessage(
        user: _aiUser,
        createdAt: DateTime.now(),
        text: aiText,
      );

      setState(() {
        _messages.insert(0, aiMessage);
      });

      // Store the conversation to persistent memory with key facts
      await _storeConversationMemory(messageText, aiText);

      _scrollToTop();
      await _speak(aiText);
    } catch (e) {
      final errorMessage = ChatMessage(
        user: _aiUser,
        createdAt: DateTime.now(),
        text: "Error: $e",
      );
      setState(() {
        _messages.insert(0, errorMessage);
      });

      _scrollToTop();
    }
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          Row(
            children: [
              const Icon(Icons.volume_up, size: 20),
              Switch(
                value: _speechEnabled,
                onChanged: (value) {
                  setState(() {
                    _speechEnabled = value;
                  });
                  if (!value) {
                    _stopSpeaking();
                  }
                },
                activeThumbColor: Colors.teal,
              ),
            ],
          ),
          if (_isSpeaking)
            IconButton(
              icon: const Icon(Icons.stop),
              onPressed: _stopSpeaking,
              tooltip: 'Stop speaking',
            ),
        ],
      ),
      body: (_isLoadingProfile || _isLoadingMemory)
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: DashChat(
                    currentUser: _currentUser,
                    messages: _messages,
                    inputOptions: InputOptions(
                      inputDisabled: true,
                      alwaysShowSend: false,
                      inputDecoration: const InputDecoration.collapsed(
                        hintText: '',
                      ),
                    ),
                    messageOptions: const MessageOptions(showTime: true),
                    onSend: (_) {},
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 25,
                        backgroundColor: _isListening
                            ? Colors.red
                            : Colors.blue,
                        child: IconButton(
                          icon: Icon(
                            _isListening ? Icons.mic : Icons.mic_none,
                            color: Colors.white,
                          ),
                          onPressed: _listen,
                          tooltip: _isListening
                              ? 'Stop listening'
                              : 'Start voice input',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          textInputAction: TextInputAction.send,
                          decoration: InputDecoration(
                            hintText: "Type a message...",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onSubmitted: (_) => _handleSend(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        radius: 25,
                        backgroundColor: Colors.teal,
                        child: IconButton(
                          icon: const Icon(Icons.send, color: Colors.white),
                          onPressed: _handleSend,
                          tooltip: 'Send message',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
