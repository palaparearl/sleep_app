import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

enum NoiseType { white, pink, brown }

// ─── Noise Generator ───

Uint8List _generateNoiseWav(NoiseType type) {
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

  // Generate samples into a temporary double list, then normalize
  final random = Random(42);
  final samples = List<double>.filled(numSamples, 0);

  switch (type) {
    case NoiseType.white:
      for (var i = 0; i < numSamples; i++) {
        samples[i] = random.nextDouble() * 2 - 1;
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
        samples[i] = pink;
      }

    case NoiseType.brown:
      double last = 0;
      for (var i = 0; i < numSamples; i++) {
        final white = random.nextDouble() * 2 - 1;
        last = (last + 0.10 * white).clamp(-1.0, 1.0);
        samples[i] = last;
      }
  }

  // RMS normalize with perceptual loudness compensation
  // Brown noise needs a higher RMS because human hearing is less sensitive
  // to low frequencies; pink needs a slight boost for the same reason.
  final targetRms = switch (type) {
    NoiseType.white => 0.18,
    NoiseType.pink  => 0.22,
    NoiseType.brown => 0.50,
  };

  var sumSquares = 0.0;
  for (final s in samples) {
    sumSquares += s * s;
  }
  final rms = sqrt(sumSquares / numSamples);
  final scale = rms > 0 ? targetRms / rms : 0.0;

  for (var i = 0; i < numSamples; i++) {
    final sample = (samples[i] * scale * 32767).round().clamp(-32767, 32767);
    buffer.setInt16(44 + i * 2, sample, Endian.little);
  }

  return buffer.buffer.asUint8List();
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
    final wavBytes = _generateNoiseWav(type);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${type.name}_noise.wav');
    await file.writeAsBytes(wavBytes, flush: true);
    await player.setFilePath(file.path);
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

  Future<void> playAudiobook(String url, String title, String author) async {
    await player.stop();
    try {
      await player.setUrl(url).timeout(const Duration(seconds: 15));
      await player.setLoopMode(LoopMode.off);
      _currentTitle = title;
      _currentCategory = 'Audiobook · $author';
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
