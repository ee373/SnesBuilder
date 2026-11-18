# Verilog参考資料

2026-11-16保存。会話中に作成した sfc_udb_rev03.zip に含まれていたVerilogソースを原文のまま保存する。

**現行のRev.0.5のRTLではない。** 15bitアドレス入力・独自バンク方式を前提とした試作コードであり、現行仕様の評価については[UDB評価資料](../../udb-evaluation.md)を参照する。現行設計仕様については[プロジェクト資料](../../README.md)を参照する。

| ファイル | 内容 |
|---|---|
| cart_bridge_fast.v | Rev.0.3 FastROM候補のRTL。CE先行選択、読出データMUX、GPIOバイパス候補、バス制御、コマンド通信の参考。 |
| tb_cart_bridge_fast.v | Rev.0.3の比較用Verilogテストベンチ。 |
| cart_bridge_rev02_reference.v | テストベンチが参照する比較用モジュール。元のRev.0.2のcart_bridge.vと同一内容。 |

PSoC Creatorでの論理合成・配置配線・タイミング保証・実機検証は未実施である。テストベンチの実行も未確認であり、本保存作業では追加の検証を実施していない。

比較テストベンチの実行例（Icarus Verilog）:

```sh
iverilog -g2012 -o sim cart_bridge_rev02_reference.v cart_bridge_fast.v tb_cart_bridge_fast.v
vvp sim
```

現行仕様と混同しないよう、このディレクトリは参考コード専用とする。
