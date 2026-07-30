#include <string>
#include "deep.h"
extern "C" int deep_len(const char *s) { return (int) std::string(s).size(); }
