"""Prepare PP-OCRv6_small_rec for the app.

1. Reads the PaddleOCR character dict out of inference.yml.
2. Prunes the classifier head to `blank + 0-9 A-Z a-z space` so the model
   cannot emit anything else (18,710 -> 64 classes, ~9 MB smaller, and the
   per-frame decode stops being a 750k-element marshalling problem).
3. Writes `ppocr_v6_small_rec.onnx` + `ppocr_v6_small_rec.json`.
4. Verifies the result on rendered text with onnxruntime.

Usage: python tools/prepare_ppocr_model.py [dir with inference.onnx + inference.yml]
Get those from https://huggingface.co/PaddlePaddle/PP-OCRv6_small_rec_onnx
"""

import json
import sys
from pathlib import Path

import numpy as np
import onnx
import yaml
from onnx import numpy_helper
from PIL import Image, ImageDraw, ImageFont

WORK = Path(sys.argv[1] if len(sys.argv) > 1 else r"C:\Users\Admin\AppData\Local\Temp\opencode\ppocr")
OUT_DIR = Path(r"C:\Users\Adminator\Documents\SeeRuta\teammate\assets\models")
NAME = "ppocr_v6_small_rec"

LINE_HEIGHT = 48
MAX_WIDTH = 320

with open(WORK / "inference.yml", encoding="utf-8") as f:
    cfg = yaml.safe_load(f)
character_dict = cfg["PostProcess"]["character_dict"]

# PaddleOCR's CTCLabelDecode: blank first, then the dict, then space.
full = [None] + list(character_dict) + [" "]

model = onnx.load(str(WORK / "inference.onnx"))

# Find the classifier weight: the initializer whose last axis is the class count.
classes = None
head = None
for init in model.graph.initializer:
    if init.dims and init.dims[-1] == len(full):
        classes = init.dims[-1]
        head = init
        break
if head is None:
    sys.exit(f"no initializer with last dim {len(full)}")
print(f"classifier: {head.name} {list(head.dims)} -> {classes} classes")

keep = set("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz ")
missing = [c for c in keep if c not in full]
print("missing from dict:", missing if missing else "none")

indices = [i for i, c in enumerate(full) if c is None or c in keep]
new_vocab = ["" if full[i] is None else full[i] for i in indices]
print(f"pruned vocab: {len(indices)} classes ({len(new_vocab) - 2} characters)")

w = numpy_helper.to_array(head)
print("head shape:", w.shape, "axis to slice:", 1 if w.ndim == 2 else 0)
new_w = np.take(w, indices, axis=1) if w.ndim == 2 else np.take(w, indices, axis=0)

# Replace the initializer in place (same name, so the graph stays wired).
for i, init in enumerate(model.graph.initializer):
    if init.name == head.name:
        model.graph.initializer[i].CopyFrom(
            numpy_helper.from_array(new_w.astype(np.float32), head.name)
        )
        break

# Slice a matching bias if the head has one.
for init in list(model.graph.initializer):
    if init.name != head.name and init.dims == [classes]:
        b = numpy_helper.to_array(init)
        for i, other in enumerate(model.graph.initializer):
            if other.name == init.name:
                model.graph.initializer[i].CopyFrom(
                    numpy_helper.from_array(b[indices].astype(np.float32), init.name)
                )
                break
        print("biased head sliced:", init.name)

# Declare the new output width so shape inference stays honest.
onnx.checker.check_model(model)
OUT_DIR.mkdir(parents=True, exist_ok=True)
onnx.save(model, str(OUT_DIR / f"{NAME}.onnx"))
print("wrote", OUT_DIR / f"{NAME}.onnx", f"{(OUT_DIR / f'{NAME}.onnx').stat().st_size / 1e6:.2f} MB")

(OUT_DIR / f"{NAME}.json").write_text(
    json.dumps(
        {
            "vocab": new_vocab,
            "blank_index": 0,
            "input_shape": [3, LINE_HEIGHT, MAX_WIDTH],
            "note": (
                "PP-OCRv6 small recognition head pruned to alphanumerics + space. "
                "Regenerate with tools/prepare_ppocr_model.py."
            ),
        },
        ensure_ascii=False,
    ),
    encoding="utf-8",
)
print("wrote", OUT_DIR / f"{NAME}.json")

# ---- verify with onnxruntime -------------------------------------------------
import onnxruntime as ort

sess = ort.InferenceSession(str(OUT_DIR / f"{NAME}.onnx"), providers=["CPUExecutionProvider"])
print("input:", [(i.name, i.shape) for i in sess.get_inputs()])
print("output:", [(o.name, o.shape) for o in sess.get_outputs()])


def render(text: str) -> np.ndarray:
    font = ImageFont.truetype(r"C:\Windows\Fonts\arialbd.ttf", 40)
    img = Image.new("RGB", (MAX_WIDTH, LINE_HEIGHT), (255, 255, 255))
    ImageDraw.Draw(img).text((6, 2), text, fill=(0, 0, 0), font=font)
    img.save(WORK / f"render_{text}.png")
    arr = np.asarray(img, dtype=np.float32)  # HWC, RGB
    bgr = arr[:, :, ::-1]  # PaddleOCR decodes with cv2 -> BGR
    chw = bgr.transpose(2, 0, 1) / 255.0
    chw = (chw - 0.5) / 0.5
    # Pad to the model width with black pixels, i.e. -1 after normalisation.
    padded = np.full((3, LINE_HEIGHT, MAX_WIDTH), -1.0, dtype=np.float32)
    padded[:, :, : chw.shape[2]] = chw
    return padded[None, ...]


def decode(logits: np.ndarray) -> tuple[str, float]:
    seq = logits[0]  # [T, C]
    if seq.shape[-1] != len(new_vocab):
        # Some exports transpose it.
        seq = seq.T
    out, probs, prev = [], [], -1
    for step in seq:
        i = int(np.argmax(step))
        if i != prev and i != 0:
            out.append(new_vocab[i])
            e = np.exp(step - step.max())
            probs.append(float(e[i] / e.sum()))
        prev = i
    return "".join(out).strip(), (sum(probs) / len(probs) if probs else 0.0)


for text in ["17B", "APAS", "CARBON", "04I", "22I", "GAISANO"]:
    logits = sess.run(None, {sess.get_inputs()[0].name: render(text)})[0]
    got, conf = decode(logits)
    print(f"  {text:8s} -> {got!r:12s} conf={conf:.3f}  {'OK' if got.upper() == text else 'MISS'}")
