// SFCBuilder Rev.0.4 follow-up candidate, 2026-11-16.
// SOP RTL estimate; NOT a PSoC Creator component or timing-signed-off design.
// bus_mode: 00 host, 01/10 isolated, 11 ARM. Firmware MUST enter isolate,
// wait for pin turn-off, change PRTx_BYP / GPIO drive modes, then select owner.
// ARM addresses/data are supplied by GPIO DR, not by this RTL.
// External /WR rising edge clocks mailbox only. CDC is bundled-data + toggle.
// ARM must update reply, status/IRQ controls, then ACK after settling;
// SFC must not submit a new request until BUSY clears.
module sfcbuilder_bridge (
    input wire rst_n, sfc_reset_n, enabled, sys_clk,
    input wire romsel_n, rd_n, wr_n,
    input wire [5:0] a_lo,
    input wire a12,a13,a14,a15,a21,a22,a23,
    input wire [7:0] sfc_di, mem_di, arm_reply,
    input wire [1:0] bus_mode,
    input wire hi_enable, ex_enable, extension_enable,
    input wire arm_ce, arm_ram, arm_rd, arm_wr,
    input wire arm_ack, arm_irq_mask, arm_irq_pending,
    output wire [7:0] sfc_do, mem_dsi_data,
    output wire [22:0] mem_dsi_addr,
    output wire sfc_d_oe, mem_d_oe, direct_addr_oe, bypass_addr_oe,
    output wire buf_oe_n, ce_rom_n, ce_ram_n, mem_oe_n, mem_we_n,
    output wire irq_assert, arm_request,
    output reg [7:0] cmd_data,
    output reg [1:0] cmd_kind,
    output reg cmd_seq, cmd_meta, cmd_sync
);
// direct_addr_oe drives the 12 PSoC-sourced address pins; bypass_addr_oe
// drives the other 11 address pins ONLY in ARM mode. Board 3SB drives these
// 11 in host mode. mem_dsi_addr unused bits are placeholders, not pad drivers.

wire live;
assign live = rst_n & enabled; // comb
wire visible;
assign visible = live & sfc_reset_n; // comb
wire host_mode;
assign host_mode = live & ~bus_mode[1] & ~bus_mode[0]; // comb
wire arm_mode;
assign arm_mode = live & bus_mode[1] & bus_mode[0]; // comb
wire host_bus;
assign host_bus = host_mode & sfc_reset_n; // comb
wire host_rd;
assign host_rd = visible & ~rd_n & wr_n; // comb
wire host_wr;
assign host_wr = visible & rd_n & ~wr_n; // comb
wire io_win;
assign io_win = ~a22 & ~a15 & a14 & ~a13 & a12; // comb
wire ram_win;
assign ram_win = (~a22 & ~a15 & a14 & a13 & a21 & hi_enable) | (~a22 & ~a15 & a14 & a13 & a23 & ex_enable); // comb
wire io_sel;
assign io_sel = io_win & extension_enable; // comb
wire host_rom;
assign host_rom = host_bus & ~romsel_n & ~io_win & ~ram_win; // comb
wire host_ram;
assign host_ram = host_bus & ram_win; // comb
wire host_mem;
assign host_mem = host_rom | host_ram; // comb
wire host_ram_wr;
assign host_ram_wr = host_ram & host_wr; // comb
wire host_mem_rd;
assign host_mem_rd = host_mem & host_rd; // comb
wire arm_sel;
assign arm_sel = arm_mode & arm_ce; // comb
wire arm_read;
assign arm_read = arm_sel & arm_rd & ~arm_wr; // comb
wire arm_write;
assign arm_write = arm_sel & arm_wr & ~arm_rd; // comb
wire arm_drive;
assign arm_drive = arm_mode & arm_wr & ~arm_rd; // comb
assign direct_addr_oe = host_bus | arm_mode; // comb
assign bypass_addr_oe = arm_mode; // comb
assign buf_oe_n = ~host_bus; // comb
assign ce_rom_n = (~host_rom & ~arm_sel) | (~host_rom & arm_ram); // comb
assign ce_ram_n = (~host_ram & ~arm_sel) | (~host_ram & ~arm_ram); // comb
assign mem_oe_n = ~host_mem_rd & ~arm_read; // comb
assign mem_we_n = ~host_ram_wr & ~arm_write; // comb
assign mem_d_oe = host_ram_wr | arm_drive; // comb
assign mem_dsi_addr[0] = a_lo[0]; // comb
assign mem_dsi_addr[1] = a_lo[1]; // comb
assign mem_dsi_addr[2] = a_lo[2]; // comb
assign mem_dsi_addr[3] = a_lo[3]; // comb
assign mem_dsi_addr[4] = a_lo[4]; // comb
assign mem_dsi_addr[5] = a_lo[5]; // comb
assign mem_dsi_addr[6] = 1'b0; // comb
assign mem_dsi_addr[7] = 1'b0; // comb
assign mem_dsi_addr[8] = 1'b0; // comb
assign mem_dsi_addr[9] = 1'b0; // comb
assign mem_dsi_addr[10] = 1'b0; // comb
assign mem_dsi_addr[11] = 1'b0; // comb
assign mem_dsi_addr[12] = a12; // comb
assign mem_dsi_addr[13] = a13; // comb
assign mem_dsi_addr[14] = a14; // comb
assign mem_dsi_addr[15] = a15; // comb
assign mem_dsi_addr[16] = 1'b0; // comb
assign mem_dsi_addr[17] = 1'b0; // comb
assign mem_dsi_addr[18] = 1'b0; // comb
assign mem_dsi_addr[19] = 1'b0; // comb
assign mem_dsi_addr[20] = 1'b0; // comb
assign mem_dsi_addr[21] = a21; // comb
assign mem_dsi_addr[22] = ~a23; // comb
assign mem_dsi_data[0] = sfc_di[0]; // comb
assign mem_dsi_data[1] = sfc_di[1]; // comb
assign mem_dsi_data[2] = sfc_di[2]; // comb
assign mem_dsi_data[3] = sfc_di[3]; // comb
assign mem_dsi_data[4] = sfc_di[4]; // comb
assign mem_dsi_data[5] = sfc_di[5]; // comb
assign mem_dsi_data[6] = sfc_di[6]; // comb
assign mem_dsi_data[7] = sfc_di[7]; // comb
wire reg_low;
assign reg_low = io_sel & ~a_lo[5] & ~a_lo[4] & ~a_lo[3]; // comb
wire r_cmd;
assign r_cmd = reg_low & ~a_lo[2] & ~a_lo[1] & ~a_lo[0]; // comb
wire r_status;
assign r_status = reg_low & ~a_lo[2] & ~a_lo[1] & a_lo[0]; // comb
wire r_reply;
assign r_reply = reg_low & ~a_lo[2] & a_lo[1] & ~a_lo[0]; // comb
wire r_bus;
assign r_bus = reg_low & ~a_lo[2] & a_lo[1] & a_lo[0]; // comb
wire r_irqctl;
assign r_irqctl = reg_low & a_lo[2] & a_lo[1] & a_lo[0]; // comb
wire r_irqstat;
assign r_irqstat = io_sel & ~a_lo[5] & ~a_lo[4] & a_lo[3] & ~a_lo[2] & ~a_lo[1] & ~a_lo[0]; // comb
wire reg_readable;
assign reg_readable = r_status | r_reply | r_bus | r_irqctl | r_irqstat; // comb
wire reg_writeable;
assign reg_writeable = r_cmd | r_bus | r_irqctl | r_irqstat; // comb
wire busy;
assign busy = (cmd_seq & ~arm_ack) | (~cmd_seq & arm_ack); // comb
wire accept;
assign accept = visible & rd_n & reg_writeable & ~busy; // comb
wire kind0;
assign kind0 = r_bus | r_irqstat; // comb
wire kind1;
assign kind1 = r_irqctl | r_irqstat; // comb
wire status0;
assign status0 = (r_status & busy) | (r_bus & arm_mode) | (r_irqctl & arm_irq_mask) | (r_irqstat & arm_irq_pending); // comb
wire status1;
assign status1 = (r_status & arm_mode) | (r_bus & ~host_mode & ~arm_mode); // comb
wire status2;
assign status2 = r_status & arm_irq_pending; // comb
assign sfc_d_oe = (host_rd & host_mem) | (host_rd & reg_readable); // comb
assign sfc_do[0] = (host_mem & mem_di[0]) | (r_reply & arm_reply[0]) | status0; // comb
assign sfc_do[1] = (host_mem & mem_di[1]) | (r_reply & arm_reply[1]) | status1; // comb
assign sfc_do[2] = (host_mem & mem_di[2]) | (r_reply & arm_reply[2]) | status2; // comb
assign sfc_do[3] = (host_mem & mem_di[3]) | (r_reply & arm_reply[3]); // comb
assign sfc_do[4] = (host_mem & mem_di[4]) | (r_reply & arm_reply[4]); // comb
assign sfc_do[5] = (host_mem & mem_di[5]) | (r_reply & arm_reply[5]); // comb
assign sfc_do[6] = (host_mem & mem_di[6]) | (r_reply & arm_reply[6]); // comb
assign sfc_do[7] = (host_mem & mem_di[7]) | (r_reply & arm_reply[7]); // comb
assign irq_assert = host_bus & extension_enable & arm_irq_mask & arm_irq_pending; // comb
assign arm_request = (cmd_sync & ~arm_ack) | (~cmd_sync & arm_ack); // comb
wire cmd_data_d0;
assign cmd_data_d0 = (accept & sfc_di[0]) | (~accept & cmd_data[0]); // ff_host
wire cmd_data_d1;
assign cmd_data_d1 = (accept & sfc_di[1]) | (~accept & cmd_data[1]); // ff_host
wire cmd_data_d2;
assign cmd_data_d2 = (accept & sfc_di[2]) | (~accept & cmd_data[2]); // ff_host
wire cmd_data_d3;
assign cmd_data_d3 = (accept & sfc_di[3]) | (~accept & cmd_data[3]); // ff_host
wire cmd_data_d4;
assign cmd_data_d4 = (accept & sfc_di[4]) | (~accept & cmd_data[4]); // ff_host
wire cmd_data_d5;
assign cmd_data_d5 = (accept & sfc_di[5]) | (~accept & cmd_data[5]); // ff_host
wire cmd_data_d6;
assign cmd_data_d6 = (accept & sfc_di[6]) | (~accept & cmd_data[6]); // ff_host
wire cmd_data_d7;
assign cmd_data_d7 = (accept & sfc_di[7]) | (~accept & cmd_data[7]); // ff_host
wire cmd_kind_d0;
assign cmd_kind_d0 = (accept & kind0) | (~accept & cmd_kind[0]); // ff_host
wire cmd_kind_d1;
assign cmd_kind_d1 = (accept & kind1) | (~accept & cmd_kind[1]); // ff_host
wire cmd_seq_d;
assign cmd_seq_d = (accept & ~cmd_seq) | (~accept & cmd_seq); // ff_host
wire cmd_meta_d;
assign cmd_meta_d = cmd_seq; // ff_sys
wire cmd_sync_d;
assign cmd_sync_d = cmd_meta; // ff_sys
always @(posedge wr_n or negedge rst_n) begin
    if (!rst_n) begin cmd_data <= 0; cmd_kind <= 0; cmd_seq <= 0; end
    else begin
        cmd_data <= {cmd_data_d7,cmd_data_d6,cmd_data_d5,cmd_data_d4,
                     cmd_data_d3,cmd_data_d2,cmd_data_d1,cmd_data_d0};
        cmd_kind <= {cmd_kind_d1,cmd_kind_d0};
        cmd_seq <= cmd_seq_d;
    end
end
always @(posedge sys_clk or negedge rst_n) begin
    if (!rst_n) begin cmd_meta <= 0; cmd_sync <= 0; end
    else begin cmd_meta <= cmd_meta_d; cmd_sync <= cmd_sync_d; end
end
endmodule
