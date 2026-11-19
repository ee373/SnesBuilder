# Rev.0.9 SFC↔RISC-V通信・FIFO・IRQ

電源投入後RISC-Vが外部SRAM物理0x1E000～0x1FFFFへ8KiBのSFC用BIOSを展開し、ROM形式・MEM所有権設定後にSFC /RESETを解除する。FPGAは$00:FFFC/FFFDへ00/80、$00:8000～8003へ5C/00/60/2Fの固定6バイトを返し、SFCが`JML $2F6000`を実行する。通信窓は$00–$3F/$80–$BF:$5000–$5FFF、SFC A0～A5の64アドレス周期とし、有効化レジスタでゲームROMとの競合を避ける。初期12レジスタは00 COMMAND、01 STATUS、02 REPLY、03 BUS_CONTROL、04 TX_DATA、05 RX_DATA、06 FIFO_STATUS、07 IRQ_CONTROL、08 IRQ_STATUS、09/0A LENGTH、0B ERRORとし、0C–3Fを予約する。双方向FIFOは初期各4バイトを想定する。

FPGAはSFCからの書込みをFIFO・コマンドに保存してCPUへIRQ通知し、CPUの返信値を事前にレジスタ/FIFOへ格納する。SFCの/RDサイクルを待ちCPU割り込み処理する方式は採用しない。異なるクロック領域はFIFOポインタ/ACKのCDCを実装する。IRQと必要に応じたDMA要求はAG32内蔵バスで伝達する。共通データバスのサービス枠と待機条件は[bus.md](bus.md)を参照する。
