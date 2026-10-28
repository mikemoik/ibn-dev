#include "sample/c/c.hpp"

#include "sample/b/b.hpp"

namespace sample::c {

std::string report(int x) { return std::to_string(b::plus_answer(x)); }

}  // namespace sample::c
