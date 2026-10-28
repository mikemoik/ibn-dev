#pragma once

#include "proj/a/a.hpp"

namespace proj::b {

// adds a::answer(): A is a public dependency, it is in this header
int plus_answer(int x);

}  // namespace proj::b
