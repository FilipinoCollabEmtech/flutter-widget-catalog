# SeeRuta patch to whisper_ggml 2.10.0

This is a vendored copy of `whisper_ggml` 2.10.0 from pub.dev, with one
native change in `android/src/whisper/main.cpp` (`stream_run_inference`).

The app uses it through the `dependency_overrides` entry in the root
`pubspec.yaml`. CI therefore builds the patched native code without any
pub-cache editing.

## What changed

1. **Clip-sized encoder window.** whisper.cpp always pads the mel
   spectrogram to 30 seconds and, by default, runs the encoder over 1500
   audio-context positions. The patch sets `whisper_full_params.audio_ctx`
   from the actual clip length (`100` mel frames/s, two mel frames per
   encoder position), rounded up to 64 positions and clamped to 128..1500.
   A normal 5 s command uses 256 positions instead of 1500, removing most of
   the fixed encoder cost on a low-end phone.
2. **One decoder pass.** `greedy.best_of` is set to 1 and
   `temperature_inc` to 0, disabling the temperature-fallback retries. The
   initial prompt already biases the closed command vocabulary, and the
   retries made the same command take wildly different times on noisy audio.
   `no_timestamps` is enabled because the app only needs text; whisper.cpp
   then forces `seek_delta` to a full chunk after the last token, which also
   prevents a second encoder pass over trailing silence.

## Updating the package

When replacing this copy with a newer `whisper_ggml`, re-apply both settings
inside `stream_run_inference` after `n_decode` is known and before
`whisper_full()` is called. Keep `audio_ctx` at least large enough to cover
the whole clip: the encoder sees `2 * audio_ctx` mel frames.

Only the shared `android/src/whisper/main.cpp` is patched. Linux and Windows
also compile that file; the Apple builds use their own sources.
