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

## 誤った入力

`undeclared/` と `missing-optional/` は意図的に誤っており、`app` からは
参照されない。それぞれ「宣言されていない機能を参照する」「有効化されて
いない任意の依存が実体を持たない」入力である。いずれも本体の `a8a59e7`
では黙って通っていた（[F-001](../../docs/10-findings.md#f-001) /
[F-002](../../docs/10-findings.md#f-002) /
[F-003](../../docs/10-findings.md#f-003)）。`07f16ec` で修正済み。

## 実行ファイルの出力

| 構成 | 出力 |
|---|---|
| 既定 | `backends=json width=4` |
| `--features=xml` | `backends=json+xml width=12` |
| `--no-default-features` | `backends=none width=0` |
