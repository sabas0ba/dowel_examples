#ifndef GREET_FROM_ARCHIVE
#error the archive package public defines did not arrive
#endif
int greet_answer(void);
int main(void) { return greet_answer() == 42 ? 0 : 1; }
