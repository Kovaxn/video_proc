#!/usr/bin/env bash

# (Universal) video remastering script: crops video to center and scales to target width or height
# Source: https://github.com/Kovaxn/video_proc/
#
# Usage: ./video_proc.sh file1.mp4 file2.mp4 "File 014.1.mp4" ...
#   Single file:
#   ./video_proc.sh "File 010.mp4"
#
#   Multiple files:
#   ./video_proc.sh File\ 010.1.mp4 File\ 010.2.mp4 File\ 011.mp4
#
#   All files by pattern:
#   ./video_proc.sh File*.mp4
#   ./video_proc.sh "File 010."*.mp4
#
#   File 10 to 13:
#   ./video_proc.sh File\ 01{0..3}.mp4
#######################################

#--------------------------------------
# Enable safer script execution:
#   -u - treat unset variables as an error (prevents typos like $myvar vs $myvarr)
#   -o - pipefail, make pipelines fail if any command in the pipe fails (not just the last one)
# Note: -e (errexit) is intentionally omitted to allow partial success when processing multiple files
set -uo pipefail
#--------------------------------------

# Handle interruption (Ctrl+C) gracefully
cleanup_on_exit() {
    # Shutting down the proc to avoid recursion
    trap - SIGINT SIGTERM

    echo
    # Time to ffmpeg correct exit on interrupt
    log_message WARNING "Processing interrupted. Waiting for ffmpeg to finish..."
    sleep 2

    # Remove incomplete file if any
    if [[ -n "$CURRENT_OUTPUT" && -f "$CURRENT_OUTPUT" ]]; then
        rm -f "$CURRENT_OUTPUT" 2>/dev/null
        log_message WARNING "Incomplete output file removed: $CURRENT_OUTPUT"
    fi

    if [[ $processed -gt 0 ]]; then
        log_message WARNING "Processing interrupted by user. Successfully processed: $processed out of $total_files"
    else
        log_message WARNING "Processing interrupted by user. No files were processed."
    fi
    exit 130
}

# Set up signal traps
trap cleanup_on_exit SIGINT SIGTERM


#######################################
# DEFAULT PARAMETERS
#######################################
VERSION="1.3"
ASPECT="source"
SCALE=960
SCALE_MODE="auto"
CRF=28
PRESET="slow"
NOTIFY=true
OVERWRITE=false
OUTPUT_DIR="_remaster"
DRY_RUN=false
SCRIPT_NAME="${0##*/}"
LOG_FILE=""

#######################################
# HELP FUNCTION
#######################################
show_help() {
    cat <<EOF
Script version $VERSION

Usage: $0 [OPTIONS] input1.mp4 [input2.mp4 ...]

Options:
  --aspect RATIO      Target aspect ratio (e.g. 4:3, 16:9). Default: source
  --scale VALUE       Target output dimension (width or height, see --scale-mode). Default: 960
  --scale-mode MODE   How to apply --scale value:
                        auto   - smart detection (width for horizontal, height for vertical)
                        width  - always scale by width (original behavior)
                        height - always scale by height
                        long   - scale by longer side
                        short  - scale by shorter side
                      Default: auto
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

Examples:
  $0 File*.mp4
  $0 --aspect 4:3 --scale 720 "File 010.mp4" "File 011.mp4"
  $0 --no-notify --overwrite File_010.mp4
  $0 --scale-mode height --scale 1280 vertical_video.mp4
  $0 --scale-mode long --scale 1920 mixed_videos*.mp4
EOF
    exit 0
}

#######################################
# CHECK DEPENDENCIES
#######################################
check_dependencies() {
    local missing=()
    for cmd in ffmpeg ffprobe gawk; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing+=("$cmd")
        fi
    done
    if (( ${#missing[@]} > 0 )); then
        echo "Error: missing required dependencies: ${missing[*]}" >&2
        echo "Please install them and try again." >&2
        exit 1
    fi
}

#######################################
# PARSE OPTIONS
#######################################
POSITIONAL=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help) show_help ;;
        --aspect)
            [[ $# -lt 2 ]] && { echo "Error: --aspect requires a value" >&2; exit 1; }
            ASPECT="$2"; shift 2 ;;
        --scale)
            [[ $# -lt 2 ]] && { echo "Error: --scale requires a value" >&2; exit 1; }
            SCALE="$2"; shift 2 ;;
        --scale-mode)
            [[ $# -lt 2 ]] && { echo "Error: --scale-mode requires a value" >&2; exit 1; }
            SCALE_MODE="$2"; shift 2 ;;
        --crf)
            [[ $# -lt 2 ]] && { echo "Error: --crf requires a value" >&2; exit 1; }
            CRF="$2"; shift 2 ;;
        --preset)
            [[ $# -lt 2 ]] && { echo "Error: --preset requires a value" >&2; exit 1; }
            PRESET="$2"; shift 2 ;;
        --notify) NOTIFY=true; shift ;;
        --no-notify) NOTIFY=false; shift ;;
        --overwrite) OVERWRITE=true; shift ;;
        --output-dir)
            [[ $# -lt 2 ]] && { echo "Error: --output-dir requires a value" >&2; exit 1; }
            OUTPUT_DIR="$2"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        --log)
            if [[ $# -gt 1 && "$2" != --* ]]; then
                LOG_FILE="$2"
                shift 2
            else
                # Auto-generate log filename
                LOG_FILE="video_proc_$(date +%Y%m%d_%H%M%S).log"
                shift
            fi
            ;;
        --version)
            echo "$SCRIPT_NAME v$VERSION"
            exit 0
            ;;
        -*|--*) echo "Unknown option: $1" >&2; exit 1 ;;
        *) POSITIONAL+=("$1"); shift ;;
    esac
done

set -- "${POSITIONAL[@]}"

if [[ $# -eq 0 ]]; then
    echo "Error: please specify at least one video file" >&2
    echo "Use --help for usage instructions" >&2
    exit 1
fi

#######################################
# ARGUMENT VALIDATION
#######################################
# Validate --aspect: source | W:H
if [[ "$ASPECT" != "source" ]]; then
    if [[ ! "$ASPECT" =~ ^[0-9]+:[0-9]+$ ]]; then
        echo "Error: invalid aspect ratio '$ASPECT'. Expected 'source' or W:H (e.g. 16:9)" >&2
        exit 1
    fi
fi

# Validate --scale: positive integer
if [[ ! "$SCALE" =~ ^[0-9]+$ || "$SCALE" -le 0 ]]; then
    echo "Error: --scale must be a positive integer (got '$SCALE')" >&2
    exit 1
fi

# Validate --scale-mode
case "$SCALE_MODE" in
    auto|width|height|long|short) ;;
    *)
        echo "Error: invalid --scale-mode value: $SCALE_MODE" >&2
        echo "Valid values: auto, width, height, long, short" >&2
        exit 1
        ;;
esac

# Validate --crf: 0-51
if [[ ! "$CRF" =~ ^[0-9]+$ ]] || (( CRF < 0 || CRF > 51 )); then
    echo "Error: --crf must be an integer between 0 and 51 (got '$CRF')" >&2
    exit 1
fi

# Validate --preset
case "$PRESET" in
    ultrafast|superfast|veryfast|faster|fast|medium|slow|slower|veryslow|placebo) ;;
    *)
        echo "Error: invalid --preset value: $PRESET" >&2
        echo "Valid values: ultrafast, superfast, veryfast, faster, fast, medium, slow, slower, veryslow, placebo" >&2
        exit 1
        ;;
esac

#######################################
# CHECK NOTIFY
#######################################
if ! command -v notify-send >/dev/null 2>&1; then
    NOTIFY=false
fi

# Check required tools before proceeding
check_dependencies

# Logging function
log_message() {
    local level="$1"
    shift
    local msg="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    if [[ -n "$LOG_FILE" ]]; then
        printf "[%s] %s: %s\n" "$timestamp" "$level" "$msg" >> "$LOG_FILE"
    fi

    case "$level" in
        ERROR|WARNING|WARN)
            echo "$msg" >&2
            ;;
        *)
            echo "$msg"
            ;;
    esac
}

#######################################
# COLORS
#######################################
if [[ -t 1 ]]; then
    COLOR_GREEN='\033[32m'
    COLOR_GREEN_LIGHT='\033[1;32m'
    COLOR_YELLOW='\033[33m'
    COLOR_YELLOW_LIGHT='\033[1;33m'
    COLOR_BLUE='\033[34m'
    COLOR_RESET='\033[0m'
else
    COLOR_GREEN=""
    COLOR_GREEN_LIGHT=""
    COLOR_YELLOW=""
    COLOR_YELLOW_LIGHT=""
    COLOR_BLUE=""
    COLOR_RESET=""
fi

#######################################
# CREATE OUTPUT DIR
#######################################
mkdir -p "$OUTPUT_DIR" || { log_message ERROR "Error: cannot create output directory '$OUTPUT_DIR'"; exit 1; }
total_files=$#
processed=0
CURRENT_OUTPUT=""

#######################################
# FUNCTIONS
#######################################
format_time() {
    local sec=$1
    local h=$((sec/3600))
    local m=$(((sec%3600)/60))
    local s=$((sec%60))
    if ((h>0)); then
        printf "%d:%02d:%02d" "$h" "$m" "$s"
    else
        printf "%d:%02d" "$m" "$s"
    fi
}

format_number() {
    local num="$1"
    if [[ ! "$num" =~ ^[0-9]+$ ]]; then
        echo "0"
        return
    fi
    echo "$num" | gawk '{
        n = length($0)
        result = ""
        for (i = n; i >= 1; i--) {
            result = substr($0, i, 1) result
            if ((n - i + 1) % 3 == 0 && i > 1) {
                result = " " result
            }
        }
        print result
    }'
}

calc_geometry() {
    gawk -v W="$1" -v H="$2" -v ASPECT="$3" -v SCALE="$4" -v SCALE_MODE="$5" -v ORIENTATION="$6" '
    function even(x){return int(x/2)*2}
    BEGIN{
        cur=W/H
        if(ASPECT=="source"){tgt=cur}else{split(ASPECT,a,":"); tgt=a[1]/a[2]}
        if(cur>tgt){crop_h=H; crop_w=even(H*tgt); x=even((W-crop_w)/2); y=0}
        else if(cur<tgt){crop_w=W; crop_h=even(W/tgt); x=0; y=even((H-crop_h)/2)}
        else{crop_w=W; crop_h=H; x=y=0}

        # Determine which dimension to scale
        if(SCALE_MODE=="auto"){
            # Auto: width for horizontal/square, height for vertical
            if (ORIENTATION == "horizontal") {
                scale_by = "width"
            } else {
                scale_by = "height"
            }
        } else if(SCALE_MODE=="width"){
            scale_by="width"
        } else if(SCALE_MODE=="height"){
            scale_by="height"
        } else if(SCALE_MODE=="long"){
            # Long: scale by longer side
            if(crop_w >= crop_h){
                scale_by="width"
            } else {
                scale_by="height"
            }
        } else if(SCALE_MODE=="short"){
            # Short: scale by shorter side
            if(crop_w <= crop_h){
                scale_by="width"
            } else {
                scale_by="height"
            }
        }

        # Calculate final dimensions
        if(scale_by=="width"){
            final_w=SCALE
            final_h=even(crop_h*SCALE/crop_w)
        } else {
            final_h=SCALE
            final_w=even(crop_w*SCALE/crop_h)
        }

        printf "crop_w=%d crop_h=%d x=%d y=%d final_w=%d final_h=%d scale_by=%s",crop_w,crop_h,x,y,final_w,final_h,scale_by
    }'
}

progress_bar() {
    local current=$1
    local total=$2
    local speed=$3
    local width=40
    local percent filled bar_fill bar_spaces cur_time

    # Avoid division by zero
    if (( total == 0 )); then total=1; fi

    percent=$(gawk -v c="$current" -v t="$total" 'BEGIN{printf "%.1f",(c/t)*100}')
    filled=$(gawk -v c="$current" -v t="$total" -v w="$width" 'BEGIN{printf "%d",(c/t)*w}')
    bar_fill=$(printf '%*s' "$filled" '' | tr ' ' '#')
    bar_spaces=$(printf '%*s' "$((width-filled))" '' | tr ' ' '-')
    cur_time=$(format_time "$current")

    printf "\r[%b%s%b%b%s%b] %b%3d%%%b | %s | %-7s" \
        "$COLOR_GREEN_LIGHT" "$bar_fill" "$COLOR_RESET" \
        "$COLOR_BLUE" "$bar_spaces" "$COLOR_RESET" \
        "$COLOR_YELLOW_LIGHT" "${percent%.*}" "$COLOR_RESET" \
        "$cur_time" "$speed"
}

#######################################
# PROCESS FILES
#######################################
process_one() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        log_message ERROR "Error: file not found: $file"
        $NOTIFY && notify-send -i dialog-error "File not found" "$(basename "$file")" -t 8000
        return
    fi

    # Get input file size
    # stat -f%z — for macOS/BSD
    # stat -c%s — for Linux
    input_size_bytes=0
    if [[ -f "$file" ]]; then
        input_size_bytes=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo 0)
    fi
    input_size_formatted=$(format_number "$input_size_bytes")

    output="$OUTPUT_DIR/$(basename "$file")"

    # Get original video resolution (first video stream)
    size=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0:s=x "$file" 2>/dev/null | head -n1)
    if [[ -z "$size" || "$size" == "N/A" ]]; then
        log_message ERROR "Error: failed to read video resolution for: $file"
        log_message ERROR "The file may be corrupted or not a valid video."
        return
    fi
    width=${size%x*}
    height=${size#*x}

    # Get rotation metadata (for mobile videos)
    rotation=$(ffprobe -v error -select_streams v:0 -show_entries stream_tags=rotate -of default=nw=1:nk=1 "$file" 2>/dev/null)
    # Also check side_data_list for displaymatrix rotation
    if [[ -z "$rotation" ]]; then
        rotation=$(ffprobe -v error -select_streams v:0 -show_entries side_data=rotation -of default=nw=1:nk=1 "$file" 2>/dev/null)
    fi

    effective_width="$width"
    effective_height="$height"

    if [[ "$rotation" == "90" || "$rotation" == "270" || \
          "$rotation" == "-90" || "$rotation" == "-270" ]]; then
        effective_width="$height"
        effective_height="$width"
    fi

    # Get duration
    duration_sec=$(ffprobe -v error -show_entries format=duration -of default=nk=1:nw=1 "$file" 2>/dev/null)
    duration_sec=${duration_sec%.*}
    [[ -z "$duration_sec" || "$duration_sec" == "N/A" ]] && duration_sec=0
    duration_formatted=$(format_time "$duration_sec")

    # Determine video orientation (after accounting for rotation)
    local orientation="horizontal"
    if (( effective_width < effective_height )); then
        orientation="vertical"
    elif (( effective_width == effective_height )); then
        orientation="square"
    fi

    # Calculate crop and scale parameters
    local geometry_str
    geometry_str=$(calc_geometry \
        "$effective_width" \
        "$effective_height" \
        "$ASPECT" \
        "$SCALE" \
        "$SCALE_MODE" \
        "$orientation")
    if [[ -z "$geometry_str" || "$geometry_str" != *"crop_w="* ]]; then
        log_message ERROR "Error: failed to calculate geometry for: $file"
        return
    fi
    eval "$geometry_str"

    # Build filter chain with rotation handling
    local filter_chain=""
    filter_chain="crop=${crop_w}:${crop_h}:${x}:${y},scale=${final_w}:${final_h}"

    echo
    echo -e "======= ${COLOR_YELLOW_LIGHT}$(basename "$file") : ${width}x${height} ($orientation) : ${duration_formatted}${COLOR_RESET} ======="
    if [[ -n "$rotation" && "$rotation" != "0" ]]; then
        echo -e "${COLOR_GREEN_LIGHT}Rotation metadata: ${rotation}°${COLOR_RESET}"
    fi
    echo -e "Original size (bytes): ${COLOR_GREEN_LIGHT}${input_size_formatted}${COLOR_RESET}"
    echo "Filter: $filter_chain → ${final_w}x${final_h} (scaled by $scale_by)"
    echo "Output: $output"

    # Dry-run logic
    if [[ "$DRY_RUN" == true ]]; then
        if [[ -f "$output" ]]; then
            log_message WARN "WARNING: output file already exists"
        fi
        echo "Dry run: encoding skipped"
        ((processed++))
        return
    fi

    log_message INFO "Start processing $file, filter: $filter_chain, size: ${input_size_bytes}b, orientation: $orientation, rotation: ${rotation:-0}°, scaled by: $scale_by"

    # Skip if output exists and not overwriting
    if [[ -f "$output" && "$OVERWRITE" == false ]]; then
        log_message WARN "WARNING: output file already exists (use --overwrite to replace)"
        return
    elif [[ -f "$output" && "$OVERWRITE" == true ]]; then
        log_message WARN "WARNING: output file was overwritten"
    fi

    # Record current output file for cleanup on interruption
    CURRENT_OUTPUT="$output"

    # -------------------------------
    # ffmpeg with progress bar
    # -------------------------------
    ffmpeg -nostdin -hide_banner -loglevel error \
        -i "$file" \
        -vf "$filter_chain" \
        -metadata:s:v:0 rotate=0 \
        -c:v libx265 -preset "$PRESET" -crf "$CRF" \
        -c:a aac -b:a 128k \
        -movflags +faststart \
        -y "$output" \
        -progress pipe:1 2>/dev/null | {
            term_cols=$(tput cols 2>/dev/null || echo 70)
            reserved=30
            bar_width=$(( term_cols - reserved ))
            (( bar_width < 30 )) && bar_width=30
            (( bar_width > 70 )) && bar_width=70

            speed="--.-x"
            current_sec=0

            while IFS='=' read -r key value; do
                case "$key" in
                    out_time_ms)
                        current_sec=$((value/1000000))
                        (( current_sec > duration_sec )) && current_sec=$duration_sec
                        progress_bar "$current_sec" "$duration_sec" "$speed"
                        ;;
                    speed)
                        speed_val="${value# }"
                        speed_val="${speed_val//[^0-9.]/}x"
                        speed=$(printf "%-7s" "$speed_val")
                        ;;
                    progress)
                        if [[ "$value" == "end" ]]; then
                            full_bar=$(printf '%*s' "$bar_width" '' | tr ' ' '#')
                            printf "\r[%b%s%b] 100%% | %s | %-7s\n" \
                                "$COLOR_GREEN" "$full_bar" "$COLOR_RESET" "$duration_formatted" "$speed"
                        fi
                        ;;
                esac
            done
        }

    CURRENT_OUTPUT=""

    log_message INFO "Done: $output"

    if [[ "$DRY_RUN" == false ]]; then
        # Get output file size
        output_size_bytes=0
        if [[ -f "$output" ]]; then
            output_size_bytes=$(stat -f%z "$output" 2>/dev/null || stat -c%s "$output" 2>/dev/null || echo 0)
        fi
        output_size_formatted=$(format_number "$output_size_bytes")

        # Calculate compression ratio (avoid division by zero)
        compression_ratio="N/A"
        if (( input_size_bytes > 0 && output_size_bytes > 0 )); then
            # Use awk for floating-point division
            compression_ratio=$(awk "BEGIN {printf \"%.2fx\", $input_size_bytes / $output_size_bytes}")
        fi
        echo -e "Output size (bytes): ${COLOR_GREEN_LIGHT}${output_size_formatted}${COLOR_RESET}"
        log_message INFO "Size (bytes): ${input_size_bytes} -> ${output_size_bytes}, compression: $compression_ratio"
    fi

    ((processed++))
    $NOTIFY && notify-send -i video-x-generic "Video processed" "$(basename "$file")" -t 5000
}

# Process all files
for file in "$@"; do
    process_one "$file"
done

#######################################
# FINAL SUMMARY
#######################################
echo
log_message INFO "Processing complete. Successfully processed: $processed out of $total_files"
$NOTIFY && {
    if (( processed == total_files )); then
        notify-send -i checkbox-checked "All files processed" "$processed out of $total_files" -t 15000
    elif (( processed > 0 )); then
        notify-send -i dialog-warning "Processing finished with errors" "Successfully processed: $processed out of $total_files" -t 15000
    else
        notify-send -i dialog-error "All files failed" "Successfully processed: 0 out of $total_files" -t 15000
    fi
}

# Exit code:
#   0 — at least one file was processed successfully
#   1 — no files were processed (all failed or skipped)
# This allows partial success in batch processing.
if (( processed == 0 )); then
    exit 1
else
    exit 0
fi
