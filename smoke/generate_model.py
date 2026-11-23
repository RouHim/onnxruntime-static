#!/usr/bin/env python3
"""Generate smoke/tiny_add.onnx, a minimal model for the C++ smoke test.

Requires the `onnx` Python package. The generated file is checked in so CI
does not need Python ML dependencies.
"""
from pathlib import Path

import onnx
from onnx import TensorProto, helper

OPSET = 17
IR_VERSION = 10


def build_model() -> onnx.ModelProto:
    node = helper.make_node("Add", ["x", "one"], ["y"], name="add")
    graph = helper.make_graph(
        [node],
        "tiny_add",
        [helper.make_tensor_value_info("x", TensorProto.FLOAT, [1, 4])],
        [helper.make_tensor_value_info("y", TensorProto.FLOAT, [1, 4])],
        [
            helper.make_tensor(
                "one", TensorProto.FLOAT, [1, 4], [1.0, 1.0, 1.0, 1.0]
            )
        ],
    )
    model = helper.make_model(
        graph,
        opset_imports=[helper.make_opsetid("", OPSET)],
        ir_version=IR_VERSION,
        producer_name="onnxruntime-static smoke",
    )
    onnx.checker.check_model(model)
    return model


if __name__ == "__main__":
    target = Path(__file__).with_name("tiny_add.onnx")
    onnx.save(build_model(), target)
    print(f"wrote {target}")
