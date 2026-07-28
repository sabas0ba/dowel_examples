#!/usr/bin/env python3
"""機械適用可能と称する修正提案を、実際に適用する。

`dowel ... --message-format=json` の出力を標準入力から読み、各診断の
`suggestions` を対象ファイルへ書き戻す。診断が「機械適用可能」であることの
唯一の確かめ方は、適用した結果がもう一度受理されるかどうかである。

同じファイルへの複数の提案は、後ろから適用して位置のずれを避ける。
"""

import json
import sys
from collections import defaultdict


def main() -> int:
    edits = defaultdict(list)
    count = 0

    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            diag = json.loads(line)
        except json.JSONDecodeError:
            continue
        for s in diag.get("suggestions", []):
            path = s.get("file")
            if path is None:
                continue
            edits[path].append((s["byte_start"], s["byte_end"], s["replacement"]))
            count += 1

    if count == 0:
        print("no suggestions", file=sys.stderr)
        return 1

    for path, spans in edits.items():
        with open(path, "rb") as f:
            data = f.read()
        for start, end, replacement in sorted(spans, reverse=True):
            data = data[:start] + replacement.encode("utf-8") + data[end:]
        with open(path, "wb") as f:
            f.write(data)

    print(f"applied {count} suggestion(s)", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
