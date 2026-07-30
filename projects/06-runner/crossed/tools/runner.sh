# 実行ラッパの代わり。渡された引数と作業ディレクトリを残してから起動する。
# 末尾が成果物のパスであり、その手前は dowel.build の args そのままである。
#
# 成果物は本物の別アーキテクチャ向けなので、起動は qemu-user に委ねる
# （宣言の無いトリプルへは組めなくなったため。#42 の修正）。
printf 'cwd=%s\nargv=%s\n' "$PWD" "$*" > runner-argv.txt
eval exec qemu-aarch64-static "\${$#}"
