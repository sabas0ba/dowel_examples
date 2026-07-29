#include <vector>
#include "parts.h"

/* .cpp は C++ の driver へ渡る。std::vector を使うため、
   C の driver では翻訳できない。 */
extern "C" int cxx_part(void)
{
    std::vector<int> v{1, 2, 3};
    return (int) v.size();
}
