import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:just_audio/just_audio.dart';

enum NoiseType { white, pink, brown }

// ─── Noise Generator ───

class _NoiseAudioSource extends StreamAudioSource {
  final Uint8List _bytes;

  _NoiseAudioSource(NoiseType type) : _bytes = _generateNoise(type);

  static Uint8List _generateNoise(NoiseType type) {
    const sampleRate = 22050;
    const durationSecs = 30;
    const numSamples = sampleRate * durationSecs;
    const dataSize = numSamples * 2; // 16-bit = 2 bytes per sample
    final buffer = ByteData(44 + dataSize);

    // WAV header
    void writeString(int offset, String s) {
      for (var i = 0; i < s.length; i++) {
        buffer.setUint8(offset + i, s.codeUnitAt(i));
      }
    }

    writeString(0, 'RIFF');
    buffer.setUint32(4, 36 + dataSize, Endian.little);
    writeString(8, 'WAVE');
    writeString(12, 'fmt ');
    buffer.setUint32(16, 16, Endian.little); // chunk size
    buffer.setUint16(20, 1, Endian.little); // PCM
    buffer.setUint16(22, 1, Endian.little); // mono
    buffer.setUint32(24, sampleRate, Endian.little);
    buffer.setUint32(28, sampleRate * 2, Endian.little); // byte rate
    buffer.setUint16(32, 2, Endian.little); // block align
    buffer.setUint16(34, 16, Endian.little); // bits per sample
    writeString(36, 'data');
    buffer.setUint32(40, dataSize, Endian.little);

    // Generate samples
    final random = Random(42);
    const amplitude = 6000; // ~18% of max — gentle volume

    switch (type) {
      case NoiseType.white:
        for (var i = 0; i < numSamples; i++) {
          final sample = ((random.nextDouble() * 2 - 1) * amplitude).toInt();
          buffer.setInt16(44 + i * 2, sample, Endian.little);
        }

      case NoiseType.pink:
        // Voss-McCartney pink noise algorithm
        double b0 = 0, b1 = 0, b2 = 0, b3 = 0, b4 = 0, b5 = 0, b6 = 0;
        for (var i = 0; i < numSamples; i++) {
          final white = random.nextDouble() * 2 - 1;
          b0 = 0.99886 * b0 + white * 0.0555179;
          b1 = 0.99332 * b1 + white * 0.0750759;
          b2 = 0.96900 * b2 + white * 0.1538520;
          b3 = 0.86650 * b3 + white * 0.3104856;
          b4 = 0.55000 * b4 + white * 0.5329522;
          b5 = -0.7616 * b5 - white * 0.0168980;
          final pink = b0 + b1 + b2 + b3 + b4 + b5 + b6 + white * 0.5362;
          b6 = white * 0.115926;
          final sample = (pink * 1000).clamp(-amplitude, amplitude).toInt();
          buffer.setInt16(44 + i * 2, sample, Endian.little);
        }

      case NoiseType.brown:
        double last = 0;
        for (var i = 0; i < numSamples; i++) {
          final white = random.nextDouble() * 2 - 1;
          last = (last + 0.02 * white).clamp(-1.0, 1.0);
          final sample = (last * amplitude).toInt();
          buffer.setInt16(44 + i * 2, sample, Endian.little);
        }
    }

    return buffer.buffer.asUint8List();
  }

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= _bytes.length;
    return StreamAudioResponse(
      sourceLength: _bytes.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(_bytes.sublist(start, end)),
      contentType: 'audio/wav',
    );
  }
}

// ─── Audio Service Singleton ───

class SleepAudioService {
  static final SleepAudioService _instance = SleepAudioService._();
  factory SleepAudioService() => _instance;
  SleepAudioService._();

  final AudioPlayer player = AudioPlayer();
  Timer? _sleepTimer;
  DateTime? _sleepTimerEnd;
  String _currentTitle = '';
  String _currentCategory = '';

  String get currentTitle => _currentTitle;
  String get currentCategory => _currentCategory;
  bool get isPlaying => player.playing;

  Duration? get sleepTimerRemaining {
    if (_sleepTimerEnd == null) return null;
    final remaining = _sleepTimerEnd!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  Future<void> playNoise(NoiseType type) async {
    await player.stop();
    final source = _NoiseAudioSource(type);
    await player.setAudioSource(source);
    await player.setLoopMode(LoopMode.one);
    _currentTitle =
        '${type.name[0].toUpperCase()}${type.name.substring(1)} Noise';
    _currentCategory = 'Generated';
    await player.play();
  }

  Future<void> playStream(String url, String title) async {
    await player.stop();
    try {
      await player.setUrl(url).timeout(const Duration(seconds: 8));
      _currentTitle = title;
      _currentCategory = 'Radio';
      await player.play();
    } catch (_) {
      _currentTitle = '';
      _currentCategory = '';
      rethrow;
    }
  }

  Future<void> togglePlayPause() async {
    if (player.playing) {
      await player.pause();
    } else {
      await player.play();
    }
  }

  Future<void> stop() async {
    await player.stop();
    _currentTitle = '';
    _currentCategory = '';
    cancelSleepTimer();
  }

  void setSleepTimer(Duration duration) {
    cancelSleepTimer();
    _sleepTimerEnd = DateTime.now().add(duration);
    _sleepTimer = Timer(duration, () {
      stop();
    });
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepTimerEnd = null;
  }
}
