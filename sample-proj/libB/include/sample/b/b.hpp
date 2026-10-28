#pragma once

#include "sample/a/a.hpp"

namespace sample::b {

// adds a::answer(): A is a public dependency, it is in this header
int plus_answer(int x);

}  // namespace sample::b
