#include <vector>
#include "clib.h"

/* テストターゲット自体が C++ である場合。 */
int main() { std::vector<int> v{1, 2}; return c_double((int) v.size()) == 4 ? 0 : 1; }
