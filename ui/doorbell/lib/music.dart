import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:glob/list_local_fs.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:path/path.dart' as p;
import 'package:m3u_nullsafe/m3u_nullsafe.dart';

class PositionData {
  final Duration position;
  final Duration bufferedPosition;
  final Duration duration;

  PositionData(this.position, this.bufferedPosition, this.duration);
}

class AudioMetadata {
  final String title;

  AudioMetadata({required this.title});
}

class Music extends StatefulWidget {
  const Music({super.key});

  @override
  State<Music> createState() => MusicState();
}

class MusicState extends State<Music> {
  final player = AudioPlayer();
  List<Map<String, String>> playlists = [];
  int playlistLength = 0;

  @override
  void initState() {
    super.initState();
    _init();
    populatePlaylists();
  }

  Future<void> populatePlaylists() async {
    var prefs = await SharedPreferences.getInstance();
    var dir = prefs!.getString('musicDirectory');
    var dirFixed = dir != null ? dir.replaceAll('\\', '/') : '';
    var rootDir = '$dirFixed/Playlists/';
    final playlistsM3U = Glob('$rootDir*.m3u', caseSensitive: false);
    final playlistsM3U8 = Glob('$rootDir*.m3u8', caseSensitive: false);

    setState(() {
      playlists = [];
      for (var entity in playlistsM3U.listSync()) {
        var title = p.basename(entity.path).replaceFirst('.m3u', '');
        playlists.add({
          'path': entity.path.replaceAll('\\', '/'),
          'title': title,
          'root': rootDir,
        });
      }
      for (var entity in playlistsM3U8.listSync()) {
        var title = p.basename(entity.path).replaceFirst('.m3u8', '');
        playlists.add({
          'path': entity.path.replaceAll('\\', '/'),
          'title': title,
          'root': rootDir,
        });
      }
    });
  }

  Future<void> _init() async {
    // Inform the operating system of our app's audio attributes etc.
    // We pick a reasonable default for an app that plays speech.
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
    // Listen to errors during playback.
    player.errorStream.listen((e) {
      print('A stream error occurred: $e');
    });
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Release the player's resources when not in use. We use "stop" so that
      // if the app resumes later, it will still remember what position to
      // resume from.
      player.stop();
    }
  }

  /// Collects the data useful for displaying in a seek bar, using a handy
  /// feature of rx_dart to combine the 3 streams of interest into one.
  Stream<PositionData> get _positionDataStream =>
      Rx.combineLatest3<Duration, Duration, Duration?, PositionData>(
        player.positionStream,
        player.bufferedPositionStream,
        player.durationStream,
        (position, bufferedPosition, duration) =>
            PositionData(position, bufferedPosition, duration ?? Duration.zero),
      );

  @override
  Widget build(BuildContext context) {
    return Card(
      shadowColor: Colors.transparent,
      margin: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              StreamBuilder<SequenceState?>(
                stream: player.sequenceStateStream,
                builder: (context, snapshot) => IconButton(
                  icon: const Icon(Icons.skip_previous),
                  onPressed: player.hasPrevious ? player.seekToPrevious : null,
                ),
              ),
              StreamBuilder<(bool, ProcessingState, int)>(
                stream: Rx.combineLatest2(
                  player.playerEventStream,
                  player.sequenceStream,
                  (event, sequence) => (
                    event.playing,
                    event.playbackEvent.processingState,
                    sequence.length,
                  ),
                ),
                builder: (context, snapshot) {
                  final (playing, processingState, sequenceLength) =
                      snapshot.data ?? (false, null, 0);
                  if (processingState == ProcessingState.loading ||
                      processingState == ProcessingState.buffering) {
                    return Container(
                      margin: const EdgeInsets.all(8.0),
                      width: 64.0,
                      height: 64.0,
                      child: const CircularProgressIndicator(),
                    );
                  } else if (!playing) {
                    return IconButton(
                      icon: const Icon(Icons.play_arrow),
                      iconSize: 64.0,
                      onPressed: sequenceLength > 0 ? player.play : null,
                    );
                  } else if (processingState != ProcessingState.completed) {
                    return IconButton(
                      icon: const Icon(Icons.pause),
                      iconSize: 64.0,
                      onPressed: player.pause,
                    );
                  } else {
                    return IconButton(
                      icon: const Icon(Icons.replay),
                      iconSize: 64.0,
                      onPressed: sequenceLength > 0
                          ? () => player.seek(
                              Duration.zero,
                              index: player.effectiveIndices.first,
                            )
                          : null,
                    );
                  }
                },
              ),
              StreamBuilder<SequenceState?>(
                stream: player.sequenceStateStream,
                builder: (context, snapshot) => IconButton(
                  icon: const Icon(Icons.skip_next),
                  onPressed: player.hasNext ? player.seekToNext : null,
                ),
              ),
              Padding(
                padding: EdgeInsets.only(left: 32.0, top: 32.0),
                child: SizedBox(
                  height: 100,
                  child: StreamBuilder<SequenceState?>(
                    stream: player.sequenceStateStream,
                    builder: (context, snapshot) {
                      final state = snapshot.data;
                      if (state?.sequence.isEmpty ?? true) {
                        return const SizedBox();
                      }
                      AudioMetadata metadata;
                      if (state?.currentSource == null ||
                          state?.currentSource?.tag == null) {
                        metadata = AudioMetadata(title: '-');
                      } else {
                        metadata = state!.currentSource!.tag as AudioMetadata;
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            metadata.title,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text('${state!.currentIndex! + 1}/${playlistLength}'),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: ListView.builder(
              itemBuilder: (builder, index) {
                return ListTile(
                  onTap: () async {
                    final fileContent = await File(
                      playlists[index]['path']!,
                    ).readAsString();
                    final listOfTracks = await parseFile(fileContent);
                    var playlist = <AudioSource>[];
                    var numTracks = 0;
                    for (var track in listOfTracks) {
                      String fullPath = p.canonicalize(
                        playlists[index]['root']! + track.link,
                      );
                      playlist.add(
                        AudioSource.file(
                          fullPath,
                          tag: AudioMetadata(title: track.title),
                        ),
                      );
                      numTracks += 1;
                    }
                    setState(() {
                      playlistLength = numTracks;
                    });
                    await player.setAudioSources(
                      playlist,
                      initialIndex: 0,
                      initialPosition: Duration.zero,
                      shuffleOrder:
                          DefaultShuffleOrder(), // Customise the shuffle algorithm
                    );
                  },
                  title: Text(playlists[index]['title']!),
                  subtitle: Text(playlists[index]['path']!),
                  leading: Icon(Icons.playlist_play_outlined),
                );
              },
              itemCount: playlists.length,
            ),
          ),
        ],
      ),
    );
  }
}
