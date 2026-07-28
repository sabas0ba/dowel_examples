#include <stdio.h>

/* When the edge goes, neither the public define nor the public header
   arrives. If they did, disabling the feature would mean nothing. */
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
