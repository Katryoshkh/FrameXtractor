# FrameXtractor

**FrameXtractor** is an interactive, FFmpeg-based video frame extractor. **FrameXtractor** produces **high-quality frames** with customizable **FPS, format, resolution, and output naming**.

## 🔹 Features

- Extract video frames **interactively** via the terminal.  
- Supports **any video format** that FFmpeg can read (MP4, MOV, MKV, AVI, etc.).  
- Customizable **frame rate (FPS)** for extraction.  
- Supports **image formats**: PNG (lossless) and JPG (with quality control).  
- Optional **scaling** or keep the **original video resolution (1:1)**.  
- **Custom output base name**, with default pattern if skipped.  
- **Custom output folder name**, with default pattern if skipped.  
- Automatic **output folder creation**, with auto-increment if folder exists.  
- **Directory auto-scan & file picker** — leave the path blank and pick a video by number instead of typing the full filename or path.  
- **Single or multi-file mode** — extract one video, or batch-process several videos in one run.  
- **Flexible output grouping** for multi-file mode: one shared folder, a separate folder per video, or custom grouping (e.g. video 2 & video 4 share a folder while others get their own).  
- **Auto or Manual configuration** for multi-file mode — apply one shared setting to every video, or configure each video's folder name, output name, FPS, format, quality, and scale independently, all in a single run.  
- **Safe, queued extraction** — jobs run through a concurrency-limited queue instead of firing all at once, defaulting to fully sequential (1 job at a time) so it won't overload weaker CPUs, with the option to raise concurrency manually.  
- Per-job **success/failure reporting** with log files for anything that fails.  
- **Lightweight Bash script**, requires only FFmpeg.

## 🔹 Installation

1. Clone the repository:

```bash
git clone https://github.com/Katryoshkh/FrameXtractor.git
cd FrameXtractor
```

2. Make the script executable:

```bash
chmod +x framextractor.sh
```

3. Ensure FFmpeg is installed and accessible:

```bash
ffmpeg -version
```

---

**FFmpeg installation:**

Linux (Debian/Ubuntu): 
```bash
sudo apt install ffmpeg
```
macOS (Homebrew): 
```bash
brew install ffmpeg
```
Android (Termux): 
```bash
pkg install ffmpeg
```
Windows: 
Download binaries from [ffmpeg.org](https://ffmpeg.org)


## 🔹 Usage
Run the script:
```bash
bash framextractor.sh
```
```bash
./framextractor.sh
```

You'll first be asked to choose a processing mode:
```
Choose processing mode:
  [1] Single file
  [2] Multi file / parallel
Select mode (1/2):
```

### Single File Mode

You will be prompted to enter:
1. Video file path — **leave it blank** to auto-scan the current directory and pick from a numbered list instead of typing the full path
2. Output folder name [default: frames]
3. FPS (frames per second) [default: 30]
4. Image format (png/jpg) [default: png]
5. JPEG quality, only if format is jpg [default: 2]
6. Optional scaling (width:height, leave blank for original resolution)
7. Output base name [default: frame]

The script will display a summary and ask for confirmation before extraction starts.

**Example** (path left blank, browsing the current directory)
```
Enter video file path (leave blank to browse current directory): 
Select video to extract:
--------------------------------------------------------
  [1] clip1.mp4
  [2] clip2.mp4
  [3] clip3.mp4
  [4] sample.mp4
--------------------------------------------------------
Select video number: 4

Enter output folder name (default: frames): sample_frames
Enter FPS (frames per second) [default: 30]: 60
Choose image format (png/jpg) [default: png]:
Enter scaling (leave blank to keep original resolution):
Enter output base name (default: frame): sample

========================================================
Input video : sample.mp4
Output dir  : ./sample_frames
FPS         : 60
Format      : png
Scale: original (1:1)
Output name : sample_%04d.png
========================================================
Proceed with extraction? (y/n): y
```
Frames will be saved in the `sample_frames/` folder as `sample_0001.png`, `sample_0002.png`, etc.

### Multi File Mode

Multi file mode browses the current directory (same picker as above), but lets you select **several videos at once**, decide how their output folders are grouped, and choose whether every video shares one configuration or is set up individually.

1. Select videos — space/comma-separated numbers (`1 2 4` or `1,2,4`), or type `all`
2. Choose folder grouping:
   - `[1]` One shared output folder for **all** selected videos
   - `[2]` A **separate** output folder for each video
   - `[3]` **Custom grouping** — assign a group number per video; videos sharing a number share a folder
3. Choose configuration mode:
   - `[1]` **Auto** — one shared FPS/format/scale/base-name for every video, with output files auto-numbered per video (`shot1`, `shot2`, `shot3`, ...)
   - `[2]` **Manual** — configure folder name, output base name, FPS, format, quality, and scale individually for **each** video, one after another, in the same run
4. Review the summary, then set how many jobs may run **at the same time** (defaults to `1`, fully sequential — see [Queued Extraction](#-queued-extraction-concurrency) below)
5. Confirm to start extraction

**Example** (3 videos selected, custom grouping, auto configuration)
```
Select videos to extract (multiple files supported)
--------------------------------------------------------
  [1] clip1.mp4
  [2] clip2.mp4
  [3] clip3.mp4
  [4] sample.mp4
--------------------------------------------------------
Select video numbers: 1,2,3

How should output folders be organized?
  [1] One shared output folder for ALL selected videos
  [2] Separate output folder for EACH video
  [3] Custom grouping (e.g. video2 & video4 share a folder, others separate)
Choose grouping mode (1/2/3): 3

Custom grouping: assign a group number to each video.
Videos with the SAME group number will share one output folder.
  Group number for [clip1.mp4]: 1
  Group number for [clip2.mp4]: 2
  Group number for [clip3.mp4]: 1

How do you want to configure extraction settings?
  [1] Auto — one shared FPS/format/scale/base-name applied to all videos
  [2] Manual — configure each video individually
Choose configuration mode (1/2): 1

Enter FPS (frames per second) [default: 30]: 60
Choose image format (png/jpg) [default: png]:
Enter scaling (leave blank to keep original resolution):
Enter output base name (default: frame): shot
Enter output folder base name (default: frames):

========================================================
                 EXTRACTION SUMMARY
========================================================
[1] clip1.mp4
     -> Output dir : ./frames_grp_1
     -> Pattern    : shot1_%04d.png
[2] clip2.mp4
     -> Output dir : ./frames_grp_2
     -> Pattern    : shot2_%04d.png
[3] clip3.mp4
     -> Output dir : ./frames_grp_1
     -> Pattern    : shot3_%04d.png
========================================================
Max jobs to run simultaneously (1 = fully sequential, recommended) [default: 1]: 
Proceed with queued extraction of 3 job(s), 1 at a time? (y/n): y

  -> Launched job 1/3: clip1.mp4 (PID 531) [slot 1/1]
  -> Finished job 1/3: clip1.mp4 (1/3 done)
  -> Launched job 2/3: clip2.mp4 (PID 537) [slot 1/1]
  -> Finished job 2/3: clip2.mp4 (2/3 done)
  -> Launched job 3/3: clip3.mp4 (PID 543) [slot 1/1]
  -> Finished job 3/3: clip3.mp4 (3/3 done)

========================================================
                 EXTRACTION RESULTS
========================================================
[OK]   clip1.mp4 -> ./frames_grp_1/
[OK]   clip2.mp4 -> ./frames_grp_2/
[OK]   clip3.mp4 -> ./frames_grp_1/
========================================================
All extractions complete!
```
`clip1.mp4` and `clip3.mp4` end up merged in `frames_grp_1/`, while `clip2.mp4` gets its own `frames_grp_2/` — each with independently numbered output files.

## 🔹 Queued Extraction (Concurrency)

Multi file mode never fires every `ffmpeg` job at once. Instead, jobs are placed in a **queue** with a configurable number of simultaneous slots:

- Default is **`1`** — fully sequential, one video processed at a time.
- You can raise this if you know your CPU can handle it, but there's no auto-detected "safe" number suggested — core count (`nproc`, etc.) doesn't reliably reflect real-world CPU strength, and detection tools behave inconsistently across Linux, WSL, Git Bash on Windows, macOS, and Android/Termux anyway.
- As soon as any running job finishes, the next queued job takes its slot — no need to wait for the whole batch.
- After all jobs finish, a results table shows `[OK]` / `[FAIL]` per video, with a log file path for anything that failed.

## 🔹 Notes

- Auto-increment output folder:
  If the output folder already exists (default frames, or any custom name), a new folder will be created as `foldername(1)`, `foldername(2)`, etc.

- JPEG quality:
  Only applies to JPG format (2–31, lower = better).

- Original resolution:
  Leave scaling blank to preserve original video dimensions.

- Supported formats: Any video format FFmpeg can read. The directory scanner/picker looks for these extensions: `mp4`, `mkv`, `mov`, `avi`, `flv`, `wmv`, `webm`, `m4v`, `mpg`, `mpeg`, `ts`, `m2ts`, `3gp`. Other formats FFmpeg can read still work if you type the path manually instead of using the picker.

- Directory picker:
  Only scans the **current working directory** (not subfolders). Run the script from inside the folder containing your videos, or `cd` there first.

- Grouped output in multi file mode:
  Videos assigned to the same group (shared folder, or same custom group number) are written into that folder using their own independently numbered filename pattern, so files from different videos never overwrite each other.

- Concurrency default:
  Multi file mode defaults to `1` simultaneous job (fully sequential) to avoid overloading the CPU — see [Queued Extraction](#-queued-extraction-concurrency).

## 🔹 Tips

- For long videos, increase FPS carefully, extracting too many frames can consume large disk space.

- Use PNG for maximum quality if storage is not an issue.

- Use custom base names to keep multiple extractions organized.

- Leave the video path blank to skip typing full filenames — the picker only needs the number.

- Use **custom grouping** in multi file mode when you want related clips (e.g. parts of the same scene) merged into one output folder while everything else stays separate.

- Use **Auto** configuration for quick batch jobs with the same settings; use **Manual** when each video needs its own FPS, format, or scale.

- Only raise the concurrency slot count above `1` if you know your CPU can handle multiple simultaneous FFmpeg encodes — this is especially relevant on older laptops or mobile devices, regardless of core count.

- Script works on Linux, macOS, and Android (Termux).

## 🔹 License

This project is licensed under the Apache-2.0 License.
