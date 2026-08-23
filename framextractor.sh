#!/bin/bash

echo "========================================================"
echo "   FrameXtractor — FFmpeg Interactive Frame Extractor   "
echo "========================================================"
echo

# ============================================================
# Globals
# ============================================================
VIDEO_EXTENSIONS=("mp4" "mkv" "mov" "avi" "flv" "wmv" "webm" "m4v" "mpg" "mpeg" "ts" "m2ts" "3gp")
declare -a FOUND_VIDEOS=()

# ============================================================
# Helper: scan current directory for video files
# ============================================================
scan_videos_in_cwd() {
    FOUND_VIDEOS=()
    local f ext vext
    for f in *; do
        [ -f "$f" ] || continue
        ext="${f##*.}"
        ext="${ext,,}"
        for vext in "${VIDEO_EXTENSIONS[@]}"; do
            if [[ "$ext" == "$vext" ]]; then
                FOUND_VIDEOS+=("$f")
                break
            fi
        done
    done
}

# ============================================================
# Helper: prompt user to pick one video from a numbered list
# Echoes the chosen file path (relative) to stdout.
# ============================================================
pick_single_video_from_list() {
    local prompt_label="$1"
    if [ ${#FOUND_VIDEOS[@]} -eq 0 ]; then
        echo "No video files found in current directory ($(pwd))." >&2
        return 1
    fi

    echo "$prompt_label" >&2
    echo "--------------------------------------------------------" >&2
    local i
    for i in "${!FOUND_VIDEOS[@]}"; do
        printf "  [%d] %s\n" "$((i+1))" "${FOUND_VIDEOS[$i]}" >&2
    done
    echo "--------------------------------------------------------" >&2

    local choice
    while true; do
        read -rp "Select video number: " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#FOUND_VIDEOS[@]}" ]; then
            echo "${FOUND_VIDEOS[$((choice-1))]}"
            return 0
        else
            echo "Invalid selection. Try again." >&2
        fi
    done
}

# ============================================================
# Helper: prompt user to pick MULTIPLE videos from a numbered list
# Sets global array SELECTED_VIDEOS
# ============================================================
declare -a SELECTED_VIDEOS=()
pick_multiple_videos_from_list() {
    SELECTED_VIDEOS=()
    if [ ${#FOUND_VIDEOS[@]} -eq 0 ]; then
        echo "No video files found in current directory ($(pwd))." >&2
        return 1
    fi

    echo "Select videos to extract (multiple files supported)" >&2
    echo "--------------------------------------------------------" >&2
    local i
    for i in "${!FOUND_VIDEOS[@]}"; do
        printf "  [%d] %s\n" "$((i+1))" "${FOUND_VIDEOS[$i]}" >&2
    done
    echo "--------------------------------------------------------" >&2
    echo "Enter numbers separated by space or comma (e.g. 1 2 4 or 1,2,4)" >&2
    echo "Or type 'all' to select every video found." >&2

    local raw
    while true; do
        read -rp "Select video numbers: " raw
        if [[ "${raw,,}" == "all" ]]; then
            SELECTED_VIDEOS=("${FOUND_VIDEOS[@]}")
            return 0
        fi

        raw="${raw//,/ }"
        local -a nums=($raw)
        local -a tmp=()
        local ok=1
        local n
        for n in "${nums[@]}"; do
            if [[ "$n" =~ ^[0-9]+$ ]] && [ "$n" -ge 1 ] && [ "$n" -le "${#FOUND_VIDEOS[@]}" ]; then
                tmp+=("${FOUND_VIDEOS[$((n-1))]}")
            else
                ok=0
                break
            fi
        done

        if [ "$ok" -eq 1 ] && [ ${#tmp[@]} -gt 0 ]; then
            SELECTED_VIDEOS=("${tmp[@]}")
            return 0
        else
            echo "Invalid selection. Try again." >&2
        fi
    done
}

# ============================================================
# Helper: resolve input path (blank -> scan+pick, else literal path)
# Echoes resolved path to stdout.
# ============================================================
resolve_single_input_path() {
    local input
    read -rp "Enter video file path (leave blank to browse current directory): " input

    if [ -z "$input" ]; then
        scan_videos_in_cwd
        local chosen
        chosen=$(pick_single_video_from_list "Select video to extract:") || return 1
        echo "$chosen"
        return 0
    else
        if [ ! -f "$input" ]; then
            echo "Error: File not found: $input" >&2
            return 1
        fi
        echo "$input"
        return 0
    fi
}

# ============================================================
# Helper: compute a non-colliding output dir given base dir + name
# Echoes resolved output dir path
# ============================================================
resolve_output_dir() {
    local base_dir="$1"
    local name="$2"
    local out="$base_dir/$name"
    local count=1
    while [ -d "$out" ]; do
        out="$base_dir/${name}($count)"
        count=$((count + 1))
    done
    echo "$out"
}

# ============================================================
# Core extraction params prompt (shared by single mode & manual multi mode)
# Populates globals: P_FPS P_FORMAT P_QUALITY P_SCALE P_BASENAME P_VF_FILTER P_PATTERN
# ============================================================
prompt_extraction_params() {
    local label="$1"   # e.g. "video1.mp4" - shown in prompts for clarity in multi mode
    local default_basename="${2:-frame}"

    if [ -n "$label" ]; then
        echo
        echo ">>> Settings for: $label"
    fi

    read -rp "Enter FPS (frames per second) [default: 30]: " P_FPS
    P_FPS=${P_FPS:-30}

    read -rp "Choose image format (png/jpg) [default: png]: " P_FORMAT
    P_FORMAT=${P_FORMAT:-png}
    P_FORMAT="${P_FORMAT,,}"
    if [[ "$P_FORMAT" != "png" && "$P_FORMAT" != "jpg" && "$P_FORMAT" != "jpeg" ]]; then
        echo "Invalid format. Please choose 'png' or 'jpg'."
        return 1
    fi

    P_QUALITY=""
    if [[ "$P_FORMAT" == "jpg" || "$P_FORMAT" == "jpeg" ]]; then
        read -rp "Set JPEG quality (2-31, lower = better) [default: 2]: " P_QUALITY
        P_QUALITY=${P_QUALITY:-2}
        if ! [[ "$P_QUALITY" =~ ^[0-9]+$ ]] || [ "$P_QUALITY" -lt 2 ] || [ "$P_QUALITY" -gt 31 ]; then
            echo "Invalid quality value. Must be between 2 and 31."
            return 1
        fi
    fi

    echo
    echo "Tip: format scaling = width:height (example: 1280:-1 or -1:720)"
    read -rp "Enter scaling (leave blank to keep original resolution): " P_SCALE

    P_VF_FILTER="fps=$P_FPS"
    if [ -n "$P_SCALE" ]; then
        if [[ "$P_SCALE" != *":"* ]]; then
            echo "Invalid scaling format. Use width:height (e.g., 1280:-1)"
            return 1
        fi
        P_VF_FILTER="$P_VF_FILTER,scale=$P_SCALE"
    else
        P_VF_FILTER="$P_VF_FILTER,scale=iw:ih"
    fi

    read -rp "Enter output base name (default: $default_basename): " P_BASENAME
    P_BASENAME=${P_BASENAME:-$default_basename}

    P_PATTERN="${P_BASENAME}_%04d.$P_FORMAT"
    return 0
}

# ============================================================
# Run the actual ffmpeg extraction for one video into one output dir
# Args: input_file output_dir vf_filter pattern format quality log_file
# ============================================================
run_extraction() {
    local input_file="$1"
    local output_dir="$2"
    local vf_filter="$3"
    local pattern="$4"
    local format="$5"
    local quality="$6"
    local log_file="$7"

    mkdir -p "$output_dir"

    if [[ "$format" == "png" ]]; then
        ffmpeg -hide_banner -loglevel info -i "$input_file" -vf "$vf_filter" \
               "$output_dir/$pattern" > "$log_file" 2>&1
    else
        ffmpeg -hide_banner -loglevel info -i "$input_file" -vf "$vf_filter" \
               -q:v "$quality" "$output_dir/$pattern" > "$log_file" 2>&1
    fi
    echo $? > "${log_file}.exitcode"
}

# ============================================================
# ============================================================
#                    SINGLE FILE MODE
# ============================================================
# ============================================================
run_single_mode() {
    echo
    echo "======================= SINGLE FILE MODE ======================="

    local INPUT
    INPUT=$(resolve_single_input_path) || exit 1
    if [ ! -f "$INPUT" ]; then
        echo "Error: File not found: $INPUT"
        exit 1
    fi

    local INPUT_DIR
    INPUT_DIR=$(dirname "$INPUT")

    echo
    read -rp "Enter output folder name (default: frames): " FOLDER_NAME
    FOLDER_NAME=${FOLDER_NAME:-frames}

    local OUTPUT_DIR
    OUTPUT_DIR=$(resolve_output_dir "$INPUT_DIR" "$FOLDER_NAME")

    prompt_extraction_params "" "frame" || exit 1

    echo
    echo "========================================================"
    echo "Input video : $INPUT"
    echo "Output dir  : $OUTPUT_DIR"
    echo "FPS         : $P_FPS"
    echo "Format      : $P_FORMAT"
    if [ -n "$P_SCALE" ]; then echo "Scale: $P_SCALE (custom)"; else echo "Scale: original (1:1)"; fi
    if [ -n "$P_QUALITY" ]; then echo "Quality: $P_QUALITY"; fi
    echo "Output name : $P_PATTERN"
    echo "========================================================"
    read -rp "Proceed with extraction? (y/n): " CONFIRM
    if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
        echo "Operation cancelled."
        exit 0
    fi

    mkdir -p "$OUTPUT_DIR"

    echo
    echo "Starting frame extraction..."
    if [[ "$P_FORMAT" == "png" ]]; then
        ffmpeg -hide_banner -loglevel info -i "$INPUT" -vf "$P_VF_FILTER" \
               "$OUTPUT_DIR/$P_PATTERN"
    else
        ffmpeg -hide_banner -loglevel info -i "$INPUT" -vf "$P_VF_FILTER" \
               -q:v "$P_QUALITY" "$OUTPUT_DIR/$P_PATTERN"
    fi

    echo
    echo "Extraction complete!"
    echo "Frames saved in: $OUTPUT_DIR/"
    echo "========================================================"
}

# ============================================================
# ============================================================
#                    MULTI FILE MODE
# ============================================================
# ============================================================

# ---- job storage (parallel arrays) ----
declare -a JOB_INPUT=()
declare -a JOB_OUTPUT_DIR=()
declare -a JOB_VF=()
declare -a JOB_PATTERN=()
declare -a JOB_FORMAT=()
declare -a JOB_QUALITY=()
declare -a JOB_LABEL=()

run_multi_mode() {
    echo
    echo "======================== MULTI FILE MODE ========================"

    scan_videos_in_cwd
    if [ ${#FOUND_VIDEOS[@]} -eq 0 ]; then
        echo "No video files found in current directory ($(pwd))."
        echo "Multi file mode currently browses the current directory only."
        exit 1
    fi

    pick_multiple_videos_from_list || exit 1

    local -a CHOSEN=("${SELECTED_VIDEOS[@]}")
    local n=${#CHOSEN[@]}

    echo
    echo "Selected ${n} video(s):"
    local i
    for i in "${!CHOSEN[@]}"; do
        printf "  [%d] %s\n" "$((i+1))" "${CHOSEN[$i]}"
    done

    # ------------------------------------------------------------
    # Grouping strategy
    # ------------------------------------------------------------
    echo
    echo "How should output folders be organized?"
    echo "  [1] One shared output folder for ALL selected videos"
    echo "  [2] Separate output folder for EACH video"
    echo "  [3] Custom grouping (e.g. video2 & video4 share a folder, others separate)"
    local GROUP_MODE
    while true; do
        read -rp "Choose grouping mode (1/2/3): " GROUP_MODE
        [[ "$GROUP_MODE" =~ ^[123]$ ]] && break
        echo "Invalid choice."
    done

    # GROUP_OF[idx] = group id string, used to map index -> group
    declare -a GROUP_OF=()
    declare -a GROUP_IDS=()      # unique group ids in order of first appearance

    case "$GROUP_MODE" in
        1)
            for ((i=0; i<n; i++)); do GROUP_OF[$i]="shared"; done
            GROUP_IDS=("shared")
            ;;
        2)
            for ((i=0; i<n; i++)); do GROUP_OF[$i]="g$i"; done
            for ((i=0; i<n; i++)); do GROUP_IDS+=("g$i"); done
            ;;
        3)
            echo
            echo "Custom grouping: assign a group number to each video."
            echo "Videos with the SAME group number will share one output folder."
            echo "Example: to merge video2 & video4, give them both group '1',"
            echo "and give video1 group '2', video3 group '3' (each unique = own folder)."
            echo
            for ((i=0; i<n; i++)); do
                local gnum
                read -rp "  Group number for [${CHOSEN[$i]}]: " gnum
                gnum=${gnum:-$((i+1))}
                GROUP_OF[$i]="grp_${gnum}"
            done
            # collect unique group ids preserving order
            for ((i=0; i<n; i++)); do
                local found=0
                local g
                for g in "${GROUP_IDS[@]}"; do
                    [[ "$g" == "${GROUP_OF[$i]}" ]] && found=1 && break
                done
                [ "$found" -eq 0 ] && GROUP_IDS+=("${GROUP_OF[$i]}")
            done
            ;;
    esac

    # ------------------------------------------------------------
    # Parameter mode: auto vs manual
    # ------------------------------------------------------------
    echo
    echo "How do you want to configure extraction settings?"
    echo "  [1] Auto — one shared FPS/format/scale/base-name applied to all videos"
    echo "            (output files auto-numbered per video, e.g. logo1, logo2, ...)"
    echo "  [2] Manual — configure folder name, output base name, FPS, format,"
    echo "               scale etc. individually for EACH video"
    local PARAM_MODE
    while true; do
        read -rp "Choose configuration mode (1/2): " PARAM_MODE
        [[ "$PARAM_MODE" =~ ^[12]$ ]] && break
        echo "Invalid choice."
    done

    JOB_INPUT=(); JOB_OUTPUT_DIR=(); JOB_VF=(); JOB_PATTERN=(); JOB_FORMAT=(); JOB_QUALITY=(); JOB_LABEL=()

    local CWD
    CWD=$(pwd)

    if [ "$PARAM_MODE" == "1" ]; then
        # -------------------- AUTO MODE --------------------
        prompt_extraction_params "" "frame" || exit 1

        # Ask folder base name once too (default 'frames')
        echo
        read -rp "Enter output folder base name (default: frames): " FOLDER_BASENAME
        FOLDER_BASENAME=${FOLDER_BASENAME:-frames}

        # Determine output dir per group
        declare -A GROUP_DIR_ASSIGNED=()
        for ((i=0; i<n; i++)); do
            local gid="${GROUP_OF[$i]}"
            local outdir
            if [ -z "${GROUP_DIR_ASSIGNED[$gid]:-}" ]; then
                if [ "$GROUP_MODE" == "1" ]; then
                    outdir=$(resolve_output_dir "$CWD" "$FOLDER_BASENAME")
                elif [ "$GROUP_MODE" == "2" ]; then
                    local base="${CHOSEN[$i]%.*}"
                    outdir=$(resolve_output_dir "$CWD" "${FOLDER_BASENAME}_${base}")
                else
                    outdir=$(resolve_output_dir "$CWD" "${FOLDER_BASENAME}_${gid}")
                fi
                GROUP_DIR_ASSIGNED[$gid]="$outdir"
            fi
            outdir="${GROUP_DIR_ASSIGNED[$gid]}"

            local pattern="${P_BASENAME}$((i+1))_%04d.$P_FORMAT"

            JOB_INPUT+=("${CHOSEN[$i]}")
            JOB_OUTPUT_DIR+=("$outdir")
            JOB_VF+=("$P_VF_FILTER")
            JOB_PATTERN+=("$pattern")
            JOB_FORMAT+=("$P_FORMAT")
            JOB_QUALITY+=("$P_QUALITY")
            JOB_LABEL+=("${CHOSEN[$i]}")
        done

    else
        # -------------------- MANUAL MODE --------------------
        declare -A GROUP_DIR_ASSIGNED=()
        for ((i=0; i<n; i++)); do
            local video="${CHOSEN[$i]}"
            local gid="${GROUP_OF[$i]}"

            echo
            echo "############################################################"
            echo "# Configuring: $video"
            echo "############################################################"

            local outdir="${GROUP_DIR_ASSIGNED[$gid]:-}"
            if [ -z "$outdir" ]; then
                local default_folder="frames"
                if [ "$GROUP_MODE" == "2" ]; then
                    default_folder="${video%.*}"
                fi
                local fname
                read -rp "Enter output folder name for this group (default: $default_folder): " fname
                fname=${fname:-$default_folder}
                outdir=$(resolve_output_dir "$CWD" "$fname")
                GROUP_DIR_ASSIGNED[$gid]="$outdir"
            else
                echo "This video is grouped with another — using shared folder: $outdir"
            fi

            prompt_extraction_params "$video" "${video%.*}" || exit 1

            JOB_INPUT+=("$video")
            JOB_OUTPUT_DIR+=("$outdir")
            JOB_VF+=("$P_VF_FILTER")
            JOB_PATTERN+=("$P_PATTERN")
            JOB_FORMAT+=("$P_FORMAT")
            JOB_QUALITY+=("$P_QUALITY")
            JOB_LABEL+=("$video")
        done
    fi

    # ------------------------------------------------------------
    # Summary + confirm
    # ------------------------------------------------------------
    echo
    echo "========================================================"
    echo "                 EXTRACTION SUMMARY"
    echo "========================================================"
    for ((i=0; i<${#JOB_INPUT[@]}; i++)); do
        echo "[$((i+1))] ${JOB_LABEL[$i]}"
        echo "     -> Output dir : ${JOB_OUTPUT_DIR[$i]}"
        echo "     -> Pattern    : ${JOB_PATTERN[$i]}"
        echo "     -> Format     : ${JOB_FORMAT[$i]}"
        [ -n "${JOB_QUALITY[$i]}" ] && echo "     -> Quality    : ${JOB_QUALITY[$i]}"
        echo "     -> Filter     : ${JOB_VF[$i]}"
    done
    echo "========================================================"

    # ------------------------------------------------------------
    # Concurrency limit (queueing) — avoid nuking the CPU by running
    # every ffmpeg job at once. User picks how many jobs may run
    # at the same time; the rest wait in queue.
    #
    # Default is 1 (fully sequential). We deliberately do NOT try to
    # auto-detect CPU core count here: tools like `nproc` or `getconf`
    # behave inconsistently across environments (plain Linux vs. WSL
    # vs. Git Bash on Windows vs. macOS vs. Termux on Android), and a
    # wrong/fallback number is worse than no number — it can look
    # like a real measurement when it isn't. On top of that, core
    # count alone never told us how strong a CPU actually is anyway:
    # an old laptop or a mobile/low-power chip can have many cores
    # and still choke on parallel ffmpeg encodes. Safer and more
    # honest to just default to 1 and let the user consciously raise
    # it if they know their own machine can handle more.
    # ------------------------------------------------------------
    local DEFAULT_SLOTS=1

    echo "Running every extraction job at once can overload the CPU,"
    echo "regardless of platform (Windows/Linux/macOS/Android) or core count."
    echo "Total jobs queued : ${#JOB_INPUT[@]}"
    local MAX_SLOTS
    while true; do
        read -rp "Max jobs to run simultaneously (1 = fully sequential, recommended) [default: $DEFAULT_SLOTS]: " MAX_SLOTS
        MAX_SLOTS=${MAX_SLOTS:-$DEFAULT_SLOTS}
        if [[ "$MAX_SLOTS" =~ ^[0-9]+$ ]] && [ "$MAX_SLOTS" -ge 1 ]; then
            break
        fi
        echo "Invalid value. Enter a whole number of 1 or more."
    done

    read -rp "Proceed with queued extraction of ${#JOB_INPUT[@]} job(s), $MAX_SLOTS at a time? (y/n): " CONFIRM
    if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
        echo "Operation cancelled."
        exit 0
    fi

    # ------------------------------------------------------------
    # Run with a bounded worker pool (queue) instead of firing
    # every job at once. At most MAX_SLOTS ffmpeg processes run
    # concurrently; remaining jobs wait until a slot frees up.
    # ------------------------------------------------------------
    local TMP_LOG_DIR
    TMP_LOG_DIR=$(mktemp -d)
    echo
    echo "Starting queued extraction (${#JOB_INPUT[@]} job(s), max $MAX_SLOTS concurrent)..."
    echo "Logs: $TMP_LOG_DIR"
    echo

    local total=${#JOB_INPUT[@]}
    local -a RUNNING_PIDS=()      # PIDs currently occupying a slot
    local -a RUNNING_IDX=()       # job index (0-based) for each running PID
    local next=0                  # next job index to launch
    local completed=0

    while [ "$completed" -lt "$total" ]; do
        # Fill free slots with queued jobs
        while [ "$next" -lt "$total" ] && [ "${#RUNNING_PIDS[@]}" -lt "$MAX_SLOTS" ]; do
            local logf="$TMP_LOG_DIR/job_$((next+1)).log"
            run_extraction "${JOB_INPUT[$next]}" "${JOB_OUTPUT_DIR[$next]}" "${JOB_VF[$next]}" \
                            "${JOB_PATTERN[$next]}" "${JOB_FORMAT[$next]}" "${JOB_QUALITY[$next]}" "$logf" &
            local newpid=$!
            RUNNING_PIDS+=("$newpid")
            RUNNING_IDX+=("$next")
            echo "  -> Launched job $((next+1))/$total: ${JOB_LABEL[$next]} (PID $newpid) [slot ${#RUNNING_PIDS[@]}/$MAX_SLOTS]"
            next=$((next + 1))
        done

        # Wait for whichever running job finishes first (not necessarily
        # the oldest), so a free slot is reused as soon as possible.
        local finished_pid
        if wait -n -p finished_pid "${RUNNING_PIDS[@]}" 2>/dev/null; then
            :
        fi
        if [ -z "$finished_pid" ]; then
            # Fallback for shells/edge-cases where -p didn't populate:
            # poll to find a PID that has already exited.
            local p
            for p in "${RUNNING_PIDS[@]}"; do
                if ! kill -0 "$p" 2>/dev/null; then
                    finished_pid="$p"
                    break
                fi
            done
        fi

        # Locate finished_pid's position in RUNNING_PIDS and drop it
        local pos=-1
        local j
        for j in "${!RUNNING_PIDS[@]}"; do
            if [ "${RUNNING_PIDS[$j]}" == "$finished_pid" ]; then
                pos=$j
                break
            fi
        done
        if [ "$pos" -ge 0 ]; then
            local finished_idx="${RUNNING_IDX[$pos]}"
            RUNNING_PIDS=("${RUNNING_PIDS[@]:0:$pos}" "${RUNNING_PIDS[@]:$((pos+1))}")
            RUNNING_IDX=("${RUNNING_IDX[@]:0:$pos}" "${RUNNING_IDX[@]:$((pos+1))}")
            completed=$((completed + 1))
            echo "  -> Finished job $((finished_idx+1))/$total: ${JOB_LABEL[$finished_idx]} ($completed/$total done)"
        fi
    done

    echo
    echo "========================================================"
    echo "                 EXTRACTION RESULTS"
    echo "========================================================"
    local all_ok=1
    for ((i=0; i<${#JOB_INPUT[@]}; i++)); do
        local logf="$TMP_LOG_DIR/job_$((i+1)).log"
        local ec="unknown"
        [ -f "${logf}.exitcode" ] && ec=$(cat "${logf}.exitcode")
        if [ "$ec" == "0" ]; then
            echo "[OK]   ${JOB_LABEL[$i]} -> ${JOB_OUTPUT_DIR[$i]}/"
        else
            all_ok=0
            echo "[FAIL] ${JOB_LABEL[$i]} (exit code: $ec) — see log: $logf"
        fi
    done
    echo "========================================================"
    if [ "$all_ok" -eq 1 ]; then
        echo "All extractions complete!"
    else
        echo "Some extractions failed. Check the logs above for details."
    fi
    echo "========================================================"
}

# ============================================================
# ============================================================
#                         ENTRY POINT
# ============================================================
# ============================================================
echo "Choose processing mode:"
echo "  [1] Single file"
echo "  [2] Multi file / parallel"
MODE=""
while true; do
    read -rp "Select mode (1/2): " MODE
    [[ "$MODE" =~ ^[12]$ ]] && break
    echo "Invalid choice."
done

if [ "$MODE" == "1" ]; then
    run_single_mode
else
    run_multi_mode
fi
