import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/audio_metadata.dart';
import 'haudiotagger_metadata_reader.dart';

final audioMetadataReaderProvider = Provider<AudioMetadataReader>(
  (ref) => const HaudiotaggerMetadataReader(),
);
