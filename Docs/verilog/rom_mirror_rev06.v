// Rev.0.6 standalone combinational ROM mapper; not a complete bridge.
// rom_size = 512KiB blocks minus one. HiROM requires rom_size <= 7.
// host_ram preserves shared SRAM A16. ARM mode uses GPIO BYP, external to this RTL.
module rom_mirror_rev06 (
 input wire a19,a20,a21,a23,
 input wire exhirom_enable,
 input wire [3:0] rom_size,
 input wire host_ram,
 output wire [3:0] mem_upper
);
 wire [3:0] x = {~a23 & exhirom_enable,a21,a20,a19};
 wire [3:0] n = rom_size;
 assign mem_upper[3] = x[3] & n[3];
 assign mem_upper[2] = x[2] & (n[2] | (n[3] & ~x[3]));
 assign mem_upper[1] = x[1] & (n[1] | (n[2] & ~x[2]) | (n[3] & ~x[3]));
 assign mem_upper[0] = x[0] & (host_ram | n[0] | (n[1] & ~x[1]) | (n[2] & ~x[2]) | (n[3] & ~x[3]));
endmodule
