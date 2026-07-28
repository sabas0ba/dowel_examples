# 03-features — 機能フラグと任意の依存

```
        app
       /   \
   json     xml        いずれも optional。辺は feature で現れ／消える
```

`app` の `[features]` は `default = ["json"]`。`json` / `xml` はそれぞれ
同名の任意の依存を引く。

```
[bin.app.private]
deps = [
    dep("json") when feature.json,
    dep("xml")  when feature.xml,
]
```

## 何を固定するか

1. **辺が現れる。** 既定で `json` が入り、`JSON_AVAILABLE` と公開ヘッダが
   `app` に届く
2. **辺が消える。** `--no-default-features` で公開定義もヘッダも届かない。
   消える側が重要である。辺が消えたのにヘッダやライブラリが残っていると、
   「機能を外したはずの構成」で外したはずのコードがリンクされる。
   これは実行時にしか現れない不整合である
3. **消えた依存は組まない。** 出力の内容からは「使っていない」ことしか
   分からない。「持ち込んでいない」ことはアクショングラフでしか見えないため、
   `libjson.a` が現れないことを別に見る
4. **複数の機能を重ねられる。** `--features=xml` で両方の辺が立つ

## 既知の未修正事項

このプロジェクトが固定している xfail は3種類。詳細は
[docs/10-findings.md](../../docs/10-findings.md)。

| # | 内容 |
|---|---|
| F-001 | 宣言されていない機能名を `--features` に渡しても診断が出ない |
| F-002 | `dowel.build` の `feature.<未宣言>` が黙って偽になる |
| F-003 | 有効化されていない `optional` 依存が読み込まれる |

F-001 と F-002 のための入力が `undeclared/`、F-003 のための入力が
`missing-optional/` である。いずれも意図的に誤っており、
`app` からは参照されない。

## 実行ファイルの出力

| 構成 | 出力 |
|---|---|
| 既定 | `backends=json width=4` |
| `--features=xml` | `backends=json+xml width=12` |
| `--no-default-features` | `backends=none width=0` |
