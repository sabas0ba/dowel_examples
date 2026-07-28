#include <stdio.h>

/* 依存の辺が消えたら、公開定義も公開ヘッダも届かない。
   届いてしまう場合は、機能を外した意味が無い。 */
#ifdef JSON_AVAILABLE
#include "json.h"
#endif
#ifdef XML_AVAILABLE
#include "xml.h"
#endif

int main(void) {
    int total = 0;
    const char *names = "";

#ifdef JSON_AVAILABLE
    total += json_width();
    names = "json";
#endif
#ifdef XML_AVAILABLE
    total += xml_width();
    names = names[0] ? "json+xml" : "xml";
#endif
    if (!names[0]) names = "none";

    printf("backends=%s width=%d\n", names, total);
    return 0;
}
