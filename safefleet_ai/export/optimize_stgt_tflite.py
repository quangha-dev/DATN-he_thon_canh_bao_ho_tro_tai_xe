"""Replace the two FlexErf GELU ops with a built-in TANH approximation.

The exported STGT graph uses exact GELU::erf, which requires the large
Select-TF-Ops/Flex Android runtime.  For on-device inference we approximate
``erf(x / sqrt(2))`` with ``tanh(sqrt(2 / pi) * x)``.  This keeps the trained
Conv/Transformer/MIL weights unchanged while making the graph runnable by the
small built-in LiteRT interpreter bundled by ``tflite_flutter``.

Install the schema helper once with ``pip install tflite==2.18.0``.
"""

from __future__ import annotations

import argparse
import hashlib
import math
import struct
from pathlib import Path

import tflite


FLEX_ERF = b"FlexErf"
ERF_INPUT_SCALE = 1 / math.sqrt(2)
TANH_INPUT_SCALE = math.sqrt(2 / math.pi)


def _patch_operator_code(raw: bytearray, operator_code: object) -> None:
    table = operator_code._tab  # Generated FlatBuffer table; no object API exists.
    deprecated_offset = table.Offset(4)
    builtin_offset = table.Offset(10)
    if deprecated_offset == 0 or builtin_offset == 0:
        raise ValueError("FlexErf operator code does not expose mutable fields")
    struct.pack_into("<b", raw, table.Pos + deprecated_offset, tflite.BuiltinOperator.TANH)
    struct.pack_into("<i", raw, table.Pos + builtin_offset, tflite.BuiltinOperator.TANH)


def _patch_scalar_buffer(raw: bytearray, buffer: object) -> None:
    table = buffer._tab
    data_offset = table.Offset(4)
    if data_offset == 0:
        raise ValueError("GELU scale buffer is empty")
    vector_start = table.Vector(data_offset)
    current = struct.unpack_from("<f", raw, vector_start)[0]
    if math.isclose(current, TANH_INPUT_SCALE, rel_tol=0, abs_tol=1e-6):
        return
    if not math.isclose(current, ERF_INPUT_SCALE, rel_tol=0, abs_tol=1e-6):
        raise ValueError(f"Unexpected GELU scale: {current}")
    struct.pack_into("<f", raw, vector_start, TANH_INPUT_SCALE)


def optimize(source: Path, output: Path) -> str:
    raw = bytearray(source.read_bytes())
    model = tflite.Model.GetRootAsModel(raw, 0)
    flex_codes = [
        model.OperatorCodes(index)
        for index in range(model.OperatorCodesLength())
        if model.OperatorCodes(index).CustomCode() == FLEX_ERF
    ]
    if len(flex_codes) != 1:
        raise ValueError(f"Expected one FlexErf operator code, found {len(flex_codes)}")

    graph = model.Subgraphs(0)
    flex_nodes = []
    for index in range(graph.OperatorsLength()):
        operator = graph.Operators(index)
        code = model.OperatorCodes(operator.OpcodeIndex())
        if code.CustomCode() == FLEX_ERF:
            flex_nodes.append(index)
    if len(flex_nodes) != 2:
        raise ValueError(f"Expected two FlexErf nodes, found {len(flex_nodes)}")

    scale_buffers: set[int] = set()
    for flex_index in flex_nodes:
        flex_operator = graph.Operators(flex_index)
        erf_input = flex_operator.Inputs(0)
        producers = [
            graph.Operators(index)
            for index in range(graph.OperatorsLength())
            if any(
                graph.Operators(index).Outputs(output_index) == erf_input
                for output_index in range(graph.Operators(index).OutputsLength())
            )
        ]
        if len(producers) != 1 or producers[0].InputsLength() != 2:
            raise ValueError("Could not identify the GELU scale multiplication")
        producer = producers[0]
        producer_code = model.OperatorCodes(producer.OpcodeIndex())
        if producer_code.BuiltinCode() != tflite.BuiltinOperator.MUL:
            raise ValueError("FlexErf input is not produced by MUL")
        for input_index in range(producer.InputsLength()):
            tensor = graph.Tensors(producer.Inputs(input_index))
            buffer_index = tensor.Buffer()
            buffer = model.Buffers(buffer_index)
            if buffer.DataLength() == 4:
                value = struct.unpack("<f", buffer.DataAsNumpy().tobytes())[0]
                if any(
                    math.isclose(value, expected, rel_tol=0, abs_tol=1e-6)
                    for expected in (ERF_INPUT_SCALE, TANH_INPUT_SCALE)
                ):
                    scale_buffers.add(buffer_index)

    if len(scale_buffers) != 1:
        raise ValueError(f"Expected one shared GELU scale buffer, found {scale_buffers}")

    _patch_operator_code(raw, flex_codes[0])
    _patch_scalar_buffer(raw, model.Buffers(scale_buffers.pop()))

    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(raw)
    return hashlib.sha256(raw).hexdigest().upper()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    digest = optimize(args.source, args.output)
    print(f"output={args.output} sha256={digest}")


if __name__ == "__main__":
    main()
