#pragma once

#include <Eigen/Core>
#include <string>

namespace proj {

// sum of the vector's entries (Eigen: public dependency, it is in this header)
double sum(const Eigen::VectorXd& v);

// SQLite version string (SQLiteCpp: private dependency, only in foo.cpp)
std::string sqlite_version();

}  // namespace proj
