# Screenshot Response Agent

This PowerShell CLI watches the parent `Screenshots` directory for new image files, sends each image to Gemini for analysis, prints the response, and saves a Markdown copy in `responses`.

## Setup

1. Create a Gemini API key in [Google AI Studio](https://aistudio.google.com/app/apikey).
2. Open `config.json` and replace the placeholder value:

   ```json
   "gemini_api_key": "your-gemini-api-key"
   ```

3. Adjust any other settings in `config.json` if needed:

   - `model`: Gemini model to use.
   - `screenshot_folder`: Image folder relative to this project; `..` means the parent `Screenshots` folder.
   - `response_folder`: Where Markdown responses are saved.
   - `poll_milliseconds`: Delay between folder checks.

No Python installation or package installation is required.

## Run

Double-click `start-watcher.cmd`, or run it from a terminal:

```cmd
start-watcher.cmd
```

The watcher prints each answer in the command line. Press `Ctrl+C` to stop it. New screenshots should be placed directly in the configured screenshot folder.

## Output

For a screenshot named `Screenshot 2026-11-10 125326.png`, the response is saved as:

```text
responses\Screenshot 2026-11-10 125326.response.md
```

Supported image formats are PNG, JPG/JPEG, WEBP, and GIF.

## Troubleshooting

- `GEMINI_API_KEY` or configuration error: confirm `gemini_api_key` is filled in and restart the watcher.
- `404 Not Found`: check that the configured model is available to your Gemini project.
- `429 Too Many Requests` or `503 Unavailable`: wait and try again; the API may be rate-limited or busy.
- No response: confirm the screenshot is in the configured folder and leave the watcher window open.

## Security

Treat `config.json` as secret because it contains the API key. Do not upload, commit, or share it. Rotate the key immediately if it is exposed.
