# 転送と起動の両方を受ける。--transfer が付いていれば転送、無ければ起動。
# どちらも引数を残してから本来の仕事をする。
if [ "$1" = "--transfer" ]; then
    shift
    printf 'argv=%s\n' "$*" > transfer-argv.txt
    eval dst=\${$#}
    shift $(($# - 2))
    # host が付いた形（board.local:remote/x）から実際の書き込み先を取る。
    mkdir -p "$(dirname "${dst#*:}")"
    cp "$1" "${dst#*:}"
else
    printf 'argv=%s\n' "$*" > launch-argv.txt
    eval exec qemu-aarch64-static "\${$#}"
fi
