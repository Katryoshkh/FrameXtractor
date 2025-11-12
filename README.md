# FrameXtractor

**FrameXtractor** is an interactive, FFmpeg-based video frame extractor. **FrameXtractor** produces **high-quality frames** with customizable **FPS, format, resolution, and output naming**.

## 🔹 Features

- Extract video frames **interactively** via the terminal.  
- Supports **any video format** that FFmpeg can read (MP4, MOV, MKV, AVI, etc.).  
- Customizable **frame rate (FPS)** for extraction.  
- Supports **image formats**: PNG (lossless) and JPG (with quality control).  
- Optional **scaling** or keep the **original video resolution (1:1)**.  
- **Custom output base name**, with default pattern if skipped.  
- Automatic **output folder creation**, with auto-increment if folder exists.  
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

You will be prompted to enter:
1. Video file path
2. FPS (frames per second) [default: 30]
3. Image format (png/jpg) [default: png]
4. Optional scaling (width:height, leave blank for original resolution)
5. Output base name [default: frame]

The script will display a summary and ask for confirmation before extraction starts.

**Example**
```
Enter video file path: /home/user/Videos/sample.mp4
Enter FPS (frames per second) [default: 30]: 60
Choose image format (png/jpg) [default: png]:
Enter scaling (leave blank to keep original resolution):
Enter output base name (default: frame): sample

==========================================================
Input video : /home/user/Videos/sample.mp4
Output dir  : /home/user/Videos/frames
FPS         : 60
Format      : png
Scale       : original (1:1)
Output name : sample_%04d.png
==========================================================
Proceed with extraction? (y/n): y
```
Frames will be saved in the frames/ folder as sample_0001.png, sample_0002.png, etc.

## 🔹 Notes

- Auto-increment output folder:
  If frames exists, a new folder will be created as frames(1), frames(2), etc.

- JPEG quality:
  Only applies to JPG format (2–31, lower = better).

- Original resolution:
  Leave scaling blank to preserve original video dimensions.

- Supported formats: Any video format FFmpeg can read.

## 🔹 Tips

- For long videos, increase FPS carefully, extracting too many frames can consume large disk space.

- Use PNG for maximum quality if storage is not an issue.

- Use custom base names to keep multiple extractions organized.

- Script works on Linux, macOS, and Android (Termux).

## 🔹 License

This project is licensed under the Apache-2.0 License.
