// SFC / PSoC 5LP cartridge bridge, Rev.0.2 (RTL prototype, NOT timing signed off).
// Use external Pins components for the two buses. *_oe = 1 means DRIVE.
// SFC input pins and memory datapath pins: no digital synchronization.
// sfc_wr_n is an external routed clock for the host register bank ONLY.
// sys_clk is the internal UDB/CPU-domain clock (start at 40 MHz).
// arm_* inputs come from Creator Control Registers; change only under
// the ownership protocol described in README.md. No automatic arbitration.
module cart_bridge (
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
    // $00:8000-$BFFF => sfc_a[14]=0; $C000-$FFFF=>1.
    wire fixed_win = sfc_a[14];
    wire reg_win = (sfc_a[14:5] == 10'h1ff);
    wire host_active = rst_n & host_enable & sfc_reset_n & ~sfc_romsel_n;
    wire host_rd = host_active & ~sfc_rd_n & sfc_wr_n;
    wire host_wr = host_active & sfc_rd_n & ~sfc_wr_n;

    // Register writes at external /WR rising edge. Input setup/hold relative
    // to this routed clock MUST be confirmed on the actual SFC and by STA.
    always @(posedge sfc_wr_n or negedge rst_n) begin
        if (!rst_n) begin
            page <= 9'd0;
            page_ram <= 1'b0;
            cmd_data <= 8'd0;
            cmd_seq <= 1'b0;
        end else if (host_active && reg_win && sfc_rd_n) begin
            case (sfc_a[4:0])
                5'h00: page[7:0] <= sfc_di;        // $BFE0
                5'h01: begin                     // $BFE1
                    page[8] <= sfc_di[0];
                    page_ram <= sfc_di[7];
                end
                5'h02: begin                     // $BFE2
                    cmd_data <= sfc_di;
                    cmd_seq <= ~cmd_seq;
                end
                default: ;
            endcase
        end
    end
    // Bundled-data CDC. Host must not overwrite cmd_data before ACK.
    // Firmware reads stable cmd_data after cmd_seq_sync changes, then sets ACK.
    always @(posedge sys_clk or negedge rst_n) begin
        if (!rst_n) begin
            cmd_seq_meta <= 1'b0;
            cmd_seq_sync <= 1'b0;
        end else begin
            cmd_seq_meta <= cmd_seq;
            cmd_seq_sync <= cmd_seq_meta;
        end
    end

    wire host_mem = host_active & ~reg_win & ~arm_own;
    wire host_ram = host_mem & ~fixed_win & page_ram;
    wire host_rom = host_mem & (fixed_win | ~page_ram);
    wire host_mem_read = host_rd & host_mem;
    wire host_mem_write = host_wr & host_ram; // SFC never programs NOR
    wire arm_sel = rst_n & arm_own & arm_ce;
    wire arm_read = arm_sel & arm_rd & ~arm_wr;
    wire arm_write = arm_sel & arm_wr & ~arm_rd;

    // The two products per address bit can be mapped to one PLD macrocell.
    assign mem_a[13:0] = arm_own ? arm_a[13:0] : sfc_a[13:0];
    assign mem_a[22:14] = arm_own ? arm_a[22:14] :
                                  (fixed_win ? 9'd0 : page);
    // Early CE; /OE is qualified by read strobe, /WE by write strobe.
    assign mem_ce_rom_n = ~(host_rom | (arm_sel & ~arm_ram));
    assign mem_ce_ram_n = ~(host_ram | (arm_sel & arm_ram));
    assign mem_oe_n = ~(host_mem_read | arm_read);
    assign mem_we_n = ~(host_mem_write | arm_write);

    // Direct asynchronous write path. Must check bus turnaround AND timing
    // between mem_d_oe, data, address, CE and /WE (especially rising edge).
    // For ARM writes the firmware may pre-drive data while CE and /WE are high,
    // by using arm_wr=1, arm_ce=0, then set arm_ce=1 to assert /WE.
    wire arm_drive = rst_n & arm_own & arm_wr & ~arm_rd;
    assign mem_d_oe = host_mem_write | arm_drive;
    assign mem_do = arm_own ? arm_d : sfc_di;

    // Only two register addresses drive the SFC data bus, even when ARM owns RAM.
    wire status_read = host_rd & reg_win & (sfc_a[4:0] == 5'h03);
    wire reply_read  = host_rd & reg_win & (sfc_a[4:0] == 5'h04);
    // ARM writes response first, waits for settling, then updates ACK.
    wire [7:0] status_data = {5'b0, arm_own, host_enable, (cmd_seq ^ arm_ack)};
    assign sfc_do = ({8{host_mem_read}} & mem_di) |
                    ({8{status_read}} & status_data) |
                    ({8{reply_read}} & arm_reply);
    assign sfc_d_oe = host_mem_read | status_read | reply_read;
    assign irq_assert = rst_n & host_enable & sfc_reset_n & arm_irq;
endmodule
