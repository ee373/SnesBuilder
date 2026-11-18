// Rev.0.3: FastROM candidate. Generic synthesizable RTL, not fitted to PSoC.
// Separate data path from strobe/OE. No tri-state inside UDB.
module cart_bridge_fast #(
    parameter ROM_PRESELECT = 1, // 0: qualify ROM CE with /ROMSEL
    parameter GPIO_BYPASS = 0 // 1: firmware takes MEM_A/D pad data via PRTx_BYP/DR
)(
    input wire rst_n, sys_clk,
    input wire sfc_reset_n, sfc_romsel_n, sfc_rd_n, sfc_wr_n,
    input wire [14:0] sfc_a,
    input wire [7:0] sfc_di, mem_di,
    input wire host_enable,
    input wire arm_own, arm_ce, arm_rd, arm_wr, arm_ram,
    input wire [22:0] arm_a,
    input wire [7:0] arm_d, arm_reply,
    input wire arm_ack, arm_irq,
    output wire [22:0] mem_a,
    output wire [7:0] mem_do, sfc_do,
    output wire mem_d_oe, sfc_d_oe,
    output wire mem_ce_rom_n, mem_ce_ram_n, mem_oe_n, mem_we_n,
    output wire irq_assert,
    output reg [7:0] cmd_data,
    output reg cmd_seq_sync
);
    reg [8:0] page;
    reg page_ram, cmd_seq, cmd_seq_meta;
    wire fixed_win = sfc_a[14];
    wire reg_win = (sfc_a[14:5] == 10'h1ff);
    wire status_addr = reg_win & (sfc_a[4:0] == 5'h03);
    wire reply_addr  = reg_win & (sfc_a[4:0] == 5'h04);
    wire host_active = rst_n & host_enable & sfc_reset_n & ~sfc_romsel_n;
    wire host_rd = host_active & ~sfc_rd_n & sfc_wr_n;
    wire host_wr = host_active & sfc_rd_n & ~sfc_wr_n;

    // Asynchronous external clock: use a real clock route in Creator.
    // Setup/hold and reset release must be verified on the target.
    always @(posedge sfc_wr_n or negedge rst_n) begin
        if (!rst_n) begin
            page <= 9'd0;
            page_ram <= 1'b0;
            cmd_data <= 8'd0;
            cmd_seq <= 1'b0;
        end else if (host_active && reg_win && sfc_rd_n) begin
            case (sfc_a[4:0])
                5'h00: page[7:0] <= sfc_di;
                5'h01: begin page[8] <= sfc_di[0]; page_ram <= sfc_di[7]; end
                5'h02: begin cmd_data <= sfc_di; cmd_seq <= ~cmd_seq; end
                default: ;
            endcase
        end
    end
    always @(posedge sys_clk or negedge rst_n) begin
        if (!rst_n) begin cmd_seq_meta <= 1'b0; cmd_seq_sync <= 1'b0; end
        else begin cmd_seq_meta <= cmd_seq; cmd_seq_sync <= cmd_seq_meta; end
    end

    // Two product terms per address bit. Do not add /RD, /WR or /ROMSEL
    // to the data/address paths. The fixed upper page is physical page 0.
    generate if (GPIO_BYPASS) begin : pin_mux
        // These are DSI sources, not the actual pad data when BYP=0.
        // Firmware changes BYP only while neither master accesses memory.
        // Keep BIE/OE under DSI hardware control in both ownership modes.
        assign mem_a[13:0] = sfc_a[13:0];
        assign mem_a[22:14] = {9{~fixed_win}} & page;
        assign mem_do = sfc_di;
    end else begin : pld_mux
        assign mem_a[13:0] = ({14{~arm_own}} & sfc_a[13:0]) |
                             ({14{ arm_own}} & arm_a[13:0]);
        assign mem_a[22:14] = ({9{~arm_own & ~fixed_win}} & page) |
                              ({9{ arm_own}} & arm_a[22:14]);
        assign mem_do = ({8{~arm_own}} & sfc_di) | ({8{arm_own}} & arm_d);
    end endgenerate

    // Address-only readback mux: the read strobe is used ONLY in pin OE.
    // Disabled data outputs are don't-care to the external bus.
    wire [7:0] status_data = {5'b0, arm_own, host_enable, (cmd_seq ^ arm_ack)};
    assign sfc_do = ({8{~reg_win}} & mem_di) |
                    ({8{status_addr}} & status_data) |
                    ({8{reply_addr}} & arm_reply);
    wire host_mem_read = host_rd & ~arm_own & ~reg_win;
    wire host_mem_write = host_wr & ~arm_own & ~reg_win & ~fixed_win & page_ram;
    assign sfc_d_oe = host_rd & ((~arm_own & ~reg_win) | status_addr | reply_addr);

    // NOR CE preselection can remain active across non-cartridge cycles.
    // Only CE is early: shared /OE and /WE remain strictly qualified.
    // SRAM CE never overlaps the NOR CE in the stable Boolean model.
    // Physical glitches, min-delay and bus turnaround still require STA/bench.
    wire rom_pre = rst_n & host_enable & sfc_reset_n & ~arm_own &
                   (fixed_win | ~page_ram) & (ROM_PRESELECT | ~sfc_romsel_n);
    wire ram_pre = host_active & ~arm_own & ~reg_win & ~fixed_win & page_ram;
    wire arm_sel = rst_n & arm_own & arm_ce;
    wire arm_read = arm_sel & arm_rd & ~arm_wr;
    wire arm_write = arm_sel & arm_wr & ~arm_rd;
    wire arm_drive = rst_n & arm_own & arm_wr & ~arm_rd;
    assign mem_ce_rom_n = ~(rom_pre | (arm_sel & ~arm_ram));
    assign mem_ce_ram_n = ~(ram_pre | (arm_sel & arm_ram));
    assign mem_oe_n = ~(host_mem_read | arm_read);
    assign mem_we_n = ~(host_mem_write | arm_write);
    assign mem_d_oe = host_mem_write | arm_drive;
    assign irq_assert = rst_n & host_enable & sfc_reset_n & arm_irq;
endmodule
