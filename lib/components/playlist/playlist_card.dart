import 'package:fl_query/fl_query.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:spotify/spotify.dart';
import 'package:spotube/components/shared/playbutton_card.dart';
import 'package:spotube/provider/proxy_playlist/proxy_playlist_provider.dart';
import 'package:spotube/provider/spotify_provider.dart';
import 'package:spotube/services/audio_player/audio_player.dart';
import 'package:spotube/services/queries/queries.dart';
import 'package:spotube/utils/service_utils.dart';
import 'package:spotube/utils/type_conversion_utils.dart';

class PlaylistCard extends HookConsumerWidget {
  final PlaylistSimple playlist;
  const PlaylistCard(
    this.playlist, {
    Key? key,
  }) : super(key: key);
  @override
  Widget build(BuildContext context, ref) {
    final playlistQueue = ref.watch(ProxyPlaylistNotifier.provider);
    final playlistNotifier = ref.watch(ProxyPlaylistNotifier.notifier);
    final playing =
        useStream(audioPlayer.playingStream).data ?? audioPlayer.isPlaying;
    final queryBowl = QueryClient.of(context);
    final tracks = useState<List<TrackSimple>?>(null);
    bool isPlaylistPlaying = useMemoized(
      () => playlistQueue.containsCollection(playlist.id!),
      [playlistQueue, playlist.id],
    );

    final updating = useState(false);
    final spotify = ref.watch(spotifyProvider);

    return PlaybuttonCard(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      title: playlist.name!,
      description: playlist.description,
      imageUrl: TypeConversionUtils.image_X_UrlString(
        playlist.images,
        placeholder: ImagePlaceholder.collection,
      ),
      isPlaying: isPlaylistPlaying,
      isLoading:
          (isPlaylistPlaying && playlistQueue.isFetching) || updating.value,
      onTap: () {
        ServiceUtils.push(
          context,
          "/playlist/${playlist.id}",
          extra: playlist,
        );
      },
      onPlaybuttonPressed: () async {
        try {
          updating.value = true;
          if (isPlaylistPlaying && playing) {
            return audioPlayer.pause();
          } else if (isPlaylistPlaying && !playing) {
            return audioPlayer.resume();
          }

          List<Track> fetchedTracks = await queryBowl.fetchQuery(
                "playlist-tracks/${playlist.id}",
                () => useQueries.playlist.tracksOf(playlist.id!, spotify),
              ) ??
              [];

          if (fetchedTracks.isEmpty) return;

          await playlistNotifier.load(fetchedTracks, autoPlay: true);
          playlistNotifier.addCollection(playlist.id!);
          tracks.value = fetchedTracks;
        } finally {
          updating.value = false;
        }
      },
      onAddToQueuePressed: () async {
        updating.value = true;
        try {
          if (isPlaylistPlaying) return;
          List<Track> fetchedTracks = await queryBowl.fetchQuery(
                "playlist-tracks/${playlist.id}",
                () => useQueries.playlist.tracksOf(playlist.id!, spotify),
              ) ??
              [];

          if (fetchedTracks.isEmpty) return;

          playlistNotifier.addTracks(fetchedTracks);
          playlistNotifier.addCollection(playlist.id!);
          tracks.value = fetchedTracks;
          if (context.mounted) {
            final snackbar = SnackBar(
              content: Text("Added ${tracks.value?.length} tracks to queue"),
              action: SnackBarAction(
                label: "Undo",
                onPressed: () {
                  playlistNotifier
                      .removeTracks(fetchedTracks.map((e) => e.id!));
                },
              ),
            );
            ScaffoldMessenger.maybeOf(context)?.showSnackBar(snackbar);
          }
        } finally {
          updating.value = false;
        }
      },
    );
  }
}
