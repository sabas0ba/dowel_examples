/* 生イメージに現れる印。objcopy が本当に走ったかを中身で確かめる。 */
const char marker[] = "DOWEL-ARTIFACT-MARKER";

int main(void)
{
    return marker[0] == 'D' ? 0 : 1;
}
