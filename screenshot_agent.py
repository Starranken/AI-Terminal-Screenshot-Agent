"""Watch a folder for new screenshots and answer the latest one with OpenAI vision."""

from __future__ import annotations

import argparse
import base64
import mimetypes
import os
import time
from pathlib import Path

from openai import OpenAI


IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp", ".gif"}
DEFAULT_PROMPT = (
    "Read the screenshot carefully. If it contains a question or task, answer it "
    "directly and concisely. If it contains code or an error, explain the likely "
    "fix. If no response is needed, briefly describe what is shown."
)


def newest_image(folder: Path) -> Path | None:
    images = [
        path
        for path in folder.iterdir()
        if path.is_file() and path.suffix.lower() in IMAGE_EXTENSIONS
    ]
    return max(images, key=lambda path: path.stat().st_mtime, default=None)


def is_stable(path: Path, seconds: float) -> bool:
    first_size = path.stat().st_size
    time.sleep(seconds)
    return path.exists() and path.stat().st_size == first_size


def answer_image(client: OpenAI, path: Path, prompt: str, model: str) -> str:
    mime = mimetypes.guess_type(path.name)[0] or "application/octet-stream"
    encoded = base64.b64encode(path.read_bytes()).decode("ascii")
    response = client.responses.create(
        model=model,
        input=[
            {
                "role": "user",
                "content": [
                    {"type": "input_text", "text": prompt},
                    {
                        "type": "input_image",
                        "image_url": f"data:{mime};base64,{encoded}",
                        "detail": "auto",
                    },
                ],
            }
        ],
    )
    return response.output_text.strip()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--folder", type=Path, default=Path(__file__).parent)
    parser.add_argument("--prompt", default=os.getenv("SCREENSHOT_PROMPT", DEFAULT_PROMPT))
    parser.add_argument("--model", default=os.getenv("OPENAI_MODEL", "gpt-5.5"))
    parser.add_argument("--poll-seconds", type=float, default=2.0)
    parser.add_argument("--stable-seconds", type=float, default=1.0)
    parser.add_argument(
        "--process-existing",
        action="store_true",
        help="answer the current newest screenshot immediately on startup",
    )
    args = parser.parse_args()

    if not os.getenv("OPENAI_API_KEY"):
        raise SystemExit("Set OPENAI_API_KEY before starting the agent.")
    folder = args.folder.expanduser().resolve()
    if not folder.is_dir():
        raise SystemExit(f"Folder does not exist: {folder}")

    client = OpenAI()
    last_processed: tuple[str, int, int] | None = None
    if not args.process_existing:
        current = newest_image(folder)
        if current:
            stat = current.stat()
            last_processed = (str(current), stat.st_mtime_ns, stat.st_size)

    print(f"Watching {folder} for new screenshots. Press Ctrl+C to stop.")
    while True:
        try:
            image = newest_image(folder)
            if image:
                stat = image.stat()
                identity = (str(image), stat.st_mtime_ns, stat.st_size)
                if identity != last_processed and is_stable(image, args.stable_seconds):
                    print(f"Analyzing {image.name}...")
                    try:
                        answer = answer_image(client, image, args.prompt, args.model)
                        output = image.with_name(f"{image.stem}.response.md")
                        output.write_text(
                            f"# Response to `{image.name}`\n\n{answer}\n",
                            encoding="utf-8",
                        )
                        print(f"Wrote {output.name}")
                        last_processed = identity
                    except Exception as exc:
                        print(f"Analysis failed: {exc}")
                        last_processed = None
            time.sleep(args.poll_seconds)
        except KeyboardInterrupt:
            print("\nStopped.")
            return
        except (FileNotFoundError, OSError) as exc:
            print(f"Waiting for the folder to settle: {exc}")
            time.sleep(args.poll_seconds)


if __name__ == "__main__":
    main()
