# (Universal) video remastering script: crops video to center and scales to target width
This script is a universal video remastering tool that crops and scales videos to a target width. It includes options for aspect ratio, scale, CRF quality, and more, while handling interruptions and logging.

Usage: ```./video_proc.sh file1.mp4 file2.mp4 "File 014.1.mp4" ...```

Single file:
```./video_proc.sh "File 010.mp4"```

Multiple files:
```./video_proc.sh File\ 010.1.mp4 File\ 010.2.mp4 File\ 011.mp4```

All files by pattern:
```./video_proc.sh File*.mp4```
```./video_proc.sh "File 010."*.mp4```

File 10 to 13:
```./video_proc.sh File\ 01{0..3}.mp4```

```
Usage: $0 [OPTIONS] input1.mp4 [input2.mp4 ...]

Options:
  --aspect RATIO      Target aspect ratio (e.g. 4:3, 16:9). Default: source
  --scale WIDTH       Target output width. Height is calculated proportionally. Default: 960
  --crf VALUE         CRF quality (H.265). Lower = better quality. Default: 28
  --preset NAME       x265 preset (ultrafast, fast, medium, slow, veryslow). Default: slow
  --notify            Enable desktop notifications (default)
  --no-notify         Disable desktop notifications
  --overwrite         Overwrite output files if they exist
  --output-dir DIR    Directory to save processed files. Default: _remaster
  --dry-run           Only calculate filter parameters, do not encode
  --log [FILE]        Enable logging. If FILE is not provided, auto-generates a log file in current directory.
  --version           Show version and exit
  --help              Show this help message and exit
```
