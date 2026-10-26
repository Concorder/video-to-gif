# ClipText web studio

Upload a video, crop to vertical (9:16), square, or landscape, reposition the crop, add a caption, choose a clip of up to 30 seconds, and export MP4 with audio or animated GIF. Mobile responsive vanilla web frontend, Node/Express server, FFmpeg media processing, and yt-dlp social imports. The earlier SwiftUI prototype is retained under App/.

## Run

Requires Node 22+, Python 3, FFmpeg (including ffprobe, libx264 and drawtext), and DejaVu Sans Bold at `/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf`.

```sh
npm ci --cache /workspace/.npm-cache
python -m venv /workspace/cliptext-tools
/workspace/cliptext-tools/bin/pip install yt-dlp==2026.10.21
YT_DLP=/workspace/cliptext-tools/bin/yt-dlp npm start
```

Server defaults to port 3000; PORT overrides it. Run `npm test` while the server is running for an upload and real MP4/GIF export integration check.

## Social links

Paste a public YouTube or TikTok HTTPS link. The backend runs yt-dlp and downloads up to 250 MB / 10 minutes. No cookies, login bypass or credentials are included. Platforms may reject requests or require authentication. This cloud environment currently denies YouTube network requests (proxy HTTP 403), so social imports have not been validated successfully. TikTok retrieval is also unverified. Configure network access to platform and media CDN domains before relying on link imports; domains vary by video. Local uploads and exports work independently.

## Validation and limits

Real synthetic video uploads and square captioned MP4/GIF exports passed; ffprobe confirmed dimensions, codecs, retained MP4 audio, and multiple GIF frames. JavaScript syntax checks passed. Browser validation passed using installed Chromium: upload, caption editing, square format selection, and export/download readiness. Desktop and mobile screenshots were captured.

This is a local development prototype. Before public hosting add authentication, rate limits, job concurrency limits, isolated downloader workers, and complete temporary-file cleanup. Uploaded clip IDs are bearer access links; files expire after one hour, exports are removed after download, and server restart forgets clip IDs. No persistent projects. Caption uses a single bottom position; preview is approximate. GIF export uses 10 fps at 480px width. Video uploads are limited to 250 MB and ten minutes. Photos import on iOS belongs to the separate native prototype; web uses the browser file picker.

## GitHub Pages

In repository Settings → Pages, choose **GitHub Actions** as the source. The Pages workflow publishes `public/` on pushes to main. Assets use relative paths to support the `/video-to-gif/` project URL. Pages alone supports local video preview, captions, crop format and positioning. It cannot run Node, FFmpeg or yt-dlp.

For export and social imports, run the Node server on a separate HTTPS host, then enter its URL under **Connect processing server** in the editor. The backend permits `https://concorder.github.io` by default; set comma-separated `ALLOWED_ORIGINS` for other frontend origins. After connecting, select the video again to upload it. Browser storage retains the server URL. Deploy the processing server only after addressing the public-hosting requirements above.

Verified in Chromium against a static server mounted at `/video-to-gif/`: asset loading, local video preview, captions, square crop selection, and disabled export without a backend. Server mode upload and export are also checked separately.
