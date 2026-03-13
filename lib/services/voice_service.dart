import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter/foundation.dart';

class VoiceService {
  static final VoiceService _instance = VoiceService._internal();

  factory VoiceService() {
    return _instance;
  }

  VoiceService._internal();

  late stt.SpeechToText _speech;
  bool _isInitialized = false;
  String _currentLocale = 'en_US';

  // Use ValueNotifier to broadcast state changes
  final ValueNotifier<bool> isListeningNotifier = ValueNotifier(false);

  bool get isListening => isListeningNotifier.value;

  void setLocale(String locale) {
    _currentLocale = locale.replaceAll('-', '_');
  }

  Future<List<stt.LocaleName>> getAvailableLocales() async {
    if (!_isInitialized) {
      await initialize();
    }
    return _speech.locales();
  }

  Future<bool> initialize() async {
    if (_isInitialized) return true;
    _speech = stt.SpeechToText();
    try {
      _isInitialized = await _speech.initialize(
        onStatus: (status) {
          debugPrint('VoiceService Status: $status');
          if (status == 'listening') {
            isListeningNotifier.value = true;
          } else if (status == 'done' || status == 'notListening') {
            isListeningNotifier.value = false;
          }
        },
        onError: (error) {
          debugPrint('VoiceService Error: $error');
          isListeningNotifier.value = false;
        },
      );
    } catch (e) {
      debugPrint("VoiceService Initialization Error: $e");
      _isInitialized = false;
    }
    return _isInitialized;
  }

  void startListening({required Function(String) onResult}) async {
    if (!_isInitialized) {
      bool success = await initialize();
      if (!success) {
        debugPrint("Speech to text not initialized");
        return;
      }
    }

    if (!isListening) {
      isListeningNotifier.value = true;
      _speech.listen(
        onResult: (val) {
          if (val.hasConfidenceRating && val.confidence > 0) {
            onResult(val.recognizedWords);
          }
        },
        localeId: _currentLocale,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 5),
        partialResults: true,
        cancelOnError: true,
        listenMode: stt.ListenMode.confirmation,
      );
    }
  }

  void stopListening() {
    if (isListening) {
      _speech.stop();
      isListeningNotifier.value = false;
    }
  }
}
