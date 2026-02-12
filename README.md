# video_proc.sh

A universal video remastering script that intelligently crops videos to center and scales them to target dimensions with support for both horizontal and vertical orientations.

## Features

- 🎯 **Smart scaling** - Automatically detects video orientation and scales appropriately
- 📐 **Aspect ratio conversion** - Convert videos to any aspect ratio (16:9, 4:3, 1:1, etc.)
- 🔄 **Batch processing** - Process multiple videos at once with pattern matching
- 📊 **Progress tracking** - Real-time progress bar with encoding speed
- 🎨 **High quality** - H.265/HEVC encoding with customizable quality settings
- 🔔 **Desktop notifications** - Optional notifications when processing completes
- 📝 **Detailed logging** - Optional log file generation for debugging
- 🛡️ **Safe execution** - Graceful interrupt handling and input validation

## Requirements

- `ffmpeg` - Video encoding
- `ffprobe` - Video analysis
- `gawk` - Mathematical calculations
- `notify-send` (optional) - Desktop notifications

### Installation (Ubuntu/Debian)

```bash
sudo apt update
sudo apt install ffmpeg gawk libnotify-bin
```

### Installation (macOS)

```bash
brew install ffmpeg gawk
```

## Quick Start

```bash
# Download the script
wget https://raw.githubusercontent.com/Kovaxn/video_proc/main/video_proc.sh
chmod +x video_proc.sh

# Process a single video (auto mode - smart scaling)
./video_proc.sh video.mp4

# Process multiple videos
./video_proc.sh video1.mp4 video2.mp4 video3.mp4

# Process all MP4 files in directory
./video_proc.sh *.mp4
```

## Usage

```bash
./video_proc.sh [OPTIONS] input1.mp4 [input2.mp4 ...]
```

### Options

| Option | Description | Default |
|--------|-------------|---------|
| `--aspect RATIO` | Target aspect ratio (e.g., 4:3, 16:9, 1:1) | `source` |
| `--scale VALUE` | Target output dimension (width or height) | `960` |
| `--scale-mode MODE` | Scaling strategy (see below) | `auto` |
| `--crf VALUE` | H.265 quality (0-51, lower = better) | `28` |
| `--preset NAME` | x265 encoding preset | `slow` |
| `--notify` | Enable desktop notifications | enabled |
| `--no-notify` | Disable desktop notifications | - |
| `--overwrite` | Overwrite existing output files | disabled |
| `--output-dir DIR` | Output directory | `_remaster` |
| `--dry-run` | Calculate parameters without encoding | disabled |
| `--log [FILE]` | Enable logging to file | disabled |
| `--version` | Show version and exit | - |
| `--help` | Show help message and exit | - |

### Scale Modes

The `--scale-mode` parameter controls how the `--scale` value is applied:

| Mode | Behavior | Use Case |
|------|----------|----------|
| `auto` | Width for horizontal, height for vertical | **Recommended** - handles mixed content |
| `width` | Always scale by width | Original behavior, legacy compatibility |
| `height` | Always scale by height | Vertical-first workflows |
| `long` | Scale by longer dimension | Ensure max dimension limit |
| `short` | Scale by shorter dimension | Ensure min dimension limit |

### Encoding Presets

| Preset | Speed | File Size | Quality |
|--------|-------|-----------|---------|
| `ultrafast` | ⚡⚡⚡⚡⚡ | Largest | Lower |
| `fast` | ⚡⚡⚡⚡ | Large | Good |
| `medium` | ⚡⚡⚡ | Medium | Better |
| `slow` | ⚡⚡ | Small | Excellent |
| `veryslow` | ⚡ | Smallest | Best |

## Examples

### Basic Usage

```bash
# Process with default settings (960px auto-scaling)
./video_proc.sh vacation.mp4

# Process all videos in current directory
./video_proc.sh *.mp4

# Process specific numbered files
./video_proc.sh video_{1..5}.mp4
```

### Horizontal Videos

```bash
# 1920x1080 → 960x540 (auto mode scales by width)
./video_proc.sh --scale 960 horizontal.mp4

# Faster encoding with lower quality
./video_proc.sh --preset fast --crf 32 horizontal.mp4

# High quality, smaller file
./video_proc.sh --preset veryslow --crf 24 horizontal.mp4
```

### Vertical Videos (TikTok, Instagram Reels, Stories)

```bash
# 1080x1920 → 540x960 (auto mode scales by height)
./video_proc.sh --scale 960 vertical.mp4

# Force scaling by height to specific size
./video_proc.sh --scale-mode height --scale 1280 vertical.mp4

# Create Instagram-compatible vertical video
./video_proc.sh --scale-mode height --scale 1920 --aspect 9:16 tiktok.mp4
```

### Aspect Ratio Conversion

```bash
# Convert vertical to square (1:1) for Instagram posts
./video_proc.sh --aspect 1:1 --scale 1080 vertical.mp4

# Convert horizontal to 4:3 (classic TV format)
./video_proc.sh --aspect 4:3 --scale 720 horizontal.mp4

# Convert to cinematic 21:9 widescreen
./video_proc.sh --aspect 21:9 --scale 1920 movie.mp4

# Convert to vertical 9:16 (TikTok/Stories)
./video_proc.sh --aspect 9:16 --scale-mode height --scale 1920 landscape.mp4
```

### Mixed Content (Horizontal + Vertical)

```bash
# Auto mode handles both correctly
./video_proc.sh --scale 960 *.mp4
# Horizontal 1920x1080 → 960x540
# Vertical 1080x1920 → 540x960

# Scale all by longest dimension to max 1920px
./video_proc.sh --scale-mode long --scale 1920 mixed_*.mp4
```

### Advanced Options

```bash
# Custom output directory
./video_proc.sh --output-dir ./processed *.mp4

# Overwrite existing files
./video_proc.sh --overwrite --scale 720 *.mp4

# Disable notifications for automated workflows
./video_proc.sh --no-notify batch_*.mp4

# Dry run to preview settings without encoding
./video_proc.sh --dry-run --aspect 16:9 --scale 1080 test.mp4

# Enable logging for debugging
./video_proc.sh --log processing.log problematic.mp4

# Custom log filename
./video_proc.sh --log my_custom.log video.mp4
```

### Production Workflows

```bash
# YouTube upload (1080p, high quality)
./video_proc.sh --scale-mode long --scale 1920 --crf 23 --preset slow youtube_*.mp4

# Instagram Reels (vertical, 1080x1920)
./video_proc.sh --aspect 9:16 --scale-mode height --scale 1920 --crf 26 reel_*.mp4

# Web optimization (smaller files, faster encoding)
./video_proc.sh --scale 720 --crf 30 --preset fast web_*.mp4

# Archive (maximum quality, minimum size)
./video_proc.sh --crf 20 --preset veryslow archive_*.mp4
```

## Understanding the Processing

### How Cropping Works

The script crops videos to achieve the target aspect ratio by:
1. Calculating the current aspect ratio
2. Comparing with target aspect ratio
3. Cropping to center (removing excess width or height)
4. Scaling to target dimension

Example:
```
Input:  1920x1080 (16:9)
Target: 4:3 aspect, 720px width

Steps:
1. Current ratio: 16:9 = 1.778
2. Target ratio:  4:3  = 1.333
3. Video is wider than target → crop width
4. Crop to: 1440x1080 (4:3 ratio, centered)
5. Scale to: 720x540 (4:3 ratio, target width)
```

### Auto Mode Logic

```
IF video_width >= video_height:
    scale_by = "width"  # Horizontal or square
ELSE:
    scale_by = "height" # Vertical
```

This ensures:
- Horizontal 1920x1080 with `--scale 960` → 960x540 ✅
- Vertical 1080x1920 with `--scale 960` → 540x960 ✅

### Output Information

During processing, you'll see:
```
======= video.mp4 : 1920x1080 (horizontal) : 2:30 =======
Original size (bytes): 45 234 567
Filter: crop=1920:1080:0:0,scale=960:540 → 960x540 (scaled by width)
Output: _remaster/video.mp4
[########################################] 100% | 2:30 | 1.2x
Output size (bytes): 12 345 678
```

## Tips & Best Practices

### Quality Settings (CRF)

- **18-23**: Near-lossless, very large files (archival)
- **23-28**: High quality, recommended for most uses
- **28-32**: Good quality, smaller files (web, social media)
- **32-36**: Acceptable quality, very small files (previews)

### Preset Selection

- Use `fast` or `medium` for quick tests
- Use `slow` (default) for general production
- Use `veryslow` for final renders or archival
- Use `ultrafast` only for rough previews

### Batch Processing

```bash
# Process in batches to avoid memory issues
./video_proc.sh video_{1..10}.mp4
./video_proc.sh video_{11..20}.mp4

# Use dry-run first to verify settings
./video_proc.sh --dry-run *.mp4
# Then run actual encoding
./video_proc.sh *.mp4
```

### Handling Errors

```bash
# Enable logging for troubleshooting
./video_proc.sh --log debug.log problematic.mp4

# Check log file for detailed error messages
cat debug.log

# Verify input file is valid
ffprobe problematic.mp4
```

## Common Use Cases

### 1. Social Media Optimization

```bash
# TikTok/Instagram Reels (9:16 vertical)
./video_proc.sh --aspect 9:16 --scale-mode height --scale 1920 --crf 26 social.mp4

# Instagram Feed (1:1 square)
./video_proc.sh --aspect 1:1 --scale 1080 --crf 26 post.mp4

# YouTube (16:9 horizontal)
./video_proc.sh --aspect 16:9 --scale 1920 --crf 23 youtube.mp4
```

### 2. File Size Reduction

```bash
# Aggressive compression (50-70% size reduction)
./video_proc.sh --scale 720 --crf 32 --preset fast large_files_*.mp4

# Balanced compression (30-50% size reduction)
./video_proc.sh --scale 960 --crf 28 --preset medium videos_*.mp4
```

### 3. Format Standardization

```bash
# Standardize all videos to 1080p 16:9
./video_proc.sh --aspect 16:9 --scale 1920 --output-dir ./standardized *.mp4

# Create thumbnail versions
./video_proc.sh --scale 480 --crf 32 --output-dir ./thumbnails *.mp4
```

## Troubleshooting

### Issue: "Command not found: ffmpeg"
**Solution:** Install ffmpeg:
```bash
# Ubuntu/Debian
sudo apt install ffmpeg

# macOS
brew install ffmpeg
```

### Issue: "Error: failed to read video resolution"
**Solution:** File may be corrupted or not a valid video format
```bash
# Check file with ffprobe
ffprobe -v error problematic.mp4

# Try re-downloading or converting the file
```

### Issue: "Output file already exists"
**Solution:** Use `--overwrite` flag or delete output manually
```bash
./video_proc.sh --overwrite video.mp4
# or
rm _remaster/video.mp4 && ./video_proc.sh video.mp4
```

### Issue: Processing is very slow
**Solution:** Use faster preset
```bash
# Instead of:
./video_proc.sh --preset veryslow video.mp4

# Try:
./video_proc.sh --preset fast video.mp4
```

### Issue: Output quality is poor
**Solution:** Lower CRF value (higher quality)
```bash
# Instead of:
./video_proc.sh --crf 32 video.mp4

# Try:
./video_proc.sh --crf 23 video.mp4
```

## Technical Details

### Dependencies
- **ffmpeg**: Video encoding (libx265, aac)
- **ffprobe**: Video metadata extraction
- **gawk**: Floating-point arithmetic for geometry calculations
- **notify-send** (optional): Desktop notifications

### Output Format
- **Video codec**: H.265/HEVC (libx265)
- **Audio codec**: AAC at 128kbps
- **Container**: MP4 with faststart flag (optimized for streaming)

### Supported Input Formats
Any format supported by ffmpeg, including:
- MP4, MOV, AVI, MKV, WebM
- H.264, H.265, VP8, VP9
- Various audio codecs

## Performance Benchmarks

Approximate processing speeds (depends on hardware):

| Preset | Speed (relative) | 1080p → 720p | 1080p → 1080p |
|--------|------------------|--------------|---------------|
| ultrafast | 10x | ~30 seconds | ~45 seconds |
| fast | 4x | ~1 minute | ~1.5 minutes |
| medium | 2x | ~2 minutes | ~3 minutes |
| slow | 1x | ~4 minutes | ~6 minutes |
| veryslow | 0.5x | ~8 minutes | ~12 minutes |

*Based on 5-minute 1080p source video on modern CPU*

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

### Development Setup

```bash
git clone https://github.com/Kovaxn/video_proc.git
cd video_proc
chmod +x video_proc.sh

# Run tests
./video_proc.sh --dry-run test_videos/*.mp4
```

## License

This project is open source and available under the MIT License.

## Changelog

### v1.2 (Current)
- Added `--scale-mode` parameter for flexible scaling
- Automatic orientation detection (horizontal/vertical/square)
- Comprehensive input validation
- Enhanced error messages
- Improved help documentation

### v1.1
- Initial public release
- Basic cropping and scaling functionality
- Progress bar and notifications
- Logging support

## Credits

Created by [Kovaxn](https://github.com/Kovaxn)

## Support

If you encounter any issues or have questions:
1. Check the [Troubleshooting](#troubleshooting) section
2. Enable logging with `--log` and review the log file
3. Open an issue on [GitHub](https://github.com/Kovaxn/video_proc/issues)

---

**Star ⭐ this repository if you find it useful!**