import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class YouTubeStreamService {
  static String _extractCleanVideoId(String videoIdOrUrl) {
    String videoId = videoIdOrUrl.trim().replaceAll('"', '').replaceAll("'", '').replaceAll(r'\"', '');
    if (videoId.contains('v=')) {
      videoId = videoId.split('v=').last.split('&').first;
    } else if (videoId.contains('youtu.be/')) {
      videoId = videoId.split('youtu.be/').last.split('?').first;
    } else if (videoId.contains('embed/')) {
      videoId = videoId.split('embed/').last.split('?').first;
    }
    videoId = videoId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '').trim();
    return videoId;
  }

  /// Extracts the direct MP4/Muxed video stream URL for a given YouTube video ID or full URL
  static Future<String?> getDirectStreamUrl(String videoIdOrUrl) async {
    final videoId = _extractCleanVideoId(videoIdOrUrl);
    if (videoId.isEmpty) return null;

    // Strategy 1: YouTube Explode client with short timeout
    try {
      final yt = YoutubeExplode();
      try {
        final manifest = await yt.videos.streamsClient.getManifest(videoId).timeout(
          const Duration(seconds: 6),
        );
        
        // Select the highest quality muxed stream (contains video + audio)
        if (manifest.muxed.isNotEmpty) {
          final streamInfo = manifest.muxed.withHighestBitrate();
          return streamInfo.url.toString();
        } else if (manifest.videoOnly.isNotEmpty) {
          final streamInfo = manifest.videoOnly.withHighestBitrate();
          return streamInfo.url.toString();
        }
      } finally {
        yt.close();
      }
    } catch (e) {
      debugPrint('YouTubeExplode extraction note: $e. Falling back to multi-CDN streams...');
    }

    // Strategy 2: Fast Invidious CDN Fallback
    final fallbackInstances = [
      'https://inv.bp.projectsegfau.lt',
      'https://invidious.nerdvpn.de',
      'https://yewtu.be',
      'https://invidious.drgns.space',
    ];

    for (final instance in fallbackInstances) {
      try {
        final uri = Uri.parse('$instance/api/v1/videos/$videoId');
        final res = await http.get(uri).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data is Map && data['formatStreams'] is List) {
            final streams = data['formatStreams'] as List;
            if (streams.isNotEmpty) {
              final directUrl = streams.last['url']?.toString();
              if (directUrl != null && directUrl.startsWith('http')) {
                return directUrl;
              }
            }
          }
        }
      } catch (_) {}
    }

    return null;
  }

  /// Fetches the real video transcript/closed captions from YouTube
  static Future<List<Map<String, dynamic>>> getTranscript(String videoIdOrUrl) async {
    final videoId = _extractCleanVideoId(videoIdOrUrl);
    if (videoId.isEmpty) return [];

    final yt = YoutubeExplode();
    try {
      final trackManifest = await yt.videos.closedCaptions.getManifest(videoId).timeout(
        const Duration(seconds: 8),
      );
      if (trackManifest.tracks.isEmpty) return [];

      final trackInfo = trackManifest.tracks.firstWhere(
        (t) => t.language.code.startsWith('en'),
        orElse: () => trackManifest.tracks.first,
      );

      final track = await yt.videos.closedCaptions.get(trackInfo).timeout(
        const Duration(seconds: 8),
      );
      
      return track.captions.map((caption) {
        return {
          'startSeconds': caption.offset.inMilliseconds / 1000.0,
          'timeText': _formatDuration(caption.offset),
          'text': caption.text,
          'speaker': 'Speaker',
        };
      }).toList();
    } catch (e) {
      debugPrint('YouTube transcript extraction notice: $e');
      return [];
    } finally {
      yt.close();
    }
  }

  static String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    if (d.inHours > 0) {
      return "${twoDigits(d.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    }
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  static void dispose() {}
}
