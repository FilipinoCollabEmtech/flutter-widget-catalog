#!/usr/bin/env python3
"""
Async stress-test client for a Google Apps Script /exec endpoint.

Mirrors the batch script's two request shapes:

    A: POST  body = "{not valid json"   (invalid JSON)
    B: POST  body = ""                  (empty)

...but runs many requests in parallel and prints live stats:

    completed   total requests finished
    in-flight   coroutines currently awaiting a response
    rate        requests/sec since start
    A / B       per-shape counters
    errors      client-side exceptions (timeouts, resets, ...)
    statuses    HTTP code / exception breakdown

Usage:
    pip install aiohttp
    python stress.py
    python stress.py --endpoint URL --concurrency 200 --follow-redirects

Stop with Ctrl+C.
"""

import argparse
import asyncio
import shutil
import sys
import time
from collections import Counter

import aiohttp

DEFAULT_ENDPOINT = (
    "https://script.google.com/macros/s/"
    "AKfycbw7kD5_2SpTWj6aCAeGev9tEunM24rCXUGB1bP5A4dG4RwzzcT01sW9MW1y-DZvDSZqeQ/exec"
)

ENDPOINT = DEFAULT_ENDPOINT


# --------------------------------------------------------------------------- #
# Stats — all mutations happen on the event loop thread, so no locks needed.
# --------------------------------------------------------------------------- #
class Stats:
    __slots__ = ("completed", "in_flight", "by_shape", "by_status", "errors", "start")

    def __init__(self):
        self.completed = 0
        self.in_flight = 0
        self.by_shape = Counter()
        self.by_status = Counter()
        self.errors = 0
        self.start = time.monotonic()


STATS = Stats()


# --------------------------------------------------------------------------- #
# One request
# --------------------------------------------------------------------------- #
async def one_request(session: aiohttp.ClientSession, shape: str) -> None:
    STATS.in_flight += 1
    STATS.by_shape[shape] += 1
    try:
        body = "{not valid json" if shape == "A" else ""
        async with session.post(
            ENDPOINT,
            data=body,
            headers={"Content-Type": "application/json"},
        ) as resp:
            await resp.read()  # drain -> connection reuse; we discard like `-o nul`
            STATS.by_status[f"HTTP {resp.status}"] += 1
    except asyncio.CancelledError:
        raise
    except Exception as exc:
        STATS.errors += 1
        STATS.by_status[type(exc).__name__] += 1
    finally:
        STATS.in_flight -= 1
        STATS.completed += 1


# --------------------------------------------------------------------------- #
# Worker: loops forever, alternating shapes, gated by the semaphore
# --------------------------------------------------------------------------- #
async def worker(session: aiohttp.ClientSession, idx: int, sem: asyncio.Semaphore) -> None:
    shape = "A" if idx % 2 == 0 else "B"
    while True:
        async with sem:
            await one_request(session, shape)
        shape = "B" if shape == "A" else "A"


# --------------------------------------------------------------------------- #
# Live render loop
# --------------------------------------------------------------------------- #
def _format_statuses(by_status: Counter) -> str:
    return " ".join(f"{k}={v}" for k, v in by_status.most_common())


async def render_loop(refresh_hz: float) -> None:
    try:
        while True:
            await asyncio.sleep(1.0 / refresh_hz)
            elapsed = time.monotonic() - STATS.start
            rate = STATS.completed / elapsed if elapsed > 0 else 0.0
            line = (
                f"completed={STATS.completed:>7}  "
                f"in_flight={STATS.in_flight:>4}  "
                f"rate={rate:>7.1f}/s  "
                f"A={STATS.by_shape['A']:>7}  B={STATS.by_shape['B']:>7}  "
                f"errors={STATS.errors:>4}  "
                f"[{_format_statuses(STATS.by_status)}]"
            )
            width = shutil.get_terminal_size((120, 20)).columns
            if len(line) >= width:
                line = line[: width - 1] + "…"
            sys.stdout.write("\r" + line.ljust(width - 1))
            sys.stdout.flush()
    except asyncio.CancelledError:
        pass


# --------------------------------------------------------------------------- #
# Main
# --------------------------------------------------------------------------- #
async def main(args: argparse.Namespace) -> None:
    global ENDPOINT
    ENDPOINT = args.endpoint

    # limit=0 -> no aiohttp-level cap; the semaphore is the concurrency governor
    connector = aiohttp.TCPConnector(limit=0, ttl_dns_cache=300)
    timeout = aiohttp.ClientTimeout(total=args.timeout)
    sem = asyncio.Semaphore(args.concurrency)

    async with aiohttp.ClientSession(
        connector=connector,
        timeout=timeout,
        auto_decompress=False,
        trust_env=False,
    ) as session:
        # curl defaults to *not* following redirects; GAS /exec returns 302.
        if not args.follow_redirects:
            # aiohttp has no global "don't follow"; patch at request level
            original_post = session.post

            def post_no_redirect(*a, **kw):
                kw.setdefault("allow_redirects", False)
                return original_post(*a, **kw)

            session.post = post_no_redirect  # type: ignore[assignment]

        workers = [
            asyncio.create_task(worker(session, i, sem))
            for i in range(args.concurrency)
        ]
        render = asyncio.create_task(render_loop(args.refresh_hz))

        try:
            await asyncio.gather(*workers)
        except (asyncio.CancelledError, KeyboardInterrupt):
            pass
        finally:
            render.cancel()
            for w in workers:
                w.cancel()
            await asyncio.gather(render, *workers, return_exceptions=True)
            sys.stdout.write("\n")
            sys.stdout.flush()


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--endpoint", default=DEFAULT_ENDPOINT)
    p.add_argument("--concurrency", type=int, default=50,
                   help="max in-flight requests (semaphore size, default 50)")
    p.add_argument("--timeout", type=float, default=30.0,
                   help="per-request total timeout seconds (default 30)")
    p.add_argument("--refresh-hz", type=float, default=4.0,
                   help="stats refresh rate (default 4)")
    p.add_argument("--follow-redirects", action="store_true",
                   help="follow 3xx (default matches curl: no)")
    return p.parse_args()


if __name__ == "__main__":
    try:
        asyncio.run(main(parse_args()))
    except KeyboardInterrupt:
        sys.stdout.write("\nstopped\n")