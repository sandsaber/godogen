# Workstation Setup

Shared workstation setup for the Godogen source repo.

## Bevy Docs Cache

If you work on the Bevy source in this repo, choose a shared docs folder and populate it once after clone:

```bash
./setup_bevy_docs.sh /absolute/or/user/path/to/bevy-docs
```

This script:

- links `bevy/skills/bevy-help/docs/` to one shared docs cache
- creates shallow `bevy` and `bevy-website` checkouts for new caches, or updates existing checkouts
- builds local rustdoc for the current stable Bevy release
- removes temporary Cargo build artifacts after rustdoc is copied

## .NET 9 SDK

Default Godot generation uses C#/.NET. Godot 4.5+ C# projects require .NET 9. GDScript-only projects do not need the .NET SDK.

### Linux (Ubuntu/Debian)

```bash
wget -q https://dot.net/v1/dotnet-install.sh -O /tmp/dotnet-install.sh
chmod +x /tmp/dotnet-install.sh
/tmp/dotnet-install.sh --channel 9.0 --install-dir ~/.dotnet
```

Add to `~/.bashrc`:

```bash
export PATH="$HOME/.dotnet:$PATH"
export DOTNET_ROOT="$HOME/.dotnet"
```

### macOS

```bash
brew install dotnet@9
```

## Rust

Bevy projects require a current Rust toolchain:

```bash
rustup update stable
cargo --version
rustc --version
```

## System Packages

```bash
sudo apt-get install vulkan-tools xvfb ffmpeg imagemagick
```

- **vulkan-tools** — `vulkaninfo` for GPU validation
- **xvfb** — virtual X11 display for headless Godot/Bevy smoke tests
- **ffmpeg** — MP4 encoding and `ffprobe` for hook validation
- **imagemagick** — image resize, flip, crop for sprite pipelines

On macOS:

```bash
brew install coreutils ffmpeg dotnet@9
```

## Python

Requires Python 3.10+.

```bash
python3 --version
pip install -r shared/skills/godogen/tools/requirements.txt
```

In a published game repo, the same requirements file lives at `.agents/skills/godogen/tools/requirements.txt`.

## Godot

The **.NET edition** is required for default C# Godot projects. GDScript-only projects can use the standard Godot build.

### Linux

```bash
VERSION=$(curl -s https://api.github.com/repos/godotengine/godot/releases/latest | grep -oP '"tag_name": "\K[^"]+' | sed 's/-stable//')
echo "Installing Godot .NET $VERSION"
cd /tmp
wget https://github.com/godotengine/godot/releases/download/${VERSION}-stable/Godot_v${VERSION}-stable_mono_linux_x86_64.zip
unzip Godot_v${VERSION}-stable_mono_linux_x86_64.zip
sudo mv Godot_v${VERSION}-stable_mono_linux_x86_64/Godot_v${VERSION}-stable_mono_linux.x86_64 /usr/local/bin/godot
sudo mv Godot_v${VERSION}-stable_mono_linux_x86_64/GodotSharp /usr/local/bin/GodotSharp
```

`GodotSharp/` must live next to the `godot` binary. Godot resolves it relative to itself.

### macOS

```bash
brew install --cask godot-mono
sudo ln -sf /Applications/Godot_mono.app/Contents/MacOS/Godot /usr/local/bin/godot
```

### Verify

```bash
dotnet --version                 # 9.0.x
godot --version                  # 4.x.x.stable.mono
godot --headless --quit          # may show harmless RID warnings
```

If `godot --headless --quit` crashes with assembly errors, check that `GodotSharp/` is next to the binary:

```bash
ls "$(dirname "$(which godot)")"/GodotSharp/
```

## Godot Android Export

Godot Android export is only needed when a Godot runtime task asks for an APK.

### OpenJDK 17

```bash
sudo apt-get install -y openjdk-17-jdk
```

### Android SDK

Download command-line tools from https://developer.android.com/studio#command-line-tools-only and install:

```bash
sudo mkdir -p /opt/android-sdk/cmdline-tools
cd /tmp && wget -q https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -O cmdline-tools.zip
sudo unzip -o cmdline-tools.zip -d /opt/android-sdk/cmdline-tools/
sudo mv /opt/android-sdk/cmdline-tools/cmdline-tools /opt/android-sdk/cmdline-tools/latest
```

Install required SDK components:

```bash
sudo /opt/android-sdk/cmdline-tools/latest/bin/sdkmanager --sdk_root=/opt/android-sdk \
  "platform-tools" "build-tools;35.0.1" "platforms;android-35" \
  "cmake;3.10.2.4988404" "ndk;28.1.13356709"
```

### Export Templates

```bash
VERSION=$(godot --version | cut -d. -f1-3)
TEMPLATE_DIR=~/.local/share/godot/export_templates/${VERSION}.stable
mkdir -p "$TEMPLATE_DIR"
cd /tmp
wget -q "https://github.com/godotengine/godot/releases/download/${VERSION}-stable/Godot_v${VERSION}-stable_export_templates.tpz" -O export_templates.tpz
unzip -o export_templates.tpz -d /tmp/tpz_extract
mv /tmp/tpz_extract/templates/* "$TEMPLATE_DIR/"
```

### Debug Keystore

```bash
mkdir -p ~/.local/share/godot/keystores
keytool -genkey -v -keystore ~/.local/share/godot/keystores/debug.keystore \
  -alias androiddebugkey -keyalg RSA -keysize 2048 -validity 10000 \
  -storepass android -keypass android \
  -dname "CN=Android Debug,O=Android,C=US"
```

### Godot Editor Settings

Run `godot --headless --quit` once in any project to generate the settings file, then set Android paths in `~/.config/godot/editor_settings-4.5.tres`:

```ini
export/android/debug_keystore = "/home/<user>/.local/share/godot/keystores/debug.keystore"
export/android/debug_keystore_user = "androiddebugkey"
export/android/debug_keystore_pass = "android"
export/android/java_sdk_path = "/usr/lib/jvm/java-17-openjdk-amd64"
export/android/android_sdk_path = "/opt/android-sdk"
```

## API Keys

Set in environment:

- `MESHY_API_KEY` — [Meshy AI](https://www.meshy.ai/) for image and 3D generation

Get your key from https://www.meshy.ai/settings/api (requires Pro plan or above).

## Post-Task Telegram Push (optional)

Published repos install a `Stop` hook that pushes the latest `screenshots/result/{N}/video.mp4` to Telegram. The hook is best-effort: it no-ops unless [tg-push](https://github.com/htdt/tg-push) is on `PATH` and both `TG_BOT_TOKEN` and `TG_CHAT_ID` are set.

```bash
pipx install tg-push
```

Set `TG_BOT_TOKEN` and `TG_CHAT_ID` in the environment.

## Verify Rendering

```bash
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/nvidia_icd.json vulkaninfo --summary 2>&1 | grep "deviceName"
xvfb-run -a godot --headless --quit
```
