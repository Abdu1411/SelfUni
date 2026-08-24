import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/youtube_stream_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  Duration _buffer = Duration.zero;
  double _playbackRate = 1.0;
  double _volume = 100.0;
  bool _isMuted = false;
  bool _showControls = true;
  bool _isFullscreenActive = false;

  Timer? _controlsTimer;

  bool _showForwardIndicator = false;
  bool _showBackwardIndicator = false;
  Timer? _indicatorTimer;

  final List<StreamSubscription> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    _initMediaKit();
  }

  void _initMediaKit() {
    try {
      _player = Player();
      _controller = VideoController(_player!);

      _subscriptions.add(_player!.stream.playing.listen((playing) {
        if (mounted && _isPlaying != playing) {
          setState(() {
            _isPlaying = playing;
            if (playing) {
              _resetAndStartControlsTimer();
            } else {
              _controlsTimer?.cancel();
              _showControls = true;
            }
          });
        }
      }));

      _subscriptions.add(_player!.stream.position.listen((pos) {
        if (mounted) {
          setState(() => _position = pos);
          _savePositionThrottled(pos);
        }
      }));

      _subscriptions.add(_player!.stream.duration.listen((dur) {
        if (mounted && dur != Duration.zero) {
          setState(() => _duration = dur);
        }
      }));

      _subscriptions.add(_player!.stream.rate.listen((rate) {
        if (mounted && _playbackRate != rate) {
          setState(() => _playbackRate = rate);
        }
      }));

      _subscriptions.add(_player!.stream.buffer.listen((buf) {
        if (mounted) {
          setState(() => _buffer = buf);
        }
      }));

      _subscriptions.add(_player!.stream.volume.listen((vol) {
        if (mounted) {
          setState(() {
            _volume = vol;
            _isMuted = vol == 0.0;
          });
        }
      }));

      _initializeStream();
    } catch (e) {
      debugPrint("MediaKit initialization failed: $e");
      _errorMessage = "Could not initialize media player. Use browser play option.";
      _isLoadingStream = false;
    }
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
      _buffer = Duration.zero;
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
        
        if (_player != null && mounted) {
          await _player!.stream.duration
              .firstWhere((duration) => duration > Duration.zero)
              .timeout(const Duration(seconds: 5), onTimeout: () => Duration.zero);
          
          if (mounted) {
            final prefs = await SharedPreferences.getInstance();
            final savedMs = prefs.getInt('video_pos_${widget.videoUrl}');
            debugPrint("DEBUG WATCH POSITION: Restoring position for ${widget.videoUrl}, savedMs: $savedMs");
            if (savedMs != null && savedMs > 0) {
              await _player!.seek(Duration(milliseconds: savedMs));
              debugPrint("DEBUG WATCH POSITION: Seek successful to $savedMs ms");
            }
          }
        }
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
    for (final s in _subscriptions) {
      s.cancel();
    }
    _controlsTimer?.cancel();
    _indicatorTimer?.cancel();
    if (_player != null) {
      _savePositionImmediately();
    }
    try {
      _player?.stop();
      _player?.dispose();
    } catch (_) {}
    super.dispose();
  }

  void _resetAndStartControlsTimer() {
    _controlsTimer?.cancel();
    if (!_showControls) {
      setState(() => _showControls = true);
    }
    if (_isPlaying) {
      _controlsTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && _isPlaying) {
          setState(() => _showControls = false);
        }
      });
    }
  }

  void _cancelControlsTimer() {
    _controlsTimer?.cancel();
    if (mounted && !_showControls) {
      setState(() => _showControls = true);
    }
  }

  void _seekRelative(Duration delta) {
    if (_player == null || _duration == Duration.zero) return;
    final newPos = _position + delta;
    Duration target;
    if (newPos < Duration.zero) {
      target = Duration.zero;
    } else if (newPos > _duration) {
      target = _duration;
    } else {
      target = newPos;
    }
    _player!.seek(target);
    _resetAndStartControlsTimer();
    _showSeekIndicator(delta.inSeconds > 0);
  }

  void _showSeekIndicator(bool isForward) {
    _indicatorTimer?.cancel();
    setState(() {
      _showForwardIndicator = isForward;
      _showBackwardIndicator = !isForward;
    });
    _indicatorTimer = Timer(const Duration(milliseconds: 650), () {
      if (mounted) {
        setState(() {
          _showForwardIndicator = false;
          _showBackwardIndicator = false;
        });
      }
    });
  }

  Future<void> _toggleFullscreen() async {
    if (_player == null || _controller == null) return;

    _controlsTimer?.cancel();

    setState(() {
      _isFullscreenActive = true;
    });

    await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          return FullscreenVideoPlayerPage(
            player: _player!,
            controller: _controller!,
            videoUrl: widget.videoUrl,
            aspectRatio: widget.aspectRatio,
            playbackRate: _playbackRate,
            isMuted: _isMuted,
            volume: _volume,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );

    if (mounted) {
      setState(() {
        _isFullscreenActive = false;
      });
      _resetAndStartControlsTimer();
    }
  }

  void togglePlay() {
    if (_directStreamUrl == null || _player == null) return;
    
    if (_isPlaying) {
      _player!.pause();
      _savePositionImmediately();
      _cancelControlsTimer();
    } else {
      _player!.play();
      _resetAndStartControlsTimer();
    }
    
    if (widget.onPlayToggled != null) {
      widget.onPlayToggled!();
    }
  }

  void pause() {
    if (_player != null && _isPlaying) {
      _player!.pause();
      _savePositionImmediately();
      _cancelControlsTimer();
      if (widget.onPlayToggled != null) {
        widget.onPlayToggled!();
      }
    }
  }

  DateTime? _lastSavedTime;

  void _savePositionThrottled(Duration pos) async {
    final now = DateTime.now();
    if (_lastSavedTime == null || now.difference(_lastSavedTime!) > const Duration(seconds: 3)) {
      _lastSavedTime = now;
      final prefs = await SharedPreferences.getInstance();
      debugPrint("DEBUG WATCH POSITION: Throttled save: ${pos.inMilliseconds} ms");
      await prefs.setInt('video_pos_${widget.videoUrl}', pos.inMilliseconds);
    }
  }

  void _savePositionImmediately() async {
    if (_player == null) return;
    final pos = _player!.state.position;
    final dur = _player!.state.duration;
    debugPrint("DEBUG WATCH POSITION: Saving position immediately for ${widget.videoUrl}: $pos / $dur");
    final prefs = await SharedPreferences.getInstance();
    
    if (dur != Duration.zero && (dur.inMilliseconds - pos.inMilliseconds) < 10000) {
      debugPrint("DEBUG WATCH POSITION: Near end, removing saved progress");
      await prefs.remove('video_pos_${widget.videoUrl}');
    } else {
      debugPrint("DEBUG WATCH POSITION: Saved position: ${pos.inMilliseconds} ms");
      await prefs.setInt('video_pos_${widget.videoUrl}', pos.inMilliseconds);
    }
  }

  Duration get position => _position;

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
          _resetAndStartControlsTimer();
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
                if (_isFullscreenActive)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black,
                      child: const Center(
                        child: Text(
                          'Playing in Fullscreen Mode',
                          style: TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                      ),
                    ),
                  )
                else if (_directStreamUrl != null && _controller != null)
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

                // 2. Gesture zones for tap/double tap seek
                if (!_isFullscreenActive && _directStreamUrl != null && _errorMessage == null && !_isLoadingStream)
                  Positioned.fill(
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              if (_showControls) {
                                setState(() => _showControls = false);
                                _controlsTimer?.cancel();
                              } else {
                                _resetAndStartControlsTimer();
                              }
                            },
                            onDoubleTap: () => _seekRelative(-const Duration(seconds: 10)),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              if (_showControls) {
                                setState(() => _showControls = false);
                                _controlsTimer?.cancel();
                              } else {
                                _resetAndStartControlsTimer();
                              }
                            },
                            onDoubleTap: () => _seekRelative(const Duration(seconds: 10)),
                          ),
                        ),
                      ],
                    ),
                  ),

                // 3. Center Large Play / Pause Trigger or Loading
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
                else if (!_isPlaying && !_isFullscreenActive)
                  IconButton(
                    iconSize: 68,
                    icon: const Icon(Icons.play_circle_fill, color: Colors.white70),
                    onPressed: togglePlay,
                  ),

                // 4. Centering Seek Indicators
                if (!_isFullscreenActive && _showBackwardIndicator)
                  Positioned(
                    left: 40,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          color: Colors.black45,
                          shape: BoxShape.circle,
                        ),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.fast_rewind, color: Colors.white, size: 32),
                            SizedBox(height: 4),
                            Text('-10s', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (!_isFullscreenActive && _showForwardIndicator)
                  Positioned(
                    right: 40,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          color: Colors.black45,
                          shape: BoxShape.circle,
                        ),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.fast_forward, color: Colors.white, size: 32),
                            SizedBox(height: 4),
                            Text('+10s', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),

                // 5. Top Action Overlay (Badge & Stream Reload)
                if (!_isFullscreenActive && _showControls)
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

                // 6. Bottom Player Controls Bar
                if (!_isFullscreenActive && _directStreamUrl != null && _errorMessage == null && !_isLoadingStream)
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    bottom: _showControls ? 0 : -80,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12, top: 24),
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
                          // Interactive Progress Bar
                          VideoProgressBar(
                            position: _position,
                            duration: _duration,
                            buffer: _buffer,
                            onSeek: (pos) {
                              _player?.seek(pos);
                              _resetAndStartControlsTimer();
                            },
                          ),
                          const SizedBox(height: 6),
                          // Button Row
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final width = constraints.maxWidth;
                              final isCompact = width < 480;
                              final isUltraCompact = width < 340;

                              return Row(
                                children: [
                                  IconButton(
                                    icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 22),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: togglePlay,
                                  ),
                                  const SizedBox(width: 8),
                                  // Mute/Volume controls
                                  IconButton(
                                    icon: Icon(
                                      _isMuted
                                          ? Icons.volume_off
                                          : (_volume > 50 ? Icons.volume_up : Icons.volume_down),
                                      color: Colors.white70,
                                      size: 18,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () {
                                      if (_isMuted) {
                                        _player?.setVolume(100.0);
                                      } else {
                                        _player?.setVolume(0.0);
                                      }
                                    },
                                  ),
                                  if (!isCompact) ...[
                                    const SizedBox(width: 4),
                                    SizedBox(
                                      width: 50,
                                      child: SliderTheme(
                                        data: const SliderThemeData(
                                          trackHeight: 2,
                                          thumbShape: RoundSliderThumbShape(enabledThumbRadius: 3),
                                          overlayShape: RoundSliderOverlayShape(overlayRadius: 6),
                                          activeTrackColor: Colors.white,
                                          inactiveTrackColor: Colors.white24,
                                          thumbColor: Colors.white,
                                        ),
                                        child: Slider(
                                          value: _isMuted ? 0.0 : _volume,
                                          min: 0.0,
                                          max: 100.0,
                                          onChanged: (val) {
                                            _player?.setVolume(val);
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      isUltraCompact
                                          ? _formatDuration(_position)
                                          : '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                                      style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const Spacer(),
                                  // Playback Rate
                                  if (!isUltraCompact) ...[
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
                                    const SizedBox(width: 8),
                                  ],
                                  // Fullscreen trigger button
                                  IconButton(
                                    icon: const Icon(Icons.fullscreen, color: Colors.white70, size: 20),
                                    tooltip: 'Fullscreen',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: _toggleFullscreen,
                                  ),
                                  if (!isCompact) ...[
                                    const SizedBox(width: 8),
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
                                ],
                              );
                            },
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

class VideoProgressBar extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final Duration buffer;
  final ValueChanged<Duration> onSeek;

  const VideoProgressBar({
    super.key,
    required this.position,
    required this.duration,
    required this.buffer,
    required this.onSeek,
  });

  @override
  State<VideoProgressBar> createState() => _VideoProgressBarState();
}

class _VideoProgressBarState extends State<VideoProgressBar> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final duration = widget.duration;
    final position = widget.position;
    final buffer = widget.buffer;

    final double playedRatio = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    final double bufferRatio = duration.inMilliseconds > 0
        ? (buffer.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    final trackHeight = _isHovered ? 6.0 : 4.0;
    final thumbSize = _isHovered ? 12.0 : 0.0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (details) => _handleSeek(context, details.globalPosition),
        onHorizontalDragStart: (details) => _handleSeek(context, details.globalPosition),
        onTapDown: (details) => _handleSeek(context, details.globalPosition),
        child: Container(
          height: 24, // Tall gesture area
          alignment: Alignment.center,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.centerLeft,
                children: [
                  // 1. Inactive Track (Background)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: width,
                    height: trackHeight,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  // 2. Buffer Track
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: width * bufferRatio,
                    height: trackHeight,
                    decoration: BoxDecoration(
                      color: Colors.white38,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  // 3. Active (Played) Track
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: width * playedRatio,
                    height: trackHeight,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF43F5E),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  // 4. Scrub Thumb
                  Positioned(
                    left: (width * playedRatio) - (thumbSize / 2),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: thumbSize,
                      height: thumbSize,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF43F5E),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2)),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _handleSeek(BuildContext context, Offset globalPosition) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final Offset localPosition = renderBox.globalToLocal(globalPosition);
    final double width = renderBox.size.width;
    if (width <= 0) return;

    final double percent = (localPosition.dx / width).clamp(0.0, 1.0);
    final int targetMs = (percent * widget.duration.inMilliseconds).round();
    widget.onSeek(Duration(milliseconds: targetMs));
  }
}

class FullscreenVideoPlayerPage extends StatefulWidget {
  final Player player;
  final VideoController controller;
  final String videoUrl;
  final double aspectRatio;
  final double playbackRate;
  final bool isMuted;
  final double volume;

  const FullscreenVideoPlayerPage({
    super.key,
    required this.player,
    required this.controller,
    required this.videoUrl,
    required this.aspectRatio,
    required this.playbackRate,
    required this.isMuted,
    required this.volume,
  });

  @override
  State<FullscreenVideoPlayerPage> createState() => _FullscreenVideoPlayerPageState();
}

class _FullscreenVideoPlayerPageState extends State<FullscreenVideoPlayerPage> {
  late bool _isPlaying;
  late Duration _position;
  late Duration _duration;
  late Duration _buffer;
  late double _playbackRate;
  late double _volume;
  late bool _isMuted;

  bool _showControls = true;
  Timer? _controlsTimer;

  bool _showForwardIndicator = false;
  bool _showBackwardIndicator = false;
  Timer? _indicatorTimer;

  final FocusNode _focusNode = FocusNode();
  final List<StreamSubscription> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _isPlaying = widget.player.state.playing;
    _position = widget.player.state.position;
    _duration = widget.player.state.duration;
    _buffer = widget.player.state.buffer;
    _playbackRate = widget.player.state.rate;
    _volume = widget.player.state.volume;
    _isMuted = _volume == 0.0;

    _subscriptions.add(widget.player.stream.playing.listen((playing) {
      if (mounted) {
        setState(() {
          _isPlaying = playing;
          if (playing) {
            _resetAndStartControlsTimer();
          } else {
            _controlsTimer?.cancel();
            _showControls = true;
          }
        });
      }
    }));

    _subscriptions.add(widget.player.stream.position.listen((pos) {
      if (mounted) {
        setState(() => _position = pos);
      }
    }));

    _subscriptions.add(widget.player.stream.duration.listen((dur) {
      if (mounted && dur != Duration.zero) {
        setState(() => _duration = dur);
      }
    }));

    _subscriptions.add(widget.player.stream.buffer.listen((buf) {
      if (mounted) {
        setState(() => _buffer = buf);
      }
    }));

    _subscriptions.add(widget.player.stream.rate.listen((rate) {
      if (mounted) {
        setState(() => _playbackRate = rate);
      }
    }));

    _subscriptions.add(widget.player.stream.volume.listen((vol) {
      if (mounted) {
        setState(() {
          _volume = vol;
          _isMuted = vol == 0.0;
        });
      }
    }));

    if (_isPlaying) {
      _resetAndStartControlsTimer();
    }
  }

  void _resetAndStartControlsTimer() {
    _controlsTimer?.cancel();
    if (!_showControls) {
      setState(() => _showControls = true);
    }
    if (_isPlaying) {
      _controlsTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && _isPlaying) {
          setState(() => _showControls = false);
        }
      });
    }
  }

  void togglePlay() {
    if (_isPlaying) {
      widget.player.pause();
    } else {
      widget.player.play();
    }
  }

  void _seekRelative(Duration delta) {
    if (_duration == Duration.zero) return;
    final newPos = _position + delta;
    Duration target;
    if (newPos < Duration.zero) {
      target = Duration.zero;
    } else if (newPos > _duration) {
      target = _duration;
    } else {
      target = newPos;
    }
    widget.player.seek(target);
    _resetAndStartControlsTimer();
    _showSeekIndicator(delta.inSeconds > 0);
  }

  void _showSeekIndicator(bool isForward) {
    _indicatorTimer?.cancel();
    setState(() {
      _showForwardIndicator = isForward;
      _showBackwardIndicator = !isForward;
    });
    _indicatorTimer = Timer(const Duration(milliseconds: 650), () {
      if (mounted) {
        setState(() {
          _showForwardIndicator = false;
          _showBackwardIndicator = false;
        });
      }
    });
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
  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    _controlsTimer?.cancel();
    _indicatorTimer?.cancel();
    _focusNode.dispose();

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          alignment: Alignment.center,
          children: [
            // Video Surface
            Positioned.fill(
              child: Video(
                controller: widget.controller,
                controls: NoVideoControls,
                fill: Colors.black,
              ),
            ),

            // Tap & Double Tap gestures overlay
            Positioned.fill(
              child: Row(
                children: [
                  // Left side
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (_showControls) {
                          setState(() => _showControls = false);
                          _controlsTimer?.cancel();
                        } else {
                          _resetAndStartControlsTimer();
                        }
                      },
                      onDoubleTap: () => _seekRelative(-const Duration(seconds: 10)),
                    ),
                  ),
                  // Right side
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (_showControls) {
                          setState(() => _showControls = false);
                          _controlsTimer?.cancel();
                        } else {
                          _resetAndStartControlsTimer();
                        }
                      },
                      onDoubleTap: () => _seekRelative(const Duration(seconds: 10)),
                    ),
                  ),
                ],
              ),
            ),

            // Centering Seek Indicators
            if (_showBackwardIndicator)
              Positioned(
                left: 100,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: Colors.black45,
                      shape: BoxShape.circle,
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fast_rewind, color: Colors.white, size: 40),
                        SizedBox(height: 4),
                        Text('-10s', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
            if (_showForwardIndicator)
              Positioned(
                right: 100,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: Colors.black45,
                      shape: BoxShape.circle,
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fast_forward, color: Colors.white, size: 40),
                        SizedBox(height: 4),
                        Text('+10s', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),

            // Bottom controls overlay
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              bottom: _showControls ? 0 : -100,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.only(left: 24, right: 24, bottom: 20, top: 40),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.9),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ProgressBar
                    VideoProgressBar(
                      position: _position,
                      duration: _duration,
                      buffer: _buffer,
                      onSeek: (pos) {
                        widget.player.seek(pos);
                        _resetAndStartControlsTimer();
                      },
                    ),
                    const SizedBox(height: 12),
                    // Action Buttons Row
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 28),
                          onPressed: togglePlay,
                        ),
                        const SizedBox(width: 12),
                        // Volume Row
                        IconButton(
                          icon: Icon(
                            _isMuted
                                ? Icons.volume_off
                                : (_volume > 50 ? Icons.volume_up : Icons.volume_down),
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: () {
                            if (_isMuted) {
                              widget.player.setVolume(100.0);
                            } else {
                              widget.player.setVolume(0.0);
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 80,
                          child: SliderTheme(
                            data: SliderThemeData(
                              trackHeight: 2,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
                              activeTrackColor: Colors.white,
                              inactiveTrackColor: Colors.white24,
                              thumbColor: Colors.white,
                            ),
                            child: Slider(
                              value: _isMuted ? 0.0 : _volume,
                              min: 0.0,
                              max: 100.0,
                              onChanged: (val) {
                                widget.player.setVolume(val);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        // Playback Speed
                        DropdownButtonHideUnderline(
                          child: DropdownButton<double>(
                            value: _playbackRate,
                            dropdownColor: const Color(0xFF0F172A),
                            icon: const Icon(Icons.speed, color: Colors.white, size: 18),
                            items: const [
                              DropdownMenuItem(value: 0.75, child: Text('0.75x', style: TextStyle(color: Colors.white, fontSize: 13))),
                              DropdownMenuItem(value: 1.0, child: Text('1.0x', style: TextStyle(color: Colors.white, fontSize: 13))),
                              DropdownMenuItem(value: 1.25, child: Text('1.25x', style: TextStyle(color: Colors.white, fontSize: 13))),
                              DropdownMenuItem(value: 1.5, child: Text('1.5x', style: TextStyle(color: Colors.white, fontSize: 13))),
                              DropdownMenuItem(value: 2.0, child: Text('2.0x', style: TextStyle(color: Colors.white, fontSize: 13))),
                            ],
                            onChanged: (rate) {
                              if (rate != null) {
                                widget.player.setRate(rate);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Exit Fullscreen Button
                        IconButton(
                          icon: const Icon(Icons.fullscreen_exit, color: Colors.white, size: 28),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Top action row (Exit/Back button)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              top: _showControls ? 0 : -80,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Lecture Video - Fullscreen',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
