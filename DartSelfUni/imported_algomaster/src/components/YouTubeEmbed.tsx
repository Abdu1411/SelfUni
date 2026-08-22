import React, { useEffect, useRef, useImperativeHandle, forwardRef, useCallback } from 'react';

interface YouTubeEmbedProps {
  videoUrl: string;
  initialStartTime?: number;
  onPause?: (currentTime: number) => void;
  onTimeUpdate?: (currentTime: number) => void;
}

export interface YouTubePlayerHandle {
  pause: () => void;
  play: () => void;
  getCurrentTime: () => number;
  getDuration: () => number;
  seekTo: (seconds: number) => void;
}

// Declare YT global from YouTube IFrame API
declare global {
  interface Window {
    YT: any;
    onYouTubeIframeAPIReady: (() => void) | undefined;
  }
}

let apiLoaded = false;
let apiReady = false;
const apiReadyCallbacks: (() => void)[] = [];

function loadYouTubeAPI() {
  if (apiReady) return;
  if (apiLoaded) return;
  apiLoaded = true;

  const tag = document.createElement('script');
  tag.src = 'https://www.youtube.com/iframe_api';
  document.head.appendChild(tag);

  window.onYouTubeIframeAPIReady = () => {
    apiReady = true;
    apiReadyCallbacks.forEach(cb => cb());
    apiReadyCallbacks.length = 0;
  };
}

function onAPIReady(cb: () => void) {
  if (apiReady) {
    cb();
  } else {
    apiReadyCallbacks.push(cb);
    loadYouTubeAPI();
  }
}

export const YouTubeEmbed = forwardRef<YouTubePlayerHandle, YouTubeEmbedProps>(
  ({ videoUrl, initialStartTime = 0, onPause, onTimeUpdate }, ref) => {
    const containerRef = useRef<HTMLDivElement>(null);
    const playerRef = useRef<any>(null);
    const timerRef = useRef<any>(null);

    // Keep callbacks in refs to avoid re-triggering useEffect on parent re-renders
    const onPauseRef = useRef(onPause);
    onPauseRef.current = onPause;

    const onTimeUpdateRef = useRef(onTimeUpdate);
    onTimeUpdateRef.current = onTimeUpdate;

    const extractIds = useCallback((url: string) => {
      const videoMatch = url.match(/[?&]v=([^&#]*)/) || url.match(/youtu\.be\/([^?&#]+)/);
      const listMatch = url.match(/[?&]list=([^&#]*)/);
      return {
        videoId: videoMatch ? videoMatch[1] : (listMatch ? '' : url),
        listId: listMatch ? listMatch[1] : null
      };
    }, []);

    const { videoId, listId } = extractIds(videoUrl);

    useImperativeHandle(ref, () => ({
      pause: () => {
        try {
          playerRef.current?.pauseVideo();
          const t = playerRef.current?.getCurrentTime() || 0;
          onPauseRef.current?.(t);
        } catch { /* ignore */ }
      },
      play: () => {
        try { playerRef.current?.playVideo(); } catch { /* ignore */ }
      },
      getCurrentTime: () => {
        try {
          return playerRef.current?.getCurrentTime() || 0;
        } catch {
          return 0;
        }
      },
      getDuration: () => {
        try {
          return playerRef.current?.getDuration() || 0;
        } catch {
          return 0;
        }
      },
      seekTo: (seconds: number) => {
        try {
          playerRef.current?.seekTo(seconds, true);
        } catch { /* ignore */ }
      }
    }));

    useEffect(() => {
      let isMounted = true;
      const startSeconds = Math.max(0, Math.floor(initialStartTime || 0));
      const divId = `yt-player-${videoId}-${Date.now()}`;
      const el = document.createElement('div');
      el.id = divId;
      if (containerRef.current) {
        containerRef.current.innerHTML = '';
        containerRef.current.appendChild(el);
      }

      onAPIReady(() => {
        if (!isMounted || !containerRef.current) return;
        try {
          playerRef.current = new window.YT.Player(divId, {
            videoId,
            width: '100%',
            height: '100%',
            playerVars: {
              rel: 0,
              modestbranding: 1,
              enablejsapi: 1,
              start: startSeconds > 0 ? startSeconds : undefined,
              ...(listId ? { listType: 'playlist', list: listId } : {})
            },
            events: {
              onReady: (event: any) => {
                if (!isMounted) return;
                if (startSeconds > 0) {
                  try {
                    event.target.seekTo(startSeconds, true);
                  } catch { /* ignore */ }
                }
              },
              onStateChange: (event: any) => {
                if (!isMounted) return;
                // 1 = PLAYING, 2 = PAUSED, 0 = ENDED
                if (event.data === 1) {
                  if (timerRef.current) clearInterval(timerRef.current);
                  timerRef.current = setInterval(() => {
                    if (!isMounted) return;
                    if (playerRef.current && typeof playerRef.current.getCurrentTime === 'function') {
                      try {
                        const t = playerRef.current.getCurrentTime() || 0;
                        onTimeUpdateRef.current?.(t);
                      } catch { /* ignore */ }
                    }
                  }, 500);
                } else {
                  if (timerRef.current) {
                    clearInterval(timerRef.current);
                    timerRef.current = null;
                  }
                }

                if (event.data === 2 || event.data === 0) {
                  try {
                    const t = playerRef.current?.getCurrentTime() || 0;
                    if (isMounted) {
                      onPauseRef.current?.(t);
                      onTimeUpdateRef.current?.(t);
                    }
                  } catch { /* ignore */ }
                }
              }
            }
          });
        } catch (err) {
          console.warn('YouTube Player initialization caught error:', err);
        }
      });

      return () => {
        isMounted = false;
        if (timerRef.current) {
          clearInterval(timerRef.current);
          timerRef.current = null;
        }
        if (playerRef.current) {
          try {
            if (typeof playerRef.current.stopVideo === 'function') {
              playerRef.current.stopVideo();
            }
          } catch { /* ignore */ }
          playerRef.current = null;
        }
      };
    }, [videoId]);

    return (
      <div
        ref={containerRef}
        className="relative w-full rounded-2xl overflow-hidden shadow-[0_8px_30px_rgba(0,0,0,0.12)] border border-slate-200/80 aspect-video bg-black"
      />
    );
  }
);

YouTubeEmbed.displayName = 'YouTubeEmbed';
