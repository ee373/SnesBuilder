# Rev.0.9 — ゲームパッケージとRISC-V実行イメージ


8MiBパラレルNORはSFCゲームROMだけでなく、ゲーム固有のRISC-V実行バイナリとリソースを格納する。内蔵Flashの共通ローダが、FPGA/AHB経由でNORからRISC-V実行イメージを読み出してAG32内蔵SRAM（CPU側0x20000000を基準とする実行領域）に展開し、エントリポイントへ制御を移す。ゲームROMの物理範囲とRISC-V/リソースの格納範囲はパッケージメタデータで区別し、NORの8MiB総容量内に収める。ROM容量マスクはSFC側のROMアクセスに適用し、ローダによる物理NORアクセスには適用しない。起動時のSFC BIOSは外部SRAM末尾8KiB、RISC-Vアプリケーションの命令フェッチ元はAG32内蔵SRAMとする。詳細は[firmware.md](boot.md)を参照する。

起動・リンカ・BIOSの実行順序は[ブート仕様](../boot.md)、ROM容量とバンクマッピングは[FPGA仕様](../../fpga/rom-mapping.md)を参照する。
