#include <proj/foo.hpp>

#include <iostream>

int main() {
  Eigen::VectorXd v(3);
  v << 1, 2, 3;
  std::cout << "sum " << proj::sum(v) << ", sqlite " << proj::sqlite_version() << '\n';
}
