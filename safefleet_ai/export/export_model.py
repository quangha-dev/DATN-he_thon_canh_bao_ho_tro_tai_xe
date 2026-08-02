"""Export the calibrated classifier to mobile metadata, ONNX, or TFLite.

The lightweight runtime image does not install training frameworks. Install
`requirements-ml.txt` only on a training workstation before ONNX/TFLite export.
"""

from __future__ import annotations

import argparse
import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MODEL_METADATA = ROOT / "models" / "safefleet_temporal_rules.json"

# Eight normalized signals -> drowsiness and phone-usage logits.
WEIGHTS = [
    [-1.8, 0.0],
    [-1.8, 0.0],
    [2.2, 0.0],
    [0.5, 0.0],
    [0.5, 0.0],
    [1.2, 0.0],
    [0.0, 2.8],
    [0.0, 0.5],
]
BIASES = [-0.5, -1.7]


def export_mobile(output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(MODEL_METADATA, output)
    json.loads(output.read_text(encoding="utf-8"))


def export_onnx(output: Path) -> None:
    try:
        import numpy as np
        import onnx
        from onnx import TensorProto, helper, numpy_helper
    except ImportError as exception:
        raise SystemExit(
            "ONNX export requires: pip install -r requirements-ml.txt"
        ) from exception

    input_info = helper.make_tensor_value_info(
        "signals", TensorProto.FLOAT, [None, 8]
    )
    output_info = helper.make_tensor_value_info(
        "probabilities", TensorProto.FLOAT, [None, 2]
    )
    weight = numpy_helper.from_array(np.asarray(WEIGHTS, dtype=np.float32), "weights")
    bias = numpy_helper.from_array(np.asarray(BIASES, dtype=np.float32), "biases")
    graph = helper.make_graph(
        [
            helper.make_node("MatMul", ["signals", "weights"], ["logits"]),
            helper.make_node("Add", ["logits", "biases"], ["biased"]),
            helper.make_node("Sigmoid", ["biased"], ["probabilities"]),
        ],
        "SafeFleetCabinClassifier",
        [input_info],
        [output_info],
        [weight, bias],
    )
    model = helper.make_model(
        graph,
        producer_name="safefleet-ai",
        opset_imports=[helper.make_opsetid("", 17)],
    )
    onnx.checker.check_model(model)
    output.parent.mkdir(parents=True, exist_ok=True)
    onnx.save(model, output)


def export_tflite(output: Path) -> None:
    try:
        import numpy as np
        import tensorflow as tf
    except ImportError as exception:
        raise SystemExit(
            "TFLite export requires: pip install -r requirements-ml.txt"
        ) from exception

    model = tf.keras.Sequential(
        [
            tf.keras.Input(shape=(8,), name="signals"),
            tf.keras.layers.Dense(2, activation="sigmoid", name="probabilities"),
        ]
    )
    model.layers[0].set_weights(
        [
            np.asarray(WEIGHTS, dtype=np.float32),
            np.asarray(BIASES, dtype=np.float32),
        ]
    )
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(converter.convert())


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--format",
        choices=("mobile", "onnx", "tflite"),
        required=True,
    )
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    {
        "mobile": export_mobile,
        "onnx": export_onnx,
        "tflite": export_tflite,
    }[args.format](args.output)
    print(
        json.dumps(
            {
                "format": args.format,
                "output": str(args.output),
                "sizeBytes": args.output.stat().st_size,
            }
        )
    )


if __name__ == "__main__":
    main()
