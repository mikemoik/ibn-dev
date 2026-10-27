#include "proj/foo.hpp"

#include <SQLiteCpp/SQLiteCpp.h>

namespace proj {

double sum(const Eigen::VectorXd& v) { return v.sum(); }

std::string sqlite_version() {
  SQLite::Database db(":memory:");
  return db.execAndGet("SELECT sqlite_version()").getString();
}

}  // namespace proj
