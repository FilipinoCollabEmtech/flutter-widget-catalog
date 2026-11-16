#!/usr/bin/env python3
"""
Auto-refresh monitor for m3u8/mp4 video links on omeglevids
Checks every 0.2 seconds for stream links
"""

import urllib.request
import re
import time
import os
import sys
import winsound
import tempfile

# --- CONFIGURATION ---
# Your target URL (returns 404 until video goes live)
URL = "https://omeglevids.com/video/premium-obj05-girl-from-omegle-has-sex-on-discord-call/"
# To monitor a different video, change the line above

_TMP = tempfile.gettempdir()
LOG_FILE = os.path.join(_TMP, "omegle_m3u8_monitor.log")
FOUND_FILE = os.path.join(_TMP, "omegle_m3u8_found.txt")
TEMP_HTML = os.path.join(_TMP, "omegle_fetch_temp.html")

USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

running = True


def write_log(msg):
    timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
    line = f"{timestamp} | {msg}"
    print(line, flush=True)
    with open(LOG_FILE, "a", encoding="utf-8") as f:
        f.write(line + "\n")


def find_video_links(html):
    """Extract all video stream links from HTML"""
    links = set()

    if not html:
        return links

    # Match m3u8 URLs
    for m in re.finditer(r'https?://[^"\s<>]+\.m3u8[^"\s<>]*', html):
        links.add(m.group())

    # Match MP4 video URLs
    for m in re.finditer(r'https?://[^"\s<>]+\.mp4[^"\s<>]*', html):
        links.add(m.group())

    # Match quoted m3u8 paths
    for m in re.finditer(r'"([^"]*\.m3u8[^"]*)"', html):
        if m.group(1):
            links.add(m.group(1))

    # Match single-quoted m3u8 paths
    for m in re.finditer(r"'([^']*\.m3u8[^']*)'", html):
        if m.group(1):
            links.add(m.group(1))

    # Match b-cdn.net media delivery URLs
    for m in re.finditer(r'https?://[^"\s<>]*b-cdn\.net[^"\s<>]*', html):
        links.add(m.group())

    # Match mediadelivery.net embed URLs
    for m in re.finditer(r'https?://[^"\s<>]*mediadelivery\.net[^"\s<>]*', html):
        links.add(m.group())

    # Match src/source/file/href attributes pointing to video
    for m in re.finditer(r'(?:src|source|file|href|embedURL)\s*[:=]\s*["\']([^"\']+)["\']', html):
        val = m.group(1)
        if any(ext in val.lower() for ext in ['.m3u8', '.mp4', '.mpd', 'b-cdn', 'mediadelivery']):
            links.add(val)

    return links


def fetch_page():
    """Fetch the page HTML"""
    try:
        req = urllib.request.Request(URL, headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(req, timeout=10) as resp:
            html = resp.read().decode("utf-8", errors="ignore")
        return html
    except Exception as e:
        write_log(f"Fetch error: {e}")
        return None


def check_page():
    """Check page for video links"""
    html = fetch_page()
    if html is None:
        return False

    # Check for 404
    if re.search(r"Page Not Found|404|error-404|not-found", html, re.IGNORECASE):
        write_log("Page returned 404 - video not available yet")
        return False

    # Search for video links
    links = find_video_links(html)

    if links:
        write_log(f"FOUND link(s): {', '.join(links)}")
        with open(FOUND_FILE, "w", encoding="utf-8") as f:
            for link in sorted(links):
                f.write(link + "\n")
        return True

    write_log("Page loaded but no video links found")
    return False


def main():
    global running
    write_log("=== Starting m3u8/mp4 monitor (0.2s interval) ===")
    write_log(f"Target URL: {URL}")

    check_count = 0

    try:
        while running:
            check_count += 1
            print(f"Check #{check_count}", flush=True)

            if check_page():
                write_log(f"=== Link found! Check {FOUND_FILE} for details ===")
                winsound.Beep(800, 500)
                time.sleep(0.5)
                winsound.Beep(800, 500)

            time.sleep(0.2)

    except KeyboardInterrupt:
        write_log("Stopped by user")
        running = False


if __name__ == "__main__":
    main()
