import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../core/constants/app_colors.dart';

class AudioBubblePlayer extends StatefulWidget {
  final String audioUrl;
  final int? durationSeconds;
  final bool isSentByMe;

  const AudioBubblePlayer({
    super.key,
    required this.audioUrl,
    this.durationSeconds,
    required this.isSentByMe,
  });

  @override
  State<AudioBubblePlayer> createState() => _AudioBubblePlayerState();
}

class _AudioBubblePlayerState extends State<AudioBubblePlayer> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    if (widget.durationSeconds != null) {
      _duration = Duration(seconds: widget.durationSeconds!);
    }

    _player.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() => _isPlaying = state == PlayerState.playing);
      }
    });

    _player.onPositionChanged.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });

    _player.onDurationChanged.listen((dur) {
      if (mounted) setState(() => _duration = dur);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.play(UrlSource(widget.audioUrl));
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final maxSec = _duration.inMilliseconds > 0 ? _duration.inMilliseconds.toDouble() : 1.0;
    final curSec = _position.inMilliseconds.toDouble().clamp(0.0, maxSec);

    return Container(
      width: 220,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
              color: widget.isSentByMe ? Colors.white : AppColors.primaryLight,
              size: 36,
            ),
            onPressed: _togglePlay,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    trackHeight: 3,
                    thumbColor: widget.isSentByMe ? Colors.white : AppColors.primaryLight,
                    activeTrackColor: widget.isSentByMe ? Colors.white : AppColors.primaryLight,
                    inactiveTrackColor: (widget.isSentByMe ? Colors.white : AppColors.primaryLight)
                        .withValues(alpha: 0.3),
                  ),
                  child: Slider(
                    value: curSec,
                    max: maxSec,
                    onChanged: (val) {
                      _player.seek(Duration(milliseconds: val.toInt()));
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Text(
                    _isPlaying ? _formatDuration(_position) : _formatDuration(_duration),
                    style: TextStyle(
                      color: (widget.isSentByMe ? Colors.white : AppColors.textSecondary)
                          .withValues(alpha: 0.8),
                      fontSize: 11,
                    ),
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
