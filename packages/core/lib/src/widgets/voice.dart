import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../l10n/generated/core_localizations.dart';
import '../theme/app_tokens.dart';

/// Hold to record a voice note, release to send (D-033: up to 60 seconds). Speech-quality
/// AAC at 32 kbit/s keeps a minute under 250 KB on a slow connection.
class VoiceRecordButton extends StatefulWidget {
  const VoiceRecordButton({super.key, required this.onRecorded, this.maxSeconds = 60});

  final void Function(Uint8List audio, int seconds) onRecorded;
  final int maxSeconds;

  @override
  State<VoiceRecordButton> createState() => _VoiceRecordButtonState();
}

class _VoiceRecordButtonState extends State<VoiceRecordButton> {
  AudioRecorder? _recorder;
  DateTime? _startedAt;
  Timer? _limit;
  String? _path;

  @override
  void dispose() {
    _limit?.cancel();
    unawaited(_recorder?.dispose());
    super.dispose();
  }

  Future<void> _start() async {
    final t = CoreLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    // Made on first use: the microphone plugin only loads when the buyer records.
    final recorder = _recorder ??= AudioRecorder();
    if (!await recorder.hasPermission()) {
      messenger.showSnackBar(SnackBar(content: Text(t.errMicDenied)));
      return;
    }
    final dir = await getTemporaryDirectory();
    _path = '${dir.path}/voice-${DateTime.now().microsecondsSinceEpoch}.m4a';
    await recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 32000,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: _path!,
    );
    if (!mounted) return;
    setState(() => _startedAt = DateTime.now());
    _limit = Timer(Duration(seconds: widget.maxSeconds), _stop);
  }

  Future<void> _stop() async {
    _limit?.cancel();
    final started = _startedAt;
    if (started == null) return;
    setState(() => _startedAt = null);
    final path = await _recorder?.stop() ?? _path;
    final seconds = DateTime.now().difference(started).inSeconds.clamp(0, widget.maxSeconds);
    if (path == null) return;
    final file = File(path);
    if (seconds < 1) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(CoreLocalizations.of(context).voiceTooShort)));
      }
    } else {
      widget.onRecorded(await file.readAsBytes(), seconds);
    }
    if (await file.exists()) await file.delete();
  }

  @override
  Widget build(BuildContext context) {
    final t = CoreLocalizations.of(context);
    final recording = _startedAt != null;
    return GestureDetector(
      onLongPressStart: (_) => _start(),
      onLongPressEnd: (_) => _stop(),
      child: Tooltip(
        message: recording ? t.voiceRecording : t.voiceHold,
        child: AnimatedContainer(
          duration: Motion.fast,
          width: recording ? 56 : 48,
          height: recording ? 56 : 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: recording
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.secondaryContainer,
          ),
          child: Icon(
            recording ? Icons.mic : Icons.mic_none_rounded,
            color: recording
                ? Theme.of(context).colorScheme.onError
                : Theme.of(context).colorScheme.onSecondaryContainer,
          ),
        ),
      ),
    );
  }
}

/// Play button, bars and length of a voice note. [url] gives a signed link when tapped.
class VoiceNotePlayer extends StatefulWidget {
  const VoiceNotePlayer({super.key, required this.seconds, required this.color, this.url});

  final int seconds;
  final Color color;
  final Future<String> Function()? url;

  @override
  State<VoiceNotePlayer> createState() => _VoiceNotePlayerState();
}

class _VoiceNotePlayerState extends State<VoiceNotePlayer> {
  AudioPlayer? _player;
  var _playing = false;
  var _loading = false;
  StreamSubscription<void>? _done;

  @override
  void dispose() {
    unawaited(_done?.cancel());
    unawaited(_player?.dispose());
    super.dispose();
  }

  Future<void> _toggle() async {
    final player = _player ??= AudioPlayer();
    if (_playing) {
      await player.pause();
      setState(() => _playing = false);
      return;
    }
    final url = widget.url;
    if (url == null) return;
    setState(() => _loading = true);
    try {
      _done ??= player.onPlayerComplete.listen((_) {
        if (mounted) setState(() => _playing = false);
      });
      await player.play(UrlSource(await url()));
      if (mounted) setState(() => _playing = true);
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(CoreLocalizations.of(context).errOffline)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = CoreLocalizations.of(context);
    final fg = widget.color;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: Hit.min,
          child: _loading
              ? Padding(
                  padding: const EdgeInsets.all(14),
                  child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                )
              : IconButton(
                  tooltip: _playing ? t.voicePause : t.voicePlay,
                  onPressed: widget.url == null ? null : _toggle,
                  icon: Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: fg),
                ),
        ),
        for (var i = 0; i < 14; i++)
          Container(
            width: 3,
            height: 6.0 + (i * 7 % 13),
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: fg.withValues(alpha: _playing ? 1 : 0.7),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        const SizedBox(width: Space.sm),
        Text(
          '0:${widget.seconds.toString().padLeft(2, '0')}',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg),
        ),
      ],
    );
  }
}
