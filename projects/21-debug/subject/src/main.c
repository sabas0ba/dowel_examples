/* デバッガで開く相手。止められる場所として関数を2つ持つ。 */
int add(int a, int b) { return a + b; }

int main(void)
{
    return add(2, 2) == 4 ? 0 : 1;
}
