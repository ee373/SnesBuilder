// SFCBuilder proposal: 1 MiB granularity mapper.
// 'rom_blocks_m1' encodes 1..8 MiB as 0..7 (HiROM: 0..3).
// SFC_A19 is routed through the spare 74LVC16244 channel directly to
// MEM_A19.  No ROM remapping of A19 occurs.
// The external 3SB must be disabled during ARM bus ownership.
// This module represents HOST-address combinational logic only.
module rom_mirror_1m (
    input wire sfc_a19,
    input wire sfc_a20,
    input wire sfc_a21,
    input wire sfc_a23,
    input wire exhirom_enable,
    input wire [2:0] rom_blocks_m1,
    input wire host_ram,
    output wire [3:0] mem_a22_a19
);
    wire [2:0] x = {~sfc_a23 & exhirom_enable, sfc_a21, sfc_a20};
    wire [2:0] n = rom_blocks_m1;
    wire [2:0] y;
    assign y[2] = x[2] & n[2];
    assign y[1] = x[1] & (n[1] | (n[2] & ~x[2]));
    assign y[0] = x[0] & (n[0] | (n[1] & ~x[1]) | (n[2] & ~x[2]));
    // For SRAM the lower address bits are passed directly and A20..22
    // are physically unconnected to the SRAM.  A19 is raw for both.
    assign mem_a22_a19 = {y, sfc_a19};
endmodule
