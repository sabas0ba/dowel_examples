#include "table.h"
#include "rows.h"

int table_sum(void)
{
    int s = 0;
    for (int i = 0; i < rows_len; i++)
        s += rows[i];
    return s;
}
