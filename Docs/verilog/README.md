# 評価用RTLと検証

Rev.0.7の正本は[UDB評価](../udb-evaluation.md)と各設計資料。完全なRev.0.7チップセットRTL、Creatorコンポーネント、FIFO実装は未作成。

| ファイル | 内容 |
|---|---|
| rom_mirror_1m.v | Rev.0.7の1MiB単位ROM上位3bit独立組み合わせRTL。SFC A19は無変換 |
| tb_rom_mirror_1m.v | Rev.0.7の384条件を想定する自己検査HDLテストベンチ（未実行） |
| check_1m.py | Rev.0.7の1MiBミラーリングを独立再帰モデルで384条件検証（実行済み） |
| verification.txt | Python検証出力（PASS 384件） |
| verification_package_1m.md | 展開した検証ZIPのREADMEと実行方法 |
| rom_mirror_rev06.v | Rev.0.6 ROM上位4bitの独立組み合わせRTL、SRAM A19保持 |
| check_rom_mirror_rev06.py | 参照モデルと組み合わせ式の再現用Python評価 |
| sfcbuilder_bridge.v | Rev.0.5基本RTL（旧資源評価の再現用） |
| tb_sfcbuilder_bridge.v | Rev.0.5指向性HDLテストベンチ（未実行） |
| estimate_and_check.py | Rev.0.5構造推定と安定論理条件の検証 |
| verification.log | Rev.0.5の実行結果 |

Rev.0.5のファイルは旧ピン・旧通信幅の評価再現専用であり、Rev.0.6の仕様を表さない。新しいROM変換は独立モジュールで提供する。全体RTLの更新はFIFO・CDC・Creator連携の詳細設計と合わせて行う。

`python3 check_rom_mirror_rev06.py` で新しい論理式の検証を再現できる。Rev.0.6当時は等価のJavaScriptモデルで256件の論理組み合わせと6144件のバンク例を確認した。PythonファイルとHDLは未実行。旧評価は `python3 estimate_and_check.py` で再現する。

## Rev.0.7 1MiB変換の検証

`python3 check_1m.py` によりHiROM 1～4MiB、ExHiROM 1～8MiB、A23/A21/A20/A19とRAM選択状態を網羅する384組合せの独立参照モデル照合を実施し、全件PASSを確認した。`rom_mirror_1m.v`と`tb_rom_mirror_1m.v`は会話で作成したZIPから解凍して独立ファイルとして追加した。HDLシミュレーションは未実行である。

```bash
iverilog -g2012 -s tb_rom_mirror_1m -o sim rom_mirror_1m.v tb_rom_mirror_1m.v
vvp sim
```

旧`rom_mirror_rev06.v`等は履歴として維持するが、現行マッピングは`rom_mirror_1m.v`を参照する。完全なRev.0.7ブリッジRTL、FIFO、Creatorのアナログルーティング、STAおよび実機動作は未検証。音声回路の決定仕様は[../audio.md](../audio.md)参照。


## Rev.0.7 統合RTL v2（2026-11-18）

現行仕様に合わせた統合動作モデル、テストベンチ、独立検証スクリプトと実行記録は [integrated_rev07/](integrated_rev07/README.md) に保存する。ROM容量1MiB単位のアドレス変換、SRAM BIOS用6バイト固定応答、NOR/SRAM排他、SFC/ARMメモリバス所有権ハンドシェイク、$5000通信レジスタ、40MHz候補の内部同期クロックによる双方向4バイトFIFOの動作モデルを含む。

検証済みなのはPython独立モデル／RTL記述式の照合であり、ROMミラーリング384件、ブート応答512件、SRAM境界48件、バス所有権状態遷移20,000件、FIFO動作100,000件等がPASSした。**Verilogテストベンチのコンパイル・HDLシミュレーション、およびPSoC Creatorの合成・配置配線は未実施**。UDB専用FIFOへの置換、GPIO/DSIの実配線、CDC/STA、バス安全性の実機確認が残る。資源使用量は状態ビット数の静的算定のみであり48 PLDへの収容を実証したものではない。現行の設計仕様は引き続きhardware.md、memory.md、bus-udb.md、communication.md、firmware.mdを正本とする。
