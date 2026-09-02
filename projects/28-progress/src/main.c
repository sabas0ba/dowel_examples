#include <stdio.h>

int s1(void);
int s2(void);
int s3(void);
int s4(void);

int main(void)
{
    printf("%d\n", s1() + s2() + s3() + s4());
    return 0;
}
