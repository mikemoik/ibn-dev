#pragma once

#include <string>

namespace sample::c {

// B is a private dependency: only c.cpp includes it
std::string report(int x);

}  // namespace sample::c
