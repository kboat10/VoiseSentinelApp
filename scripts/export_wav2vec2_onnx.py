#!/usr/bin/env python3
"""
Download facebook/wav2vec2-xls-r-300m from Hugging Face and export the encoder to ONNX.

The encoder output (last_hidden_state) gives the 1024-dim SSL features used in the
1092-dim ensemble input (ssl_0..ssl_1023). Run once, then copy the ONNX into the app:
  android/app/src/main/assets/models/onnx_models/wav2vec2_encoder.onnx

Requirements:
  pip install transformers torch huggingface_hub

Usage:
  python scripts/export_wav2vec2_onnx.py [--output DIR]
"""

import argparse
import os
import sys

HF_MODEL_ID = "facebook/wav2vec2-xls-r-300m"


def main():
    parser = argparse.ArgumentParser(description="Download Wav2Vec2 XLS-R 300M and export encoder to ONNX")
    parser.add_argument(
        "--output",
        "-o",
        default=os.path.join(os.path.dirname(__file__), "..", "onnx_export"),
        help="Output directory for ONNX and processor (default: ./onnx_export)",
    )
    args = parser.parse_args()

    try:
        from transformers import Wav2Vec2ForCTC
        import torch
    except ImportError:
        print(
            "Install: pip install transformers torch huggingface_hub",
            file=sys.stderr,
        )
        sys.exit(1)

    os.makedirs(args.output, exist_ok=True)
    out_path = os.path.abspath(args.output)

    print(f"Downloading {HF_MODEL_ID} from Hugging Face...")
    # Load model only (this repo has no vocab, so we skip Wav2Vec2Processor).
    model = Wav2Vec2ForCTC.from_pretrained(HF_MODEL_ID)
    # Optionally download preprocessor_config.json for 16 kHz etc.
    try:
        from huggingface_hub import hf_hub_download
        for name in ("config.json", "preprocessor_config.json"):
            hf_hub_download(HF_MODEL_ID, name, local_dir=out_path)
        print(f"Config saved to {out_path}")
    except Exception as e:
        print(f"Config download skipped: {e}")

    print("Exporting encoder to ONNX (last_hidden_state for SSL features)...")
    encoder = model.wav2vec2
    encoder.eval()

    # Input: (batch, raw_audio_samples). 16 kHz; example 1 second = 16000.
    batch_size = 1
    length = 16000
    dummy_input = torch.randn(batch_size, length)

    onnx_path = os.path.join(out_path, "wav2vec2_encoder.onnx")
    torch.onnx.export(
        encoder,
        dummy_input,
        onnx_path,
        input_names=["input_values"],
        output_names=["last_hidden_state"],
        dynamic_axes={
            "input_values": {0: "batch", 1: "length"},
            "last_hidden_state": {0: "batch", 1: "sequence"},
        },
        opset_version=14,
    )
    print(f"ONNX saved to {onnx_path}")

    print("\nNext steps:")
    print(f"  1. Copy {onnx_path}")
    print("  2. To: android/app/src/main/assets/models/onnx_models/wav2vec2_encoder.onnx")
    if os.path.exists(os.path.join(out_path, "preprocessor_config.json")):
        print("  3. Use preprocessor_config.json in your app for 16 kHz audio preprocessing.")


if __name__ == "__main__":
    main()
