from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

import numpy as np
import onnx
import onnxruntime as ort
import torch
import yaml
from torch import nn
from vietocr.model.vocab import Vocab
from vietocr.tool.config import Cfg
from vietocr.tool.predictor import Predictor


class Encoder(nn.Module):
    def __init__(self, predictor: Predictor):
        super().__init__()
        # VietOCR dùng permute(-1, 0, 1); ONNX yêu cầu perm chỉ số dương.
        # Tách cùng các layer của backbone và viết lại đúng phép reshape đó.
        self.backbone = predictor.model.cnn.model
        self.transformer = predictor.model.transformer

    def forward(self, image: torch.Tensor) -> torch.Tensor:
        convolution = self.backbone.features(image)
        convolution = self.backbone.dropout(convolution)
        convolution = self.backbone.last_conv_1x1(convolution)
        convolution = convolution.transpose(3, 2)
        convolution = convolution.flatten(2)
        features = convolution.permute(2, 0, 1)
        return self.transformer.forward_encoder(features)


class Decoder(nn.Module):
    def __init__(self, predictor: Predictor):
        super().__init__()
        self.transformer = predictor.model.transformer

    def forward(
        self, tokens: torch.Tensor, memory: torch.Tensor
    ) -> torch.Tensor:
        target_length = tokens.shape[0]
        target_mask = self.transformer.gen_nopeek_mask(target_length).to(tokens.device)
        target = self.transformer.pos_enc(
            self.transformer.embed_tgt(tokens) * math.sqrt(self.transformer.d_model)
        )
        # Passing the causal hint explicitly avoids PyTorch's data-dependent mask
        # inspection and lets ONNX keep the target sequence dimension dynamic.
        output = self.transformer.transformer.decoder(
            target,
            memory,
            tgt_mask=target_mask,
            tgt_is_causal=True,
        )
        return self.transformer.fc(output.transpose(0, 1))


def load_predictor(model_dir: Path) -> Predictor:
    with (model_dir / "base.yml").open(encoding="utf-8") as stream:
        config = yaml.safe_load(stream)
    with (model_dir / "vgg-transformer.yml").open(encoding="utf-8") as stream:
        config.update(yaml.safe_load(stream))
    config["device"] = "cpu"
    config["weights"] = str(model_dir / "vgg_transformer.pth")
    config["cnn"]["pretrained"] = False
    config["predictor"]["beamsearch"] = False
    return Predictor(Cfg(config))


def export(model_dir: Path, output_dir: Path) -> dict:
    output_dir.mkdir(parents=True, exist_ok=True)
    predictor = load_predictor(model_dir)
    predictor.model.eval()
    encoder = Encoder(predictor).eval()
    decoder = Decoder(predictor).eval()
    image = torch.rand(1, 3, 32, 512)
    # Use a non-unit sample length so torch.export does not specialize the
    # dynamic target dimension to one.
    tokens = torch.zeros((8, 1), dtype=torch.long)
    tokens[0, 0] = 1
    with torch.no_grad():
        memory = encoder(image)
        torch_logits = decoder(tokens, memory)

    encoder_path = output_dir / "vietocr_encoder.onnx"
    decoder_path = output_dir / "vietocr_decoder.onnx"
    torch.onnx.export(
        encoder,
        (image,),
        str(encoder_path),
        input_names=["image"],
        output_names=["memory"],
        opset_version=17,
        do_constant_folding=True,
        dynamo=False,
    )
    torch.onnx.export(
        decoder,
        (tokens, memory),
        str(decoder_path),
        input_names=["tokens", "memory"],
        output_names=["logits"],
        opset_version=18,
        dynamo=True,
        external_data=False,
        dynamic_shapes=(
            {0: torch.export.Dim("target_length", min=1, max=129)},
            None,
        ),
    )
    onnx.checker.check_model(onnx.load(encoder_path))
    onnx.checker.check_model(onnx.load(decoder_path))

    encoder_session = ort.InferenceSession(
        str(encoder_path), providers=["CPUExecutionProvider"]
    )
    decoder_session = ort.InferenceSession(
        str(decoder_path), providers=["CPUExecutionProvider"]
    )
    ort_memory = encoder_session.run(None, {"image": image.numpy()})[0]
    encoder_error = float(np.max(np.abs(memory.numpy() - ort_memory)))
    decoder_error = 0.0
    validated_target_lengths = []
    for target_length in (1, 2, 10, 64, 129):
        validation_tokens = torch.zeros((target_length, 1), dtype=torch.long)
        validation_tokens[0, 0] = 1
        with torch.no_grad():
            validation_logits = decoder(validation_tokens, memory)
        ort_logits = decoder_session.run(
            None,
            {"tokens": validation_tokens.numpy(), "memory": ort_memory},
        )[0]
        decoder_error = max(
            decoder_error,
            float(np.max(np.abs(validation_logits.numpy() - ort_logits))),
        )
        validated_target_lengths.append(target_length)
    if encoder_error > 1e-3 or decoder_error > 1e-3:
        raise RuntimeError(
            f"ONNX validation failed: encoder={encoder_error}, decoder={decoder_error}"
        )

    vocab = Vocab(predictor.config["vocab"])
    metadata = {
        "format": "vietocr-onnx-split-v1",
        "image_height": predictor.config["dataset"]["image_height"],
        "image_min_width": predictor.config["dataset"]["image_min_width"],
        "image_max_width": predictor.config["dataset"]["image_max_width"],
        "sos_token": vocab.go,
        "eos_token": vocab.eos,
        "max_sequence_length": 128,
        "characters": predictor.config["vocab"],
        "encoder_max_abs_error": encoder_error,
        "decoder_max_abs_error": decoder_error,
        "validated_target_lengths": validated_target_lengths,
        "encoder_bytes": encoder_path.stat().st_size,
        "decoder_bytes": decoder_path.stat().st_size,
    }
    (output_dir / "vietocr_metadata.json").write_text(
        json.dumps(metadata, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return metadata


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model-dir", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()
    print(
        json.dumps(
            export(args.model_dir, args.output_dir),
            ensure_ascii=False,
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
