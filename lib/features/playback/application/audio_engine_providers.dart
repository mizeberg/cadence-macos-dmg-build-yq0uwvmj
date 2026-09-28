import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/audio_engine.dart';
import '../data/audio_output_models.dart';

final audioOutputDevicesProvider = StreamProvider<List<AudioOutputDevice>>(
  (ref) => ref.watch(audioEngineProvider).outputDevicesStream,
);

final selectedAudioOutputProvider = StreamProvider<AudioOutputDevice>(
  (ref) => ref.watch(audioEngineProvider).outputDeviceStream,
);

final decodedAudioFormatProvider = StreamProvider<DecodedAudioFormat?>(
  (ref) => ref.watch(audioEngineProvider).decodedFormatStream,
);

final audioBufferingProvider = StreamProvider<bool>(
  (ref) => ref.watch(audioEngineProvider).bufferingStream,
);

final audioBufferPositionProvider = StreamProvider<Duration>(
  (ref) => ref.watch(audioEngineProvider).bufferPositionStream,
);
