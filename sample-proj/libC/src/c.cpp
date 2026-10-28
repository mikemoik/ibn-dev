#include "proj/c/c.hpp"

#include "proj/b/b.hpp"

namespace proj::c {

std::string report(int x) { return std::to_string(b::plus_answer(x)); }

}  // namespace proj::c
