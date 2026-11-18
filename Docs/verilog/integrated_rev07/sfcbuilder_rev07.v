`default_nettype none
// SFCBuilder Rev.0.7 integrated functional RTL, revision 2.
// Generic HDL simulation model: fifo4_sync needs PSoC datapath F0/F1 mapping.
// Physical GPIO drive modes/PRTx_BYP are firmware-written. UDB guards access
// until an explicit per-transition configuration handshake is completed.
module sfcbuilder_rev07 (
    input wire rst_n, sys_clk, sfc_reset_n, enabled,
    // req=1 ARM, req=0 SFC. Requests may remain asserted after completion.
    input wire request_arm, host_quiesced, gpio_cfg_done,
    output wire gpio_cfg_request, gpio_cfg_target_arm,
    output wire [2:0] owner_state, // 0 isolated, 1 SFC, 2 ARM, 3 transitioning
    output wire owner_busy,
    input wire boot_mode, extension_enable, hi_enable, ex_enable,
    input wire exhirom_enable, input wire [2:0] rom_blocks_m1,
    input wire romsel_n, rd_n, wr_n,
    input wire [4:0] sfc_a0_4,
    input wire [3:0] sfc_a12_15, sfc_a20_23,
    input wire [6:0] host_mem_a5_11,
    input wire [3:0] host_mem_a16_19,
    input wire [7:0] sfc_data_in, mem_data_in,
    output reg [7:0] sfc_data_out,
    output wire sfc_data_oe,
    output wire [22:0] mem_addr_out, mem_addr_oe,
    output wire [7:0] mem_data_out,
    output wire mem_data_oe,
    output wire buf_oe_n, ce_rom_n, ce_ram_n, mem_oe_n, mem_we_n,
    output wire irq_assert,
    input wire [22:0] arm_mem_addr,
    input wire [7:0] arm_mem_wdata,
    input wire arm_mem_ce, arm_mem_ram, arm_mem_rd, arm_mem_wr,
    output reg [7:0] cmd_data,
    output reg [2:0] cmd_kind,
    output wire arm_cmd_valid,
    input wire arm_cmd_ack,
    input wire [7:0] arm_reply,
    input wire arm_irq_mask, arm_irq_pending,
    input wire [7:0] arm_error,
    input wire [15:0] arm_length,
    output wire [7:0] arm_tx_data,
    output wire arm_tx_valid,
    input wire arm_tx_ready,
    input wire [7:0] arm_rx_data,
    input wire arm_rx_valid,
    output wire arm_rx_ready,
    output wire [7:0] fifo_status,
    output wire boot_hit
);
    wire live = rst_n && enabled;
    // FSM: isolate when reset; quiesce (all strobes + OE disabled), await
    // GPIO change acknowledgment, then a four-sys_clk guard before ownership.
    localparam [2:0] ISO=3'd0, HOST=3'd1, ARM=3'd2,
                     QUIET=3'd3, CONFIG=3'd4, GUARD=3'd5;
    reg [2:0] state;
    reg target_arm;
    reg config_seen_low;
    reg [2:0] guard_count;
    // ARM-side requests are sampled through 2FF synchronizers.  Firmware
    // holds each request/acknowledgment level until the state changes.
    reg req_meta,req_sync,quiesce_meta,quiesce_sync,done_meta,done_sync;
    always @(posedge sys_clk or negedge rst_n) begin
        if (!rst_n) begin
            req_meta<=0;req_sync<=0;quiesce_meta<=0;quiesce_sync<=0;
            done_meta<=0;done_sync<=0;
        end else begin
            req_meta<=request_arm;req_sync<=req_meta;
            quiesce_meta<=host_quiesced;quiesce_sync<=quiesce_meta;
            done_meta<=gpio_cfg_done;done_sync<=done_meta;
        end
    end
    wire cycle_idle = rd_n && wr_n && !arm_mem_rd && !arm_mem_wr;
    wire sfc_owner = live && (state == HOST);
    wire arm_owner = live && (state == ARM);
    wire sfc_active = sfc_owner && sfc_reset_n;
    wire sfc_rd = live && sfc_reset_n && !rd_n && wr_n;
    wire sfc_wr = live && sfc_reset_n && rd_n && !wr_n;
    assign owner_state = !live ? 3'd0 : state==HOST ? 3'd1 :
                         state==ARM ? 3'd2 : 3'd3;
    assign owner_busy = !sfc_owner && !arm_owner;
    assign gpio_cfg_request = live && state==CONFIG;
    assign gpio_cfg_target_arm = target_arm;
    always @(posedge sys_clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ISO; target_arm <= 1'b1;
            config_seen_low <= 1'b0; guard_count <= 3'd0;
        end else if (!enabled) begin
            state <= ISO; target_arm <= 1'b1;
            config_seen_low <= 1'b0; guard_count <= 3'd0;
        end else case(state)
            ISO: begin
                if (cycle_idle) begin
                    target_arm <= req_sync;
                    state <= QUIET;
                end
            end
            HOST: if (req_sync && quiesce_sync && cycle_idle) begin
                target_arm <= 1'b1; state <= QUIET;
            end
            ARM: if (!req_sync && cycle_idle) begin
                target_arm <= 1'b0; state <= QUIET;
            end
            QUIET: if (cycle_idle) begin
                // Force acknowledgment low for a complete CONFIG phase
                // before accepting an acknowledgment rising high.
                config_seen_low <= 1'b0; state <= CONFIG;
            end
            CONFIG: begin
                if (!done_sync) config_seen_low <= 1'b1;
                if (config_seen_low && done_sync) begin
                    guard_count <= 3'd4; state <= GUARD;
                end
            end
            GUARD: if (guard_count == 3'd0) begin
                state <= target_arm ? ARM : HOST;
            end else guard_count <= guard_count - 3'd1;
            default: state <= ISO;
        endcase
    end
    // 24-bit logical CPU address is assembled from 13 direct input pins and
    // 11 readback pins driven by 74LVC16244. This does not consume extra pads.
    wire [23:0] host_addr = {sfc_a20_23,host_mem_a16_19,
                             sfc_a12_15,host_mem_a5_11,sfc_a0_4};
    wire a12=sfc_a12_15[0], a13=sfc_a12_15[1];
    wire a14=sfc_a12_15[2], a15=sfc_a12_15[3];
    wire a20=sfc_a20_23[0],a21=sfc_a20_23[1];
    wire a22=sfc_a20_23[2],a23=sfc_a20_23[3];
    wire io_window = !a22 && !a15 && a14 && !a13 && a12;
    wire ram_window = !a22 && !a15 && a14 && a13 &&
                     ((a21 && hi_enable) || (a23 && ex_enable));
    wire reg_sel = live && sfc_reset_n && extension_enable && io_window;
    wire host_ram = sfc_active && ram_window;
    wire host_rom = sfc_active && !boot_mode && !romsel_n &&
                    !io_window && !ram_window;
    reg boot_address;
    reg [7:0] boot_byte;
    always @* begin
        boot_address = 1'b1;
        case(host_addr)
            24'h00fffc: boot_byte = 8'h00;
            24'h00fffd: boot_byte = 8'h80;
            24'h008000: boot_byte = 8'h5c;
            24'h008001: boot_byte = 8'h00;
            24'h008002: boot_byte = 8'h60;
            24'h008003: boot_byte = 8'h2f;
            default: begin boot_address=1'b0; boot_byte=8'h00; end
        endcase
    end
    assign boot_hit = sfc_active && boot_mode && !romsel_n &&
                      boot_address && !ram_window && !io_window;
    wire [2:0] x = {(!a23 && exhirom_enable),a21,a20};
    wire [2:0] n = rom_blocks_m1;
    wire [2:0] y;
    assign y[2] = x[2] && n[2];
    assign y[1] = x[1] && (n[1] || (n[2] && !x[2]));
    assign y[0] = x[0] && (n[0] || (n[1] && !x[1]) || (n[2] && !x[2]));
    wire [22:0] host_mem_address = {y,host_mem_a16_19,
                                  sfc_a12_15,host_mem_a5_11,sfc_a0_4};
    assign mem_addr_out = arm_owner ? arm_mem_addr : host_mem_address;
    // Only 12 host address pads are UDB-driven: A0..4,A12..15,A20..22.
    // A5..11,A16..19 are 3SB-driven (A19 is specifically NOT remapped).
    assign mem_addr_oe = arm_owner ? 23'h7fffff :
                         sfc_active ? 23'h70f01f : 23'h000000;
    assign buf_oe_n = !sfc_active;
    wire arm_rd = arm_owner && arm_mem_ce && arm_mem_rd && !arm_mem_wr;
    wire arm_wr = arm_owner && arm_mem_ce && arm_mem_wr && !arm_mem_rd;
    wire arm_rom = arm_owner && arm_mem_ce && !arm_mem_ram;
    wire arm_ram = arm_owner && arm_mem_ce && arm_mem_ram;
    assign ce_rom_n = !(host_rom || arm_rom);
    assign ce_ram_n = !(host_ram || arm_ram);
    assign mem_oe_n = !((sfc_rd && (host_rom || host_ram)) || arm_rd);
    assign mem_we_n = !((sfc_wr && host_ram) || arm_wr);
    assign mem_data_oe = (sfc_wr && host_ram) || arm_wr;
    assign mem_data_out = arm_owner ? arm_mem_wdata : sfc_data_in;
    // Command mailbox: bundle held until ARM acknowledgment. SFC /WR rising
    // edge is used only to capture stable host data and toggle the request.
    reg cmd_seq, seq_m, seq_s, ack_seq, ack_m, ack_s;
    wire busy = cmd_seq ^ ack_s;
    assign arm_cmd_valid = seq_s ^ ack_seq;
    wire [4:0] reg_idx = sfc_a0_4;
    reg mailbox_writable;
    reg [2:0] mailbox_kind;
    always @* begin
        mailbox_writable = 1'b1; mailbox_kind = 3'd0;
        case(reg_idx)
            5'h00: mailbox_kind=3'd0;
            5'h03: mailbox_kind=3'd1;
            5'h07: mailbox_kind=3'd2;
            5'h08: mailbox_kind=3'd3;
            5'h09: mailbox_kind=3'd4;
            5'h0a: mailbox_kind=3'd5;
            default: mailbox_writable=1'b0;
        endcase
    end
    always @(posedge wr_n or negedge rst_n) begin
        if (!rst_n) begin
            cmd_data<=0; cmd_kind<=0; cmd_seq<=0;
        end else if (reg_sel && mailbox_writable && !busy) begin
            cmd_data<=sfc_data_in;cmd_kind<=mailbox_kind;cmd_seq<=!cmd_seq;
        end
    end
    always @(posedge sys_clk or negedge rst_n) begin
        if (!rst_n) begin
            seq_m<=0;seq_s<=0;ack_seq<=0;ack_m<=0;ack_s<=0;
        end else begin
            seq_m<=cmd_seq; seq_s<=seq_m;
            if (arm_cmd_valid && arm_cmd_ack) ack_seq<=seq_s;
            ack_m<=ack_seq;ack_s<=ack_m;
        end
    end
    // SFC strobe-end captures; events cross via 2-FF toggle synchronizers.
    // Every new SFC transfer must be separated by >= 3 sys_clk periods,
    // satisfied by the specified 372.5 ns SFC DMA cycle at 40MHz.
    // The captured 8-bit datum stays stable until the next /WR edge.
    reg [7:0] tx_latch;
    reg tx_toggle, rx_pop_toggle, rx_empty_toggle;
    reg [7:0] rx_read_snapshot;
    reg rx_read_valid;
    always @(posedge wr_n or negedge rst_n) begin
        if (!rst_n) begin tx_latch<=0;tx_toggle<=0; end
        else if (reg_sel && reg_idx==5'h04) begin
            tx_latch<=sfc_data_in;tx_toggle<=!tx_toggle;
        end
    end
    // Snapshot FIFO output on /RD assertion. A newly arriving ARM byte can
    // never change the value halfway through an SFC bus read.
    always @(negedge rd_n or negedge rst_n) begin
        if (!rst_n) begin rx_read_snapshot<=0;rx_read_valid<=0;end
        else if (reg_sel && reg_idx==5'h05) begin
            rx_read_snapshot<=rx_head;
            rx_read_valid<=!rx_empty;
        end
    end
    always @(posedge rd_n or negedge rst_n) begin
        if (!rst_n) begin rx_pop_toggle<=0;rx_empty_toggle<=0;end
        else if (reg_sel && reg_idx==5'h05) begin
            if (rx_read_valid) rx_pop_toggle<=!rx_pop_toggle;
            else rx_empty_toggle<=!rx_empty_toggle;
        end
    end
    reg tx_m,tx_s,tx_prev,rx_m,rx_s,rx_prev;
    reg re_m,re_s,re_prev;
    wire tx_event = tx_s ^ tx_prev;
    wire rx_event = rx_s ^ rx_prev;
    wire rx_empty_event = re_s ^ re_prev;
    wire tx_full,tx_empty,rx_full,rx_empty;
    wire [7:0] rx_head;
    reg tx_overrun,rx_underrun;
    // Full/empty of the synchronous FIFO are always updated by sys_clk,
    // including when SFC is idle. The ARM DMA stream uses the same domain.
    wire tx_push = tx_event && (!tx_full || tx_pop);
    wire tx_pop = arm_tx_ready && !tx_empty;
    wire rx_push = arm_rx_valid && !rx_full;
    wire rx_pop = rx_event && !rx_empty;
    fifo4_sync fifo_tx (
       .clk(sys_clk),.rst_n(rst_n),.push(tx_push),.push_data(tx_latch),
       .pop(tx_pop),.head_data(arm_tx_data),.full(tx_full),.empty(tx_empty)
    );
    fifo4_sync fifo_rx (
       .clk(sys_clk),.rst_n(rst_n),.push(rx_push),.push_data(arm_rx_data),
       .pop(rx_pop),.head_data(rx_head),.full(rx_full),.empty(rx_empty)
    );
    assign arm_tx_valid = !tx_empty;
    assign arm_rx_ready = !rx_full;
    assign fifo_status = {2'b00,rx_underrun,tx_overrun,
                          rx_full,rx_empty,tx_empty,tx_full};
    always @(posedge sys_clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_m<=0;tx_s<=0;tx_prev<=0;
            rx_m<=0;rx_s<=0;rx_prev<=0;
            re_m<=0;re_s<=0;re_prev<=0;
            tx_overrun<=0;rx_underrun<=0;
        end else begin
            tx_m<=tx_toggle;tx_s<=tx_m;tx_prev<=tx_s;
            rx_m<=rx_pop_toggle;rx_s<=rx_m;rx_prev<=rx_s;
            re_m<=rx_empty_toggle;re_s<=re_m;re_prev<=re_s;
            if (tx_event && tx_full && !tx_pop) tx_overrun<=1;
            if (rx_empty_event) rx_underrun<=1;
        end
    end
    // Read-side head is the FIFO front (FWFT). Remains stable throughout
    // each /RD-low interval; FIFO advances only after /RD rises.
    reg [7:0] reg_rdata;
    reg reg_readable;
    always @* begin
        reg_rdata=0;reg_readable=1;
        case(reg_idx)
            5'h01:reg_rdata={5'b0,arm_irq_pending,arm_owner,busy};
            5'h02:reg_rdata=arm_reply;
            5'h03:reg_rdata={6'b0,owner_busy,arm_owner};
            5'h05:reg_rdata=rx_read_valid ? rx_read_snapshot : 8'h00;
            5'h06:reg_rdata=fifo_status;
            5'h07:reg_rdata={7'b0,arm_irq_mask};
            5'h08:reg_rdata={7'b0,arm_irq_pending};
            5'h09:reg_rdata=arm_length[7:0];
            5'h0a:reg_rdata=arm_length[15:8];
            5'h0b:reg_rdata=arm_error;
            default:reg_readable=0;
        endcase
    end
    assign sfc_data_oe = sfc_rd && (boot_hit || host_rom || host_ram ||
                                   (reg_sel && reg_readable));
    always @* begin
        sfc_data_out=0;
        if(boot_hit) sfc_data_out=boot_byte;
        else if(host_rom || host_ram) sfc_data_out=mem_data_in;
        else if(reg_sel && reg_readable) sfc_data_out=reg_rdata;
    end
    assign irq_assert = sfc_active && extension_enable &&
                        arm_irq_mask && arm_irq_pending;
endmodule

// Behavioral FIFO contract for two UDB datapath FIFO channels, 4 bytes each.
// For Creator, replace storage/counters with UDB datapath F0/F1 native FIFOs.
// Same clk for both producer/consumer; no independent clock domains inside.
module fifo4_sync (
    input wire clk,rst_n,push,
    input wire [7:0] push_data,
    input wire pop,
    output wire [7:0] head_data,
    output wire full,empty
);
    reg [7:0] q[0:3];
    reg [1:0] wptr,rptr;
    reg [2:0] count;
    wire do_pop = pop && (count!=0);
    wire do_push = push && ((count!=4) || do_pop);
    assign full = (count == 4);
    assign empty = (count == 0);
    assign head_data = empty ? 8'h00 : q[rptr];
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wptr<=0;rptr<=0;count<=0;
        end else begin
            if (do_push) begin q[wptr]<=push_data;wptr<=wptr+2'd1;end
            if (do_pop) rptr<=rptr+2'd1;
            case ({do_push,do_pop})
                2'b10:count<=count+3'd1;
                2'b01:count<=count-3'd1;
                default:count<=count;
            endcase
        end
    end
endmodule
`default_nettype wire