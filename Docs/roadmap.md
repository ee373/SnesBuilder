# Rev.0.9 実装・検証計画

- [ ] AG32の固定機能と75/78使用・予約I/OのSupra Nativeピンフィッティング。
- [ ] Prepare LOGIC生成トップのAHB・IRQ・DMA/クロック・リセット接続。
- [ ] FPGAのROM4形式、7段階容量マスク、SRAMデコード、MEMアドレスMUX。
- [ ] U1/U6の/OE排他、MEM D0–D7の双方向OE、U5 DIR/OEを合成・実機確認。
- [ ] CPU→FPGA AHBメモリコントローラ、HREADYOUT、NOR/SRAM8bit、SFC優先通信。
- [ ] $5000の64アドレス窓、FIFO、IRQ、ブート固定6バイト、SRAM BIOS。
- [ ] SlowROM200ns、FastROM120nsのSTA・実機測定と電源/CIC/リセット検証。
- [ ] PVSnesLib HiROM/SlowROM→LoROM/Ex形式、SDK、エミュレータ。
- [ ] 将棋AI、3Dデモ、多重PCM、USB配信デモの実証。

回路規模・ピン合法性・実機FastROMは未検証。歴史的RTLの検証結果を現行の合格根拠に使用しない。
