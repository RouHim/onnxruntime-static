// Link and run a minimal inference against a statically linked ONNX Runtime.
#include <onnxruntime_cxx_api.h>

#include <array>
#include <cmath>
#include <cstdio>

namespace {

constexpr float kTolerance = 1e-5f;

int fail(const char* message) {
    std::fprintf(stderr, "smoke failed: %s\n", message);
    return 1;
}

}  // namespace

int main(int argc, char** argv) {
    if (argc != 2) {
        std::fprintf(stderr, "usage: %s <model.onnx>\n", argv[0]);
        return 2;
    }

    Ort::Env env(ORT_LOGGING_LEVEL_WARNING, "smoke");
    Ort::SessionOptions options;
    options.SetIntraOpNumThreads(1);
    options.SetGraphOptimizationLevel(GraphOptimizationLevel::ORT_ENABLE_BASIC);

    Ort::Session session(env, argv[1], options);
    Ort::AllocatorWithDefaultOptions allocator;
    auto input_name = session.GetInputNameAllocated(0, allocator);
    auto output_name = session.GetOutputNameAllocated(0, allocator);

    std::array<float, 4> input{1.0f, 2.0f, 3.0f, 4.0f};
    std::array<int64_t, 2> shape{1, 4};
    auto memory = Ort::MemoryInfo::CreateCpu(OrtArenaAllocator, OrtMemTypeDefault);
    auto tensor = Ort::Value::CreateTensor<float>(
        memory, input.data(), input.size(), shape.data(), shape.size());

    const char* input_names[] = {input_name.get()};
    const char* output_names[] = {output_name.get()};
    auto outputs = session.Run(
        Ort::RunOptions{nullptr}, input_names, &tensor, 1, output_names, 1);

    const auto info = outputs[0].GetTensorTypeAndShapeInfo();
    if (info.GetElementCount() != input.size()) {
        return fail("unexpected output element count");
    }
    const auto element_type = info.GetElementType();
    if (element_type != ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT) {
        return fail("unexpected output element type");
    }

    const float* output = outputs[0].GetTensorData<float>();
    for (size_t i = 0; i < input.size(); ++i) {
        const float expected = input[i] + 1.0f;
        if (std::fabs(output[i] - expected) > kTolerance) {
            std::fprintf(stderr, "smoke failed: output[%zu] = %f, expected %f\n",
                         i, output[i], expected);
            return 1;
        }
    }

    std::puts("smoke ok");
    return 0;
}
