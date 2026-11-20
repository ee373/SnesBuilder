// PCM ingestion and FIR share the fabric clock. DSM runs from the crystal.
module sfcbuilder_audio (
    input bus_clock, audio_dsm_clock, resetn,
    input power_service, control_write, pcm_write,
    input [31:0] write_data,
    output wire pcm_full,
    output reg enabled,
    output wire [7:0] fifo_status,
    output wire underrun,
    output wire left_dsm, right_dsm
);
    // Assert reset immediately. Release it on the destination clock.
    (* async_reg = "true", keep = "true" *) reg [1:0] fir_reset, dsm_reset;
    reg fir_underrun;
    always @(posedge bus_clock or negedge resetn)
        if (!resetn) fir_reset <= 0;
        else fir_reset <= {fir_reset[0],1'b1};
    always @(posedge audio_dsm_clock or negedge resetn)
        if (!resetn) dsm_reset <= 0;
        else dsm_reset <= {dsm_reset[0],1'b1};

    (* async_reg = "true", keep = "true" *) reg [1:0] fir_enable, dsm_enable, under_bus;
    always @(posedge bus_clock or negedge resetn) begin
        if (!resetn) begin
            enabled <= 0;
            under_bus <= 0;
        end else begin
            under_bus <= {under_bus[0],fir_underrun};
            if (power_service) enabled <= 0;
            else if (control_write) enabled <= write_data[0];
        end
    end
    always @(posedge bus_clock or negedge fir_reset[1])
        if (!fir_reset[1]) fir_enable <= 0;
        else fir_enable <= {fir_enable[0],enabled};
    always @(posedge audio_dsm_clock or negedge dsm_reset[1])
        if (!dsm_reset[1]) dsm_enable <= 0;
        else dsm_enable <= {dsm_enable[0],enabled};

    wire [6:0] pcm_used;
    wire [31:0] pcm;
    wire pcm_empty, pcm_pop;
    assign fifo_status = {pcm_full,pcm_used};
    assign underrun = under_bus[1];
    sfcbuilder_pcm_fifo pcm_fifo (
        .clk(bus_clock), .resetn(resetn), .push(pcm_write), .write_data(write_data),
        .full(pcm_full), .used(pcm_used), .pop(pcm_pop), .read_data(pcm), .empty(pcm_empty)
    );

    // Keep 320 kHz frames and 64 kHz PCM input at a 80 MHz fabric clock.
    localparam [8:0] LAST_TICK = 9'd249, FILTER_TICK = 9'd244;
    reg [8:0] fir_tick;
    reg [2:0] pcm_phase;
    reg frame_playing, pcm_taken;
    (* keep = "true" *) reg frame_start;
    assign pcm_pop = frame_start && pcm_phase == 0 && fir_enable[1] && !pcm_empty;
    always @(posedge bus_clock or negedge fir_reset[1]) begin
        if (!fir_reset[1]) begin
            fir_tick <= 0;
            frame_start <= 1;
            pcm_phase <= 0;
            frame_playing <= 0;
            pcm_taken <= 0;
            fir_underrun <= 0;
        end else begin
            fir_tick <= fir_tick == LAST_TICK ? 9'd0 : fir_tick + 1'b1;
            frame_start <= fir_tick == LAST_TICK;
            if (frame_start) begin
                frame_playing <= fir_enable[1];
                pcm_taken <= pcm_pop;
                if (fir_enable[1] && pcm_phase == 0 && pcm_empty)
                    fir_underrun <= 1;
            end
            if (!fir_enable[1]) fir_underrun <= 0;
            if (fir_tick == LAST_TICK)
                pcm_phase <= !frame_playing || !fir_enable[1] || pcm_phase == 4 ?
                             3'd0 : pcm_phase + 1'b1;
        end
    end

    wire [16:0] filtered_l, filtered_r;
    sfcbuilder_audio_fir fir (
        bus_clock, fir_reset[1], frame_playing, fir_tick, pcm_phase,
        pcm_taken ? pcm : 32'd0, filtered_l, filtered_r
    );

    // The reader starts with two words in reserve. Both sample rates derive
    // from the same crystal, but neither interface relies on PLL phase.
    wire filter_full, filter_empty, filter_prefilled;
    wire [33:0] filtered;
    reg [4:0] dsm_tick;
    reg dsm_started, filter_taken;
    wire filter_pop = dsm_started && dsm_tick == 0 && !filter_empty;
    sfcbuilder_audio_fifo #(34,2) filter_fifo (
        .write_clk(bus_clock), .write_resetn(fir_reset[1]),
        .push(fir_tick == FILTER_TICK && !filter_full),
        .write_data(frame_playing ? {filtered_r,filtered_l} : 34'd0),
        .full(filter_full), .used(),
        .read_clk(audio_dsm_clock), .read_resetn(dsm_reset[1]),
        .pop(filter_pop), .read_data(filtered), .empty(filter_empty),
        .prefilled(filter_prefilled)
    );
    always @(posedge audio_dsm_clock or negedge dsm_reset[1]) begin
        if (!dsm_reset[1]) begin
            dsm_tick <= 0;
            dsm_started <= 0;
            filter_taken <= 0;
        end else if (dsm_started) begin
            dsm_tick <= dsm_tick == 24 ? 5'd0 : dsm_tick + 1'b1;
            if (dsm_tick == 0) filter_taken <= filter_pop;
        end else if (filter_prefilled) dsm_started <= 1;
    end
    wire dsm_prepare = dsm_started && dsm_tick == 1;
    wire dsm_apply = dsm_started && dsm_tick == 24;
    wire dsm_step = dsm_started && dsm_tick != 24;
    wire [16:0] dsm_l, dsm_r;
    assign dsm_l = filter_taken ? filtered[16:0] : 17'd0;
    assign dsm_r = filter_taken ? filtered[33:17] : 17'd0;
    sfcbuilder_audio_dsm left_mod(audio_dsm_clock,dsm_reset[1],dsm_enable[1],{dsm_l,2'b0},left_dsm);
    sfcbuilder_audio_dsm right_mod(audio_dsm_clock,dsm_reset[1],dsm_enable[1],{dsm_r,2'b0},right_dsm);
endmodule

// The PCM buffer has one clock. A full buffer rejects the AHB write
// even when a concurrent read will make room on the same edge.
module sfcbuilder_pcm_fifo (
    input clk, resetn, push,
    input [31:0] write_data,
    output full,
    output reg [6:0] used,
    input pop,
    output reg [31:0] read_data,
    output empty
);
    (* ram_style = "block" *) reg [31:0] entries [0:63];
    reg [5:0] write_pos, read_pos;
    wire write_word = push && !full;
    wire read_word = pop && !empty;
    assign full = used[6];
    assign empty = used == 0;
    always @(posedge clk) begin
        if (write_word)
            entries[write_pos] <= write_data;
        if (read_word)
            read_data <= entries[read_pos];
    end
    always @(posedge clk or negedge resetn) begin
        if (!resetn)
            {write_pos,read_pos,used} <= 0;
        else begin
            if (write_word) write_pos <= write_pos + 1'b1;
            if (read_word) read_pos <= read_pos + 1'b1;
            case ({write_word,read_word})
                2'b10: used <= used + 1'b1;
                2'b01: used <= used - 1'b1;
                default: ;
            endcase
        end
    end
endmodule

// Dual-clock synchronous-read RAM with Gray-coded pointer crossings.
module sfcbuilder_audio_fifo #(parameter BITS=32, ADDR=6) (
    input write_clk, write_resetn, push,
    input [BITS-1:0] write_data,
    output wire full,
    output wire [ADDR:0] used,
    input read_clk, read_resetn, pop,
    output reg [BITS-1:0] read_data,
    output wire empty, prefilled
);
    localparam [ADDR:0] DEPTH = 1 << ADDR;
    (* ram_style = "block" *) reg [BITS-1:0] entries [0:(1<<ADDR)-1];
    reg [ADDR:0] write_pos, read_pos;
    (* keep = "true" *) reg [ADDR:0] write_gray, read_gray;
    (* async_reg = "true", keep = "true" *) reg [ADDR:0] read_meta, read_sync, write_meta, write_sync;
    wire [ADDR:0] write_next = write_pos + 1'b1;
    wire [ADDR:0] read_next = read_pos + 1'b1;
    function [ADDR:0] from_gray(input [ADDR:0] value);
        integer i;
        begin
            from_gray[ADDR] = value[ADDR];
            for (i=ADDR-1; i>=0; i=i-1) from_gray[i] = from_gray[i+1] ^ value[i];
        end
    endfunction
    wire accepted_write = push && !full;
    wire [ADDR:0] write_next_gray = write_next ^ (write_next >> 1);
    // Full means the binary pointers differ by DEPTH. In Gray code,
    // toggling the highest two bits advances a power-of-two FIFO by DEPTH.
    wire [ADDR:0] full_limit = read_sync ^ (DEPTH | (DEPTH >> 1));
    assign full = write_gray == full_limit;
    assign used = write_pos - from_gray(read_sync);
    assign empty = write_sync == read_gray;
    wire [ADDR:0] read_used = from_gray(write_sync) - read_pos;
    assign prefilled = read_used >= 2;
    always @(posedge write_clk) if (accepted_write) entries[write_pos[ADDR-1:0]] <= write_data;
    always @(posedge read_clk) if (pop && !empty) read_data <= entries[read_pos[ADDR-1:0]];
    always @(posedge write_clk or negedge write_resetn) begin
        if (!write_resetn) {write_pos,write_gray,read_meta,read_sync} <= 0;
        else begin
            {read_sync,read_meta} <= {read_meta,read_gray};
            if (accepted_write) begin
                write_pos <= write_next;
                write_gray <= write_next_gray;
            end
        end
    end
    always @(posedge read_clk or negedge read_resetn) begin
        if (!read_resetn) {read_pos,read_gray,write_meta,write_sync} <= 0;
        else begin
            {write_sync,write_meta} <= {write_meta,write_gray};
            if (pop && !empty) begin
                read_pos <= read_next;
                read_gray <= read_next ^ (read_next >> 1);
            end
        end
    end
endmodule

// Divide the signed endpoint difference once. Distribute the remainder
// across the steps so the ramp reaches the next endpoint exactly.
module sfcbuilder_audio_ramp #(parameter DIVISOR=5) (
    input clk, resetn, clear, prepare, apply, step,
    input signed [18:0] destination,
    output reg signed [18:0] value
);
    localparam REM_BITS = $clog2(DIVISOR);
    localparam [REM_BITS:0] DEN = DIVISOR;
    reg signed [18:0] target, base, increment;
    reg [18:0] quotient;
    reg [4:0] remaining;
    reg [REM_BITS-1:0] remainder, step_remainder, ramp_error;
    wire signed [19:0] difference = destination - target;
    wire [REM_BITS:0] trial = {remainder,quotient[18]};
    wire subtract = trial >= DEN;
    wire [REM_BITS:0] divided_remainder = subtract ? trial - DEN : trial;
    wire [REM_BITS:0] next_error = {1'b0,ramp_error} + {1'b0,step_remainder};
    wire carry_error = next_error >= DEN;
    wire [REM_BITS:0] reduced_error = carry_error ? next_error - DEN : next_error;
    wire [19:0] next_value = {value,1'b1} + {increment,carry_error};
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            {target,base,increment,value,quotient,remaining,remainder,
             step_remainder,ramp_error} <= 0;
        end else if (clear) begin
            {target,base,increment,value,remaining,remainder,step_remainder,ramp_error} <= 0;
        end else begin
            if (prepare) begin
                base <= target;
                target <= destination;
                // Seeding a negative input with DIVISOR-1 makes the
                // unsigned result equal floor(difference/DIVISOR)+2^19.
                quotient <= difference[18:0];
                remainder <= difference[19] ? DIVISOR-1 : 0;
                remaining <= 19;
            end else if (remaining != 0) begin
                quotient <= {quotient[17:0],subtract};
                remainder <= divided_remainder[REM_BITS-1:0];
                remaining <= remaining - 1'b1;
            end
            if (apply) begin
                value <= base;
                increment <= quotient;
                step_remainder <= remainder;
                ramp_error <= 0;
            end else if (step) begin
                value <= next_value[19:1];
                ramp_error <= reduced_error[REM_BITS-1:0];
            end
        end
    end
endmodule


module sfcbuilder_audio_fir (
    input clk, resetn, playing,
    input [8:0] tick,
    input [2:0] phase,
    input [31:0] sample_word,
    output reg [16:0] left_result, right_result
);
    function signed [11:0] coeff_lut(input [6:0] pos);
        case(pos)
            7'd1: coeff_lut = 12'sd59;
            7'd2: coeff_lut = 12'sd20;
            7'd3: coeff_lut = -12'sd162;
            7'd4: coeff_lut = 12'sd1941;
            7'd5: coeff_lut = 12'sd230;
            7'd6: coeff_lut = -12'sd166;
            7'd7: coeff_lut = 12'sd141;
            7'd8: coeff_lut = -12'sd15;
            7'd16: coeff_lut = -12'sd15;
            7'd17: coeff_lut = 12'sd141;
            7'd18: coeff_lut = -12'sd166;
            7'd19: coeff_lut = 12'sd230;
            7'd20: coeff_lut = 12'sd1941;
            7'd21: coeff_lut = -12'sd162;
            7'd22: coeff_lut = 12'sd20;
            7'd23: coeff_lut = 12'sd59;
            7'd32: coeff_lut = -12'sd20;
            7'd33: coeff_lut = 12'sd196;
            7'd34: coeff_lut = -12'sd337;
            7'd35: coeff_lut = 12'sd736;
            7'd36: coeff_lut = 12'sd1695;
            7'd37: coeff_lut = -12'sd384;
            7'd38: coeff_lut = 12'sd145;
            7'd39: coeff_lut = 12'sd17;
            7'd48: coeff_lut = -12'sd10;
            7'd49: coeff_lut = 12'sd203;
            7'd50: coeff_lut = -12'sd431;
            7'd51: coeff_lut = 12'sd1262;
            7'd52: coeff_lut = 12'sd1262;
            7'd53: coeff_lut = -12'sd431;
            7'd54: coeff_lut = 12'sd203;
            7'd55: coeff_lut = -12'sd10;
            7'd64: coeff_lut = 12'sd17;
            7'd65: coeff_lut = 12'sd145;
            7'd66: coeff_lut = -12'sd384;
            7'd67: coeff_lut = 12'sd1695;
            7'd68: coeff_lut = 12'sd736;
            7'd69: coeff_lut = -12'sd337;
            7'd70: coeff_lut = 12'sd196;
            7'd71: coeff_lut = -12'sd20;
            default: coeff_lut = 0;
        endcase
    endfunction
    // addresses 0..15 hold PCM. Each additional 16-word section holds one phase.
    (* ram_style = "block" *) reg [31:0] history [0:127];
    integer k;
    initial for (k=0; k<128; k=k+1)
        history[k] = k>=16 ? {20'b0,coeff_lut(k-16)} : 32'd0;
    reg [31:0] history_q;
    reg [3:0] head;
    reg [4:0] used;
    wire [2:0] slot = tick[2:0];
    wire right = tick>=80;
    wire [3:0] tap = right ? tick[6:3]-4'd10 : tick[6:3]-1'b1;
    wire [2:0] coefficient_page = phase + 1'b1;
    wire valid_group = playing && tick>=8 && tick<152;
    // Prepare the RAM request one cycle before the existing sample/coeff reads.
    // At slot 7 the next product starts, so use its tap with the current head.
    wire [3:0] next_tap = tick>=79 ? tick[6:3]-4'd9 : tick[6:3];
    (* keep = "true" *) reg [6:0] history_read_address;
    (* keep = "true" *) reg history_read_enable;
    // Bind the metadata to the BRAM sample read at slot 0. Slot 1 only
    // selects the registered result and never recomputes the tap comparison.
    (* keep = "true" *) reg sample_present_q, sample_right_q;
    (* keep = "true" *) reg [3:0] sample_tap_q;
    always @(posedge clk) begin
        // Slot 7 computes the same next tap used for the sample RAM address.
        // Slot 0 can check history depth without the tap arithmetic.
        sample_tap_q <= next_tap;
        sample_present_q <= used[4] || sample_tap_q < used[3:0];
        sample_right_q <= right;
        history_read_enable <= playing && tick>=7 && tick<151 && (slot==7 || slot==0);
        history_read_address <= slot==0 ? {coefficient_page,tap} : {3'b0,head-next_tap};
        if (playing && tick==1 && phase==0)
            history[{3'b0,head+4'd1}] <= sample_word;
        if (history_read_enable)
            history_q <= history[history_read_address];
    end
    reg signed [15:0] sample;
    reg signed [11:0] coeff;
    reg signed [17:0] digit_product;
    reg signed [27:0] horner,product;
    reg [15:0] sum_low;
    reg [11:0] sum_high;
    (* keep = "true" *) reg carry;
    // Each phase's coefficient L1 norm is below 4096, so a 16-bit
    // input and the unchanged coefficient ROM fit every sum in 28 bits.
    wire signed [27:0] accum = {sum_high,sum_low};
    wire [11:0] product_high = product[27:16];
    wire [16:0] add_low = {1'b0,sum_low}+{1'b0,product[15:0]};
    wire [12:0] add_high = {sum_high,1'b1}+{product_high,carry};
    // Select each radix-4 digit a cycle before its multiply. The first
    // digit is prepared directly from the RAM output on the coefficient read.
    (* keep = "true" *) reg signed [2:0] signed_digit;
    always @(posedge clk) begin
        case (slot)
            2: signed_digit <= {history_q[11],history_q[11:10]};
            3: signed_digit <= {1'b0,coeff[9:8]};
            4: signed_digit <= {1'b0,coeff[7:6]};
            5: signed_digit <= {1'b0,coeff[5:4]};
            6: signed_digit <= {1'b0,coeff[3:2]};
            default: signed_digit <= {1'b0,coeff[1:0]};
        endcase
    end
    // Register the arithmetic window before applying the slot decode.
    (* keep = "true" *) reg horner_active_q;
    always @(posedge clk or negedge resetn) begin
        if (!resetn)
            horner_active_q <= 1'b0;
        else if (tick == 11)
            horner_active_q <= 1'b1;
        else if (tick == 153)
            horner_active_q <= 1'b0;
    end
    wire signed [27:0] next_product=(horner <<< 2)+digit_product;
    // Round the FIR result to one fractional bit above the signed 16-bit
    // PCM scale. The 12-bit coefficient normalization stays at Q11.
    wire [16:0] rounded=accum[26:10]+{16'b0,accum[9]};
    wire threshold=&accum[25:9];
    wire clip_high=!accum[27] && (accum[26] || threshold);
    wire clip_low=accum[27] && !accum[26] && !threshold;
    wire [16:0] limited=clip_high ? 17'h0ffff : clip_low ? 17'h10000 : rounded;
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            {head,used,sample,coeff,digit_product,horner,product,sum_low,sum_high,carry,left_result,right_result}<=0;
        end else if (!playing) begin
            used<=0;
        end else begin
            if (tick==1 && phase==0) begin
                head<=head+1'b1;
                if (used!=16) used<=used+1'b1;
            end
            if (valid_group && slot==1)
                sample<=sample_present_q ? (sample_right_q ? history_q[31:16] : history_q[15:0]) : 16'd0;
            if (valid_group && slot==2)
                coeff<=history_q[11:0];
            if (tick>=11 && tick<=152 && (slot>=3 || slot==0))
                digit_product<=sample*signed_digit;
            if (horner_active_q) begin
                case(slot)
                    4: horner<=digit_product;
                    5,6,7,0: horner<=next_product;
                    1: product<=next_product;
                    default: ;
                endcase
            end
            if (tick>=18 && tick<=154 && slot==2)
                {carry,sum_low}<=tick==18 || tick==90 ? {1'b0,product[15:0]} : add_low;
            if (tick>=19 && tick<=155 && slot==3)
                sum_high<=tick==19 || tick==91 ? product_high : add_high[12:1];
            if (tick==84) left_result<=limited;
            if (tick==156) right_result<=limited;
        end
    end
endmodule

// Three cascaded integrators with feedback implement
// NTF=(1-z^-1)^3/(1-0.75z^-1)^3. The stage scalings are 64, 16 and 4.
// Quantizer full scale is twice the maximum PCM amplitude for loop margin.
module sfcbuilder_audio_dsm (
    input clk, resetn, enable,
    input signed [18:0] pcm,
    output reg bit_out
);
    reg signed [23:0] s1, s2, s3;
    wire high = !s3[23];
    // Feedback lies on a bit boundary. Add the lower bits once and
    // include the feedback in the upper guard bits.
    function [23:0] integrate(
        input [23:0] state,
        input [23:0] increment,
        input polarity,
        input [4:0] weight
    );
        reg [19:0] low;
        reg [4:0] high_sum;
        begin
            low = {1'b0,state[18:0]} + {1'b0,increment[18:0]};
            high_sum = state[23:19] + increment[23:19] + {4'b0,low[19]} +
                       (polarity ? -weight : weight);
            integrate = {high_sum,low[18:0]};
        end
    endfunction
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            {s1,s2,s3,bit_out} <= 0;
        end else if (!enable) begin
            {s1,s2,s3,bit_out} <= 0;
        end else begin
            bit_out <= high;
            s1 <= integrate(s1,{{5{pcm[18]}},pcm},high,5'd1);
            s2 <= integrate(s2,s1 >>> 2,high,5'd3);
            s3 <= integrate(s3,s2 >>> 2,high,5'd3);
        end
    end
endmodule
