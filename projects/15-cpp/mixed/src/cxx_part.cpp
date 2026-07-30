#include <vector>
#include "parts.h"
#include "cxx_only.h"

/* .cpp は C++ の driver へ渡る。std::vector を使うため、
   C の driver では翻訳できない。 */
extern "C" int cxx_part(void)
{
    std::vector<int> v(CXX_VALUE, 1);
    return (int) v.size();
}
