# ScreenPut

A lightweight macOS menu bar app that automatically uploads your screenshots to **AWS S3** or **Azure Blob Storage** and copies the shareable URL to your clipboard. No browser, no manual uploading — just screenshot and share.

![macOS](https://img.shields.io/badge/macOS-14.0%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange)
![SwiftUI](https://img.shields.io/badge/SwiftUI-MenuBarExtra-purple)
![License](https://img.shields.io/badge/license-MIT-green)

![ScreenPut](https://github.com/user-attachments/assets/9f1de745-4f3a-43c4-817e-ad1b9cff30e4)

---

## How It Works

1. **Take a screenshot** (Cmd+Shift+3, Cmd+Shift+4, Cmd+Shift+5)
2. ScreenPut detects the new file instantly via native macOS file system events
3. The screenshot is uploaded to your configured cloud storage (S3 or Azure)
4. The public URL is **copied to your clipboard** automatically
5. A **system notification** confirms the upload
6. The screenshot appears in the **menu bar popover** with its URL and thumbnail

That's it. Screenshot, paste, done.

---

## Features

- **Menu bar app** — lives in your menu bar, no dock icon, no windows to manage
- **Instant detection** — uses macOS FSEvents (no polling) to detect new screenshots the moment they appear
- **AWS S3 support** — uploads directly using AWS Signature V4 authentication
- **Azure Blob Storage support** — uploads using SAS token authentication
- **Auto clipboard** — the shareable URL is copied to your clipboard immediately after upload
- **System notifications** — get notified when uploads succeed or fail
- **Recent screenshots** — click the menu bar icon to see your upload history with thumbnails
- **Re-copy URLs** — click any previous screenshot to copy its URL again
- **Image resizing** — optionally downscale images before upload to save bandwidth
- **Auto-delete originals** — optionally remove the local file after successful upload
- **Launch at login** — start ScreenPut automatically when you log in
- **Keychain storage** — AWS secret keys and Azure SAS tokens are stored securely in the macOS Keychain
- **Zero dependencies** — built entirely with Apple frameworks (SwiftUI, CryptoKit, Foundation, AppKit)
- **Persistent history** — your upload history survives app restarts

---

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15.0 or later (to build from source)
- An AWS S3 bucket **or** Azure Blob Storage container

---

## Installation

### Build from Source

```bash
git clone https://github.com/YOUR_USERNAME/ScreenPut.git
cd ScreenPut
open ScreenPut.xcodeproj
```

In Xcode:
1. Select the **ScreenPut** scheme
2. Press **Cmd+R** to build and run
3. The ScreenPut icon (camera viewfinder) appears in your menu bar

### Optional: Set Your Development Team

If you want to sign the app with your Apple Developer account, open the project settings in Xcode and set your **Team** under **Signing & Capabilities**.

---

## Setup

### 1. Configure Screenshot Location

On first launch, ScreenPut automatically:
- Creates `~/Documents/Screenshots/` if it doesn't exist
- Sets macOS to save all screenshots to that folder via `defaults write com.apple.screencapture location`

You can verify this worked by taking a screenshot — it should appear in `~/Documents/Screenshots/` instead of the Desktop.

### 2. Configure Cloud Storage

Click the ScreenPut icon in the menu bar, then click **Settings**.

#### Option A: AWS S3

1. **Create an S3 bucket** (if you don't have one):
   ```bash
   aws s3 mb s3://my-screenshots-bucket --region us-east-1
   ```

2. **Set the bucket policy** to allow public read access (so URLs are shareable):
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Sid": "PublicReadGetObject",
         "Effect": "Allow",
         "Principal": "*",
         "Action": "s3:GetObject",
         "Resource": "arn:aws:s3:::my-screenshots-bucket/*"
       }
     ]
   }
   ```

3. **Create an IAM user** with `s3:PutObject` permission on your bucket, and generate an access key.

4. In ScreenPut Settings, fill in:
   | Field | Example |
   |-------|---------|
   | Bucket | `my-screenshots-bucket` |
   | Region | `us-east-1` |
   | Access Key ID | `AKIAIOSFODNN7EXAMPLE` |
   | Secret Access Key | `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY` |
   | Path Prefix | `screenshots/` |

Your uploaded screenshots will be accessible at:
```
https://my-screenshots-bucket.s3.us-east-1.amazonaws.com/screenshots/2026/04/02/A1B2C3D4.png
```

#### Option B: Azure Blob Storage

1. **Create a Storage Account and Container** in the Azure Portal.

2. **Enable public access** on the container (set access level to "Blob" for public read).

3. **Generate a SAS token** for the container:
   - Go to your container → **Shared access tokens**
   - Set permissions to **Write** and **Create**
   - Set an expiry date
   - Click **Generate SAS token and URL**
   - Copy the **SAS token** (the part after the `?`)

4. In ScreenPut Settings, fill in:
   | Field | Example |
   |-------|---------|
   | Account Name | `mystorageaccount` |
   | Container Name | `screenshots` |
   | SAS Token | `sv=2024-11-04&ss=b&srt=o&sp=wc&se=2027-01-01...` |

Your uploaded screenshots will be accessible at:
```
https://mystorageaccount.blob.core.windows.net/screenshots/screenshots/2026/04/02/A1B2C3D4.png
```

---

## Usage

### Taking Screenshots

Just use macOS screenshot shortcuts as usual:

| Shortcut | Action |
|----------|--------|
| Cmd+Shift+3 | Capture entire screen |
| Cmd+Shift+4 | Capture selected area |
| Cmd+Shift+4+Space | Capture a window |
| Cmd+Shift+5 | Screenshot toolbar (includes screen recording) |

ScreenPut detects the new file and handles everything automatically.

### Menu Bar Popover

Click the camera icon in the menu bar to see:

- **Upload status** — spinner when an upload is in progress
- **Error messages** — if an upload fails, the error is shown at the top
- **Recent screenshots** — thumbnails, URLs, file sizes, and relative timestamps
- **Copy button** — click the copy icon on any row to re-copy that URL
- **Settings** — open the configuration window
- **Upload count** — total number of successful uploads this session
- **Quit** — exit ScreenPut

### Settings

Open Settings from the menu bar popover:

**Storage tab:**
- Switch between AWS S3 and Azure Blob Storage
- Configure credentials for your chosen provider
- Status indicator shows whether configuration is complete

**General tab:**
- **Delete original after upload** — remove the local screenshot file after successful upload
- **Resize images before upload** — downscale images to reduce file size (default: 80%)
- **Scale slider** — adjust the resize percentage (25%–100%)
- **Launch at Login** — start ScreenPut when you log in
- **Apply Screenshot Location** — re-apply the `~/Documents/Screenshots` setting if it was reset

---

## Project Structure

```
ScreenPut/
├── ScreenPut.xcodeproj
├── ScreenPut/
│   ├── App/
│   │   ├── ScreenPutApp.swift              # App entry point, MenuBarExtra scene
│   │   └── Info.plist                      # LSUIElement=true (menu bar only)
│   ├── Models/
│   │   ├── ScreenshotRecord.swift          # Data model for uploaded screenshots
│   │   └── StorageConfig.swift             # S3Config, AzureConfig, StorageProvider
│   ├── Services/
│   │   ├── StorageUploader.swift           # Upload protocol + error types
│   │   ├── S3Uploader.swift                # AWS S3 with Signature V4 (CryptoKit)
│   │   ├── AzureBlobUploader.swift         # Azure Blob Storage with SAS tokens
│   │   ├── FolderWatcher.swift             # FSEvents directory monitor
│   │   ├── ClipboardManager.swift          # NSPasteboard wrapper
│   │   ├── NotificationManager.swift       # UNUserNotificationCenter wrapper
│   │   └── ScreenshotLocationManager.swift # macOS screenshot location config
│   ├── ViewModels/
│   │   └── AppViewModel.swift              # Central state, upload pipeline, Keychain
│   ├── Views/
│   │   ├── MenuBarPopover.swift            # Main popover UI
│   │   ├── ScreenshotRow.swift             # Screenshot list row with thumbnail
│   │   └── SettingsView.swift              # Storage + General settings tabs
│   ├── Assets.xcassets/                    # App icon
│   └── ScreenPut.entitlements              # Network client entitlement
└── README.md
```

---

## Architecture

### Overview

ScreenPut is a pure SwiftUI menu bar app with no external dependencies. It uses the `MenuBarExtra` API (macOS 13+) with the `.window` style to display a full popover with thumbnails.

### Key Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Menu bar | `MenuBarExtra` + `.window` style | Full SwiftUI views with thumbnails, not just plain menus |
| S3 auth | Raw AWS Signature V4 with `CryptoKit` | Zero dependencies — only one S3 operation needed (`PutObject`) |
| Azure auth | SAS token appended to URL | Simplest approach, no signing code needed |
| File watching | `DispatchSource` (FSEvents) | Event-driven, efficient, no polling |
| State management | `@Observable` (Observation framework) | Modern SwiftUI, less boilerplate |
| Concurrency | `async/await` | Clean sequential pipeline, no Combine needed |
| Secret storage | macOS Keychain (`Security.framework`) | Secure — never stored in UserDefaults or plaintext |
| Image resize | `NSImage` / `NSBitmapImageRep` | Built into AppKit, no third-party image library |
| No Dock icon | `LSUIElement = true` in Info.plist | Menu bar apps shouldn't clutter the Dock |
| Launch at login | `SMAppService` | Modern API, replaces legacy LaunchAgent plists |

### Upload Pipeline

```
DispatchSource detects new file in ~/Documents/Screenshots
    │
    ├── PNG/JPG: optional resize (NSImage, configurable scale)
    ├── MOV: wait for file to finish writing (size stability check)
    │
    ▼
Upload to S3 (Signature V4) or Azure (SAS token)
    │ retry up to 3x with exponential backoff
    │
    ▼
Copy public URL to clipboard (NSPasteboard)
    │
    ▼
Show system notification (UNUserNotificationCenter)
    │
    ▼
Optionally delete original file
    │
    ▼
Add to recent screenshots list (persisted to JSON)
```

### AWS Signature V4 Implementation

The S3 uploader implements AWS Signature V4 signing from scratch using only `CryptoKit`:

1. Constructs a canonical request (method, path, headers, payload hash)
2. Creates a string to sign (algorithm, timestamp, credential scope, request hash)
3. Derives a signing key via HMAC-SHA256 chain (secret → date → region → service → "aws4_request")
4. Computes the signature and adds the `Authorization` header

This is ~130 lines of Swift and avoids pulling in the full AWS SDK (~20 SPM packages) for a single `PUT` operation.

---

## Supported File Types

| Type | Extension | Behavior |
|------|-----------|----------|
| Screenshots | `.png` | Optionally resized, uploaded as `image/png` |
| JPEG screenshots | `.jpg`, `.jpeg` | Optionally resized, uploaded as `image/jpeg` |
| Screen recordings | `.mov` | Waits for recording to finish, uploaded as `video/quicktime` |
| Converted video | `.mp4` | Uploaded as `video/mp4` |

---

## Configuration Reference

### UserDefaults Keys

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `storageProvider` | String | `"AWS S3"` | Active storage backend |
| `s3Config` | Data (JSON) | Empty config | S3 bucket, region, access key ID, path prefix |
| `azureConfig` | Data (JSON) | Empty config | Azure account name, container name |
| `deleteAfterUpload` | Bool | `false` | Remove local file after upload |
| `resizeImages` | Bool | `true` | Downscale images before upload |
| `resizeScale` | Double | `0.8` | Resize scale factor (0.25–1.0) |

### Keychain Items

| Key | Description |
|-----|-------------|
| `s3SecretAccessKey` | AWS S3 secret access key |
| `azureSasToken` | Azure Blob Storage SAS token |

All Keychain items are stored under the service name `com.screenput.app`.

---

## Troubleshooting

### Screenshots aren't being detected

1. Verify the screenshot location is set correctly:
   ```bash
   defaults read com.apple.screencapture location
   ```
   Should output: `/Users/yourname/Documents/Screenshots`

2. If not, click **Settings → General → Apply Screenshot Location** in ScreenPut.

3. Make sure the folder exists:
   ```bash
   ls ~/Documents/Screenshots
   ```

### Upload fails with "not configured"

Open Settings and make sure all required fields are filled in. The status indicator at the bottom of each provider section shows whether the configuration is complete.

### Upload fails with HTTP 403

- **S3**: Check that your IAM user has `s3:PutObject` permission on the bucket. Verify the access key ID and secret are correct.
- **Azure**: Your SAS token may have expired. Generate a new one in the Azure Portal.

### URLs aren't publicly accessible

- **S3**: Make sure the bucket policy allows `s3:GetObject` for `"Principal": "*"`. Also check that "Block Public Access" settings on the bucket allow public policies.
- **Azure**: Set the container's access level to "Blob (anonymous read access for blobs only)".

### App doesn't appear in menu bar

Check that `LSUIElement` is set to `true` in `Info.plist`. The app won't show in the Dock, only in the menu bar (look for the camera viewfinder icon).

### "DetachedSignatures" error in console

```
cannot open file at line 49455 of [1b37c146ee]
os_unix.c:49455: (2) open(/private/var/db/DetachedSignatures) - No such file or directory
```

This is a harmless macOS system message related to code signing verification during development. It does not affect the app's functionality. It goes away when the app is properly signed for distribution.

---

## Building for Distribution

To create a distributable `.app` bundle:

```bash
xcodebuild -project ScreenPut.xcodeproj \
  -scheme ScreenPut \
  -configuration Release \
  -archivePath ./build/ScreenPut.xcarchive \
  archive

xcodebuild -exportArchive \
  -archivePath ./build/ScreenPut.xcarchive \
  -exportPath ./build/release \
  -exportOptionsPlist ExportOptions.plist
```

Or in Xcode: **Product → Archive**, then **Distribute App**.

---

## Contributing

Contributions are welcome! Some ideas for future improvements:

- **Cloudflare R2 support** — S3-compatible, just needs a configurable endpoint URL
- **Custom domain** — use a CloudFront or Azure CDN domain for shorter URLs
- **Drag and drop** — upload any file by dragging it onto the menu bar icon
- **Keyboard shortcut** — global hotkey to open the popover
- **Image annotation** — quick markup before upload
- **Multiple storage backends** — upload to several providers simultaneously
- **URL shortening** — integrate with a link shortener
- **Shareable link format options** — Markdown, HTML, BBCode

---

## License

MIT License. See [LICENSE](LICENSE) for details.

