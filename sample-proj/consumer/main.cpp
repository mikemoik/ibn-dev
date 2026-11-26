#include <iostream>

#include "proj/b/b.hpp"  // linked directly: proj::B
#include "proj/c/c.hpp"  // proj::C

int main() {
  std::cout << "c::report(1)      = " << proj::c::report(1) << '\n'
            << "b::plus_answer(1) = " << proj::b::plus_answer(1) << '\n'
            << "a::answer()       = " << proj::a::answer() << '\n';  // via b.hpp
}
