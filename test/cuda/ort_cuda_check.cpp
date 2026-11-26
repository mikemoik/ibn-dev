// ort_cuda_check: does onnxruntime's CUDA provider work here? Runs the
// prodsim model (test/prodsim/data/tile_sigmoid.onnx, one Sigmoid node,
// embedded below) with the CPU fallback off, so it only passes if the node
// runs on the GPU. Sigmoid needs no cuDNN (onnxruntime loads it only for
// ops like Conv), so cuDNN is checked separately: libcudnn.so loaded the way
// the provider does, and its version. In the GPU container (README: Run → GPU), with the dist
// environment (the shell hooks):
//   g++ -std=c++17 ort_cuda_check.cpp -lonnxruntime -ldl -o /tmp/ort_cuda_check && /tmp/ort_cuda_check
#include <onnxruntime_cxx_api.h>
#include <dlfcn.h>

#include <array>
#include <cmath>
#include <cstdio>

static const unsigned char model[] = {
    0x08, 0x08, 0x12, 0x14, 0x70, 0x72, 0x6f, 0x64, 0x73, 0x69, 0x6d, 0x20,
    0x67, 0x65, 0x6e, 0x5f, 0x6d, 0x6f, 0x64, 0x65, 0x6c, 0x2e, 0x70, 0x79,
    0x3a, 0x4d, 0x0a, 0x18, 0x0a, 0x01, 0x78, 0x12, 0x01, 0x79, 0x1a, 0x07,
    0x73, 0x69, 0x67, 0x6d, 0x6f, 0x69, 0x64, 0x22, 0x07, 0x53, 0x69, 0x67,
    0x6d, 0x6f, 0x69, 0x64, 0x12, 0x0d, 0x70, 0x72, 0x6f, 0x64, 0x73, 0x69,
    0x6d, 0x5f, 0x74, 0x69, 0x6c, 0x65, 0x73, 0x5a, 0x10, 0x0a, 0x01, 0x78,
    0x12, 0x0b, 0x0a, 0x09, 0x08, 0x01, 0x12, 0x05, 0x0a, 0x03, 0x12, 0x01,
    0x6e, 0x62, 0x10, 0x0a, 0x01, 0x79, 0x12, 0x0b, 0x0a, 0x09, 0x08, 0x01,
    0x12, 0x05, 0x0a, 0x03, 0x12, 0x01, 0x6e, 0x42, 0x04, 0x0a, 0x00, 0x10,
    0x0d,
};

int main() {
  try {
    Ort::Env env(ORT_LOGGING_LEVEL_WARNING, "ort_cuda_check");
    Ort::SessionOptions opts;
    opts.AddConfigEntry("session.disable_cpu_ep_fallback", "1");
    OrtCUDAProviderOptions cuda{};
    opts.AppendExecutionProvider_CUDA(cuda);
    Ort::Session session(env, model, sizeof model, opts);

    std::array<float, 3> x{-2.f, 0.f, 2.f};
    std::array<int64_t, 1> shape{3};
    auto mem = Ort::MemoryInfo::CreateCpu(OrtArenaAllocator, OrtMemTypeDefault);
    auto in = Ort::Value::CreateTensor<float>(mem, x.data(), x.size(), shape.data(), shape.size());
    const char* in_names[] = {"x"};
    const char* out_names[] = {"y"};
    auto out = session.Run(Ort::RunOptions{nullptr}, in_names, &in, 1, out_names, 1);
    const float* y = out[0].GetTensorData<float>();
    for (size_t i = 0; i < x.size(); ++i)
      if (std::fabs(y[i] - 1.f / (1.f + std::exp(-x[i]))) > 1e-5f) {
        std::fprintf(stderr, "CUDA FAILED: wrong result sigmoid(%g) = %g\n", x[i], y[i]);
        return 1;
      }
    std::printf("CUDA OK: onnxruntime %s, sigmoid(-2, 0, 2) = %.4f %.4f %.4f on the GPU\n",
                Ort::GetVersionString().c_str(), y[0], y[1], y[2]);
    std::fflush(stdout);

    void* cudnn = dlopen("libcudnn.so", RTLD_NOW);
    if (!cudnn) {
      std::fprintf(stderr, "cuDNN FAILED: %s\n", dlerror());
      return 1;
    }
    auto version = reinterpret_cast<size_t (*)()>(dlsym(cudnn, "cudnnGetVersion"));
    std::printf("cuDNN OK: %zu\n", version ? version() : 0);
  } catch (const Ort::Exception& e) {
    std::fprintf(stderr, "CUDA FAILED: %s\n", e.what());
    return 1;
  }
}
