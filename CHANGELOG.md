# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0]

### Added
- **In-App Music Downloader & OTA Dynamic Engine**: Integrated multi-platform audio resolver supporting Spotify, Apple Music, Bandcamp, and YouTube with live percentage progress, instant library injection, and OTA dynamic engine updates without APK recompile.
- **Unified Custom Wallpaper Studio**: Consolidated theme, player, and detail view background customization into a single interactive studio card in Settings featuring live mockups and segmented tab previews.
- **Detail View Custom Background**: Dedicated background styling for album, artist, and playlist detail views with independent blur (0–60) and dimming (0–90%) adjustments.
- **Edit Lyrics Auto 3-Dots Wave Toggle**: Per-song and global toggle controls in Edit Lyrics and Settings to enable or disable automatic instrumental 3-dot wave indicators.
- **Dedicated User Profile System**: Profile screen accessible from top header featuring custom photo upload with 1:1 square cropper, editable display name, bio, and real-time library counters (songs, playlists, favorites).
- **Interactive Search Discovery**: Dedicated Search tab with 8 category discovery tiles, instant search filtering, and dedicated local search history.
- **Resume Playback Session**: Inline resume card in Home screen restoring exact playback position and timestamp with smooth transition animations.
- **Mini-Player Progress Indicator**: Live linear playback progress bar along the bottom edge of the floating mini player.
- **Ambient Animated Splash Intro**: AMOLED launch intro with glowing Fley neon bloom and drifting micro-particle music visualizer.
- **Home Banner GIF Support**: Support for animated `.gif` and custom image banners with 1-tap hide/show collapse toggle.

### Changed
- **Spotify-Style Detail View Control Bar**: Redesigned detail view action bar featuring inline cover thumbnail, fast favorite toggle, queue action, inline options menu, shuffle state dot indicator, and prominent play/pause button.
- **Modern Library Filter Capsules**: Redesigned library pills into sleek 36px fully rounded capsules with active theme accent glow and 16px horizontal alignment matching Home and Search.
- **Swipeable 3-Tab Architecture**: Replaced static stack with fluid swipeable PageView navigation across Home, Search, and Your Library with instant bottom navbar jumps.
- **Unified Top App Bar**: Global persistent header displaying dynamic tab titles, user profile avatar with live thumbnail, download manager shortcut, and settings shortcut.

---

## [1.1.0]

### Added
- **Modern Artists & Albums View**: Interactive Grid and List layout switcher with persistent view mode preferences.
- **Top Highlights Carousel**: Horizontal scroll highlights for top artists and albums based on track count.
- **Native Audio Trimmer & Ringtone Cutter**: Frame-accurate Kotlin audio cutter engine (`AudioTrimmer.kt`) supporting MP3, AAC/M4A, and WAV formats with options to save cut files or set as device ringtone.
- **Track Options Scroll Hint**: Added bottom gradient fade and floating down-indicator hint to track context menu so users know more options exist below without needing a persistent scrollbar.

### Changed
- **Project Rebranding to Fley**: Renamed project, visual identity, and Android package ID (`com.fley`) to Fley; removed all residual legacy Flow aliases and references.
- **Track Context Menu Height**: Expanded context menu viewport to 72% screen height with a grab handle for faster option access.
- **Lyrics Editor Timing Controls**: Reorganized offset controls into a clean two-row layout with dedicated ±0.1s and ±0.5s buttons.
- **Rock-Solid Offline Audio Core**: Streamlined audio playback engine for pure offline playback, eliminating network timeouts and sudden playback pauses.
- **Audio Crossfade & Volume Reliability**: Ensured target volume is consistently restored during track transitions and playback restarts.

### Fixed
- **Lyrics Offset Clipping**: Resolved horizontal overflow and clipping of offset buttons on mobile viewports.
- **UI Scroll Performance & Lag**: Replaced non-virtualized `shrinkWrap` grids with `CustomScrollView` and lazy `SliverGrid` / `SliverList` delegates.
- **Binder IPC Congestion**: Removed duplicate native MediaStore artwork queries on list items, using instant memory cache and placeholders.
- **Compositing Layer Overhead**: Bypassed unnecessary opacity layer compositing in entrance animation wrappers when animations are disabled.
- **Startup Preload Optimization**: Restricted background artwork preloading to initial viewport items to keep startup instantaneous.

---

## [1.0.6]

### Added
- **Manual Lyrics Offset**: Per-track ±0.1s / ±0.5s fine-tuning to correct desynchronized `.lrc` files directly from the player.
- **Font Preloading**: Preload selected Google Fonts (Figtree, Inter, Plus Jakarta Sans) before first paint to eliminate startup font-flash.
- **Dynamic Viewport Stagger Animations**: Top 8 visible items now feature fluid cascading entrance animations when switching tabs.

### Changed
- **Architectural Decomposition**: Refactored monolithic files into modular domain logic and UI controllers (`lib/ui/`, `lib/logic/`, `lib/screens/`).
- **Album Art Gesture Refinement**: Single-tap album artwork opens synced lyrics; removed double-tap to favorite to prevent accidental toggles.
- **Smooth Lyrics Return**: Replaced abrupt jumps with a fluid 900ms cubic transition when returning to auto-follow lyrics mode.

### Fixed
- **Scoped Storage Backup Failure**: Resolved `errno = 13 (Permission Denied)` on Android 10–15 via a multi-tiered fallback path engine (Public Downloads → External Storage → App Documents).
- **Ringtone Cutter Race Condition**: Fixed a preview timer race condition where restarting audio cut previews prematurely killed active playback.

---

## [1.0.5]

### Added
- **Smooth Lyrics Auto-Follow**: Active lyrics glide smoothly to the center of the screen with a 600ms ease-out curve.
- **Lyrics Behavior Settings**: Configurable toggles for *Auto-Follow Lyrics* and *Hide Past Lyrics*.
- **Unified Sheets UI**: Redesigned Hidden Tracks and Equalizer bottom sheets to match Flow's design system with album art thumbnails.

### Changed
- **Uniform Lyric Typography**: Removed font-size jumping between active and inactive lines; opacity indicates active line.
- **Forgotten Gems Threshold**: Filter criteria refined to strict `playCount <= 1` so songs played $\ge 2$ times are excluded.

### Fixed
- **Stale Smart Playlist Views**: Fixed stale item ordering in Last Played and Forgotten Gems detail views by keying cache to track lists.
- **Accurate Play Count Increments**: Guarded position stream listener with position reset checks to prevent false play count increments during rapid track changes.
- **Lyrics Re-centering**: Fixed blank lyrics view when toggled mid-track via immediate viewport jumps to the active line.

---

## [1.0.4]

### Added
- **Automatic Instrumental Detection**: Automatic three-dot animated wave indicator for instrumental intros, bridges ($\ge 8\text{s}$), and outros.
- **Full Internationalization (i18n)**: Comprehensive localization across English, Indonesian, and Japanese via type-safe ARB files.

### Changed
- **Smart Playlist Recency**: Enhanced recency tracking and sorting mechanisms for Recently Added and Last Played playlists.

### Fixed
- **MediaStore Ghost Entries**: Strict file path deduplication filtering out deleted or corrupt media store entries.

---

## [1.0.3]

### Added
- **4 Player Background Modes**: Dynamic Gradient, Apple Blurred Cover, AMOLED Deep Black, and Custom Gallery Wallpaper.
- **Real-Time Wallpaper Editor**: Interactive sliders to adjust blur intensity (0–60) and dimming level (0–90%).
- **Playback Tempo & Pitch Controls**: Variable playback speed (0.5x – 2.0x) with optional Pitch Lock.
- **Headset Auto-Play**: Automatically resumes music playback when headphones or Bluetooth audio devices connect.

---

## [1.0.2]

### Changed
- **Modular Refactoring**: Separated monolithic settings dashboards into dedicated component builders and modal controllers.
- **Performance Optimizations**: Optimized repeat modes, persistent artwork cache, and detail view scrolling.

---

## [1.0.1]

### Added
- **Audio Ringtone Trimmer & Cutter**: Dual-handle slider editor with real-time slice preview and 1-tap export to `/Ringtones/`.
- **Dynamic Sleep Timer**: Built-in timer presets (15m, 30m, 60m) with soft volume fade-out.
- **Mini Music Visualizer**: Live-animated equalizer bars for actively playing tracks in song lists.

---

## [1.0.0]

### Added
- Initial public release of Flow Audio Player.
- Local media storage scanning with background playback via Android MediaSession.
- Synced LRC and embedded lyrics parsing.
- Dynamic color palette extraction from album artwork.
- Smart playlists (Favorites, Recently Added, Most Played, Last Played, Forgotten Gems).
- Custom user playlists with hold-to-select multi-select batch actions.
- Virtual metadata editor and custom album cover selection with built-in image cropper.
