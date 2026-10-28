#pragma once

#include <string>

namespace proj::c {

// B is a private dependency: only c.cpp includes it
std::string report(int x);

}  // namespace proj::c
