# 08-lsp — 言語サーバ
#
# `dowel lsp` は標準入出力で LSP を話す。エディタが起動主体であり、
# 常駐デーモンではない（ADR-0002）。
#
# 本体の `dowel-lsp` は自分自身を内側から検査している。ここで見るのは
# そこから見えない側、すなわち **CLI と言語サーバが同じ本文に同じ答を
# 返すか**である。両者は別の入口だが、利用者にとっては同じ道具である。
# エディタが黙っている誤りは、利用者にとって存在しない誤りになる。
#
# シェルから JSON-RPC を話すのは無理があるため、検査の本体は checks.py に
# 置く。ハーネスとの境界は他のプロジェクトと同じ「1検査1行」に揃えてあり、
# checks.py は `status \t desc \t 所見` を書くだけである。

if ! python3 -c 'import sys' 2>/dev/null; then
    fact 1 "python3 is available for the language server checks"
    return 0
fi

while IFS=$'\t' read -r status desc issue; do
    [ -n "$status" ] || continue
    [ -n "$issue" ] && known_issue "$issue"
    case $status in
        pass) fact 0 "$desc" ;;
        *)    fact 1 "$desc" ;;
    esac
done < <(python3 checks.py)
