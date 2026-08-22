import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/youtube_stream_service.dart';

class AdaptiveVideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final String? thumbnailUrl;
  final double aspectRatio;
  final VoidCallback? onPlayToggled;

  const AdaptiveVideoPlayerWidget({
    super.key,
    required this.videoUrl,
    this.thumbnailUrl,
    this.aspectRatio = 16 / 9,
    this.onPlayToggled,
  });

  @override
  State<AdaptiveVideoPlayerWidget> createState() => AdaptiveVideoPlayerWidgetState();
}

class AdaptiveVideoPlayerWidgetState extends State<AdaptiveVideoPlayerWidget> {
  Player? _player;
  VideoController? _controller;
  
  String? _directStreamUrl;
  bool _isLoadingStream = true;
  String? _errorMessage;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _playbackRate = 1.0;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _initMediaKit();
  }

  void _initMediaKit() {
    _player = Player();
    _controller = VideoController(_player!);

    _player!.stream.playing.listen((playing) {
      if (mounted && _isPlaying != playing) {
        setState(() => _isPlaying = playing);
      }
    });

    _player!.stream.position.listen((pos) {
      if (mounted) {
        setState(() => _position = pos);
      }
    });

    _player!.stream.duration.listen((dur) {
      if (mounted && dur != Duration.zero) {
        setState(() => _duration = dur);
      }
    });

    _player!.stream.rate.listen((rate) {
      if (mounted && _playbackRate != rate) {
        setState(() => _playbackRate = rate);
      }
    });

    _initializeStream();
  }

  @override
  void didUpdateWidget(AdaptiveVideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      reloadStream();
    }
  }

  Future<void> reloadStream() async {
    if (!mounted) return;
    setState(() {
      _isLoadingStream = true;
      _errorMessage = null;
      _directStreamUrl = null;
      _isPlaying = false;
      _position = Duration.zero;
      _duration = Duration.zero;
    });

    try {
      await _player?.stop();
    } catch (_) {}

    await _initializeStream();
  }

  Future<void> _initializeStream() async {
    try {
      final streamUrl = await YouTubeStreamService.getDirectStreamUrl(widget.videoUrl);
      if (mounted && streamUrl != null) {
        _directStreamUrl = streamUrl;
        await _player?.open(Media(streamUrl), play: false);
      } else if (mounted) {
        _errorMessage = "Could not extract video stream directly. You can reload or play externally.";
      }
    } catch (e) {
      if (mounted) {
        _errorMessage = "Extraction error: $e";
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingStream = false;
        });
      }
    }
  }

  @override
  void dispose() {
    try {
      _player?.stop();
      _player?.dispose();
    } catch (_) {}
    super.dispose();
  }

  void togglePlay() {
    if (_directStreamUrl == null || _player == null) return;
    
    if (_isPlaying) {
      _player!.pause();
    } else {
      _player!.play();
    }
    
    if (widget.onPlayToggled != null) {
      widget.onPlayToggled!();
    }
  }

  void pause() {
    if (_player != null && _isPlaying) {
      _player!.pause();
      if (widget.onPlayToggled != null) {
        widget.onPlayToggled!();
      }
    }
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    if (d.inHours > 0) {
      return "${twoDigits(d.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    }
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: MouseRegion(
        onHover: (_) {
          if (!_showControls) setState(() => _showControls = true);
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: Colors.black38, blurRadius: 16, offset: Offset(0, 6)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 1. Video Surface
                if (_directStreamUrl != null && _controller != null)
                  Positioned.fill(
                    child: Video(
                      controller: _controller!,
                      controls: NoVideoControls,
                      fill: Colors.black,
                    ),
                  )
                else
                  Positioned.fill(
                    child: widget.thumbnailUrl != null && widget.thumbnailUrl!.isNotEmpty
                        ? Image.network(
                            widget.thumbnailUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: const Color(0xFF0F172A),
                              child: const Center(
                                child: Icon(Icons.videocam, size: 64, color: Colors.white38),
                              ),
                            ),
                          )
                        : Container(
                            color: const Color(0xFF0F172A),
                            child: const Center(
                              child: Icon(Icons.videocam, size: 64, color: Colors.white38),
                            ),
                          ),
                  ),

                // 2. Center Large Play / Pause Trigger or Loading
                if (_isLoadingStream)
                  Container(
                    color: Colors.black54,
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                          SizedBox(height: 16),
                          Text('Connecting direct video stream...', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  )
                else if (_errorMessage != null)
                  Container(
                    color: Colors.black87,
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, color: Colors.redAccent, size: 44),
                          const SizedBox(height: 12),
                          Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ElevatedButton.icon(
                                onPressed: reloadStream,
                                icon: const Icon(Icons.refresh, size: 16),
                                label: const Text('Retry Stream'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  final uri = Uri.parse(widget.videoUrl);
                                  if (await canLaunchUrl(uri)) {
                                    await launchUrl(uri);
                                  }
                                },
                                icon: const Icon(Icons.open_in_new, size: 16, color: Colors.white),
                                label: const Text('Open in Browser', style: TextStyle(color: Colors.white, fontSize: 12)),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.white54),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )
                else if (!_isPlaying)
                  IconButton(
                    iconSize: 68,
                    icon: const Icon(Icons.play_circle_fill, color: Colors.white),
                    onPressed: togglePlay,
                  )
                else
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: togglePlay,
                      behavior: HitTestBehavior.opaque,
                      child: Container(color: Colors.transparent),
                    ),
                  ),

                // 3. Top Action Overlay (Badge & Stream Reload)
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _directStreamUrl != null ? const Color(0xFF10B981) : Colors.black54,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _directStreamUrl != null ? Icons.bolt : Icons.videocam,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _directStreamUrl != null ? 'MP4 Stream Live' : 'Video Player',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.white, size: 18),
                        tooltip: 'Reload Stream',
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black54,
                          padding: const EdgeInsets.all(8),
                        ),
                        onPressed: reloadStream,
                      ),
                    ],
                  ),
                ),

                // 4. Bottom Player Controls Bar
                if (_directStreamUrl != null && _errorMessage == null && !_isLoadingStream)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.85),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Seek Slider
                          SliderTheme(
                            data: SliderThemeData(
                              trackHeight: 3,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                              activeTrackColor: const Color(0xFFF43F5E),
                              inactiveTrackColor: Colors.white24,
                              thumbColor: const Color(0xFFF43F5E),
                            ),
                            child: Slider(
                              value: _duration.inMilliseconds > 0
                                  ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
                                  : 0.0,
                              onChanged: (val) {
                                final targetMs = (val * _duration.inMilliseconds).round();
                                _player?.seek(Duration(milliseconds: targetMs));
                              },
                            ),
                          ),
                          // Button Row
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 22),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: togglePlay,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                                style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                              const Spacer(),
                              // Playback Rate
                              DropdownButtonHideUnderline(
                                child: DropdownButton<double>(
                                  value: _playbackRate,
                                  dropdownColor: const Color(0xFF0F172A),
                                  icon: const Icon(Icons.speed, color: Colors.white70, size: 16),
                                  items: const [
                                    DropdownMenuItem(value: 0.75, child: Text('0.75x', style: TextStyle(color: Colors.white, fontSize: 11))),
                                    DropdownMenuItem(value: 1.0, child: Text('1.0x', style: TextStyle(color: Colors.white, fontSize: 11))),
                                    DropdownMenuItem(value: 1.25, child: Text('1.25x', style: TextStyle(color: Colors.white, fontSize: 11))),
                                    DropdownMenuItem(value: 1.5, child: Text('1.5x', style: TextStyle(color: Colors.white, fontSize: 11))),
                                    DropdownMenuItem(value: 2.0, child: Text('2.0x', style: TextStyle(color: Colors.white, fontSize: 11))),
                                  ],
                                  onChanged: (rate) {
                                    if (rate != null) {
                                      _player?.setRate(rate);
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              IconButton(
                                icon: const Icon(Icons.open_in_new, color: Colors.white70, size: 18),
                                tooltip: 'Open in Browser',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () async {
                                  final uri = Uri.parse(widget.videoUrl);
                                  if (await canLaunchUrl(uri)) {
                                    await launchUrl(uri);
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
