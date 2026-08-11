# 入口はひとつ。ローカルでも CI でも同じものを実行する。

.PHONY: verify report site clean

# 検査を走らせ、要約と掲示用の表まで作る。
verify:
	./run.sh
	@$(MAKE) --no-print-directory report

# 直近の実行をまとめる（.work/report/summary.md, results.json）。
# run.sh が落ちた後でも使える。
report:
	python3 scripts/report.py run --work .work --out .work/report
	python3 scripts/report.py append \
	    --results .work/report/results.json --history .work/report/history.json
	@$(MAKE) --no-print-directory site
	@echo
	@cat .work/report/summary.md

# 履歴から掲示用の頁と図を作る。CI が掲示用の枝で行うのと同じもの。
site:
	python3 scripts/report.py site --history .work/report/history.json \
	    --latest .work/report/results.json --out .work/report

clean:
	rm -rf .work
