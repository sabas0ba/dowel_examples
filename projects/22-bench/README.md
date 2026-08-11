# 22-bench — 測るための種別

`dowel bench` は `bench` 種別を組み、**過程まるごとの実時間**を測って min と
median を出す（ADR-0025）。

```console
$ dowel bench --iterations=5
measuring 3 benchmarks
bench b:spin/small ... min 2.00ms  median 2.02ms  (5 runs)
bench b:spin/big ... min 10.99ms  median 11.23ms  (5 runs)
bench b:spin/slow ... min 48.89ms  median 48.96ms  (5 runs)
```

枠組みは課されず、**読まれもしない**。C には測定結果の綴りに慣習が無く、
枠組みごとに1つ形式を解釈するのが ADR の拒む絡まりである。過程の外から
測るなら、どの実行ファイルにも同じ物差しが当たる。

## 何を検査にするか

時間そのものは検査にしない。速さは機械と負荷で変わる。固定できるのは
**関係**と**形**だけである。

| 見るもの | 固定できる理由 |
|---|---|
| min ≤ median ≤ max | 同じ系列から出る統計量の間の関係であり、機械に依らない |
| `runs` == `--iterations` | 頼んだ回数と走った回数は一致していなければならない |
| 遅い事例 > 速い事例 | 仕事の量を 100 倍にしてある。負荷で順序が入れ替わる幅ではない |
| 数が出る／出ない | 測れたかどうかは真偽である |

## 速さに判定は無い

ここが `test` との本質的な差である。**遅いことは失敗ではない。**

`dowel bench` が落ちるのは、走り切れなかったときだけである——非零で終わる、
シグナルで死ぬ、事例の `timeout` に掛かる、起動できない。そしてそのときは
**その事例の数を1つも出さない**。

```console
$ dowel bench
bench b:spin/small ... min 2.01ms  median 2.03ms  (3 runs)
bench b:spin/big ... min 11.02ms  median 11.15ms  (3 runs)

failures:

---- b:spin/boom ----
run 1 exited with status 3

bench result: FAILED. 1 of 3 could not be measured
```

途中までの統計は、完了した測定として読める。出さないのはそのためである。
落ちなかった事例の数は捨てない——1件の失敗が測定全体を無にするなら、
長い系列ほど結果が得られなくなる。

閾値も回帰の門も dowel には無い。下流の方針として JSON に当てるものであり、
`expect.sh` は**そういう旗が無いこと**も固定している。

## 判定する側と分かれている

同じ木に `bench` と `test` を置いてある。

| 打つもの | 走るもの |
|---|---|
| `dowel test` | `test` だけ |
| `dowel bench` | `bench` だけ |
| `dowel build` | 両方（どちらも実行ファイルである） |

宣言の側にも差がある。`bench` の事例に `should_fail` は書けない——測るので
あって判定しないので、覆す判定が無い。`harness` も受け付けない。

## 機械可読の形

```json
{"kind":"bench-result","target":"b:spin","case":"small","label":"b:spin/small",
 "runs":3,"min_us":2005,"median_us":2031,"max_us":2104,"failure":null}
```

時間は**整数のマイクロ秒**である。小数の描画は読む側の決めることであり、
数の側に持ち込むと比較のたびに丸めが問題になる。

## 測って、遅くて、開ける

測って遅かったものは、次に見たいのが中身である。`dowel debug` は `bench` も
受ける（`bin` / `test` / `bench`）。事例のラベルを渡せば、その事例の引数が
起動構成に写る。

```console
$ dowel debug b:spin/big --dap
{ "args": ["big"], … }
```
