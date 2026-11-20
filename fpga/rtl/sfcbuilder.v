`define SFCBUILDER_AUDIO
`ifdef SFCBUILDER_AUDIO
`include "sfcbuilder_audio.v"
`endif

module sfcbuilder (
  output wire        DAC0_AUDIO_L,
  output wire        DAC1_AUDIO_R,
  output wire        MEM_A0,
  output wire        MEM_A1,
  output wire        MEM_A10,
  output wire        MEM_A11,
  output wire        MEM_A12,
  output wire        MEM_A13,
  output wire        MEM_A14,
  output wire        MEM_A15,
  output wire        MEM_A16,
  output wire        MEM_A17,
  output wire        MEM_A18,
  output wire        MEM_A19,
  output wire        MEM_A2,
  output wire        MEM_A20,
  output wire        MEM_A21,
  output wire        MEM_A22,
  output wire        MEM_A3,
  output wire        MEM_A4,
  output wire        MEM_A5,
  output wire        MEM_A6,
  output wire        MEM_A7,
  output wire        MEM_A8,
  output wire        MEM_A9,
  inout              MEM_D0,
  inout              MEM_D1,
  inout              MEM_D2,
  inout              MEM_D3,
  inout              MEM_D4,
  inout              MEM_D5,
  inout              MEM_D6,
  inout              MEM_D7,
  output wire        MEM_nCE_RAM,
  output wire        MEM_nCE_ROM,
  output wire        MEM_nOE,
  output wire        MEM_nWE,
  input              POWER_FAIL,
  input              SD_MISO,
  output wire        SD_nCS,
  input              SFC_A0,
  input              SFC_A1,
  input              SFC_A12,
  input              SFC_A13,
  input              SFC_A14,
  input              SFC_A15,
  input              SFC_A16,
  input              SFC_A17,
  input              SFC_A18,
  input              SFC_A19,
  input              SFC_A2,
  input              SFC_A20,
  input              SFC_A21,
  input              SFC_A22,
  input              SFC_A23,
  input              SFC_A3,
  input              SFC_A4,
  input              SFC_A5,
  inout              SFC_nIRQ_OD,
  input              SFC_nRD,
  inout              SFC_nRESET_OD,
  input              SFC_nROMSEL,
  input              SFC_nWR,
  output wire        SPI_NOR_nCS,
  output wire        U1_nOE,
  output wire        U5_nOE_FET,
  output wire        U6_nOE,
  input              USB_VBUS_SENSE,
  output wire        spi_miso_in,
  input              spi_sel0_out_data,
  input              spi_sel0_out_en,
  input              spi_sel1_out_data,
  input              spi_sel1_out_en,
  input              sys_clock,
  input              bus_clock,
`ifdef SFCBUILDER_AUDIO
  input              audio_fir_clock_out_data,
  input              audio_fir_clock_out_en,
  input              audio_dsm_clock_out_data,
  input              audio_dsm_clock_out_en,
`endif
  input              resetn,
  input              stop,
  input       [1:0]  mem_ahb_htrans,
  input              mem_ahb_hready,
  input              mem_ahb_hwrite,
  input       [31:0] mem_ahb_haddr,
  input       [2:0]  mem_ahb_hsize,
  input       [2:0]  mem_ahb_hburst,
  input       [31:0] mem_ahb_hwdata,
  output wire        mem_ahb_hreadyout,
  output wire        mem_ahb_hresp,
  output wire [31:0] mem_ahb_hrdata,
  output wire        slave_ahb_hsel,
  output wire        slave_ahb_hready,
  input              slave_ahb_hreadyout,
  output wire [1:0]  slave_ahb_htrans,
  output wire [2:0]  slave_ahb_hsize,
  output wire [2:0]  slave_ahb_hburst,
  output wire        slave_ahb_hwrite,
  output wire [31:0] slave_ahb_haddr,
  output wire [31:0] slave_ahb_hwdata,
  input              slave_ahb_hresp,
  input       [31:0] slave_ahb_hrdata,
  output wire [3:0]  ext_dma_DMACBREQ,
  output wire [3:0]  ext_dma_DMACLBREQ,
  output wire [3:0]  ext_dma_DMACSREQ,
  output wire [3:0]  ext_dma_DMACLSREQ,
  input       [3:0]  ext_dma_DMACCLR,
  input       [3:0]  ext_dma_DMACTC,
  output wire [3:0]  local_int
);
// Cross one AHB beat at a time. The CPU and fabric hold their payloads
// stable until the opposite domain has observed the corresponding toggle.
localparam [2:0] CPU_IDLE=0, CPU_WAIT=2, CPU_ERR_FIRST=4,
                 CPU_PREPARE=5, CPU_RESP=6, CPU_CAPTURE=7;
localparam [1:0] FABRIC_IDLE=0, FABRIC_ADDR=1, FABRIC_DATA=2;
reg [2:0] cpu_phase;
(* keep = "true" *) reg sampled_htrans, address_window;
(* keep = "true" *) reg request_issue, error_start, ready_release;
wire address_pending = sampled_htrans && address_window;
(* keep = "true" *) reg response_arrived;
reg [1:0] fabric_phase;
reg request_toggle, response_toggle;
(* async_reg = "true" *) reg request_meta, request_sync, response_meta, response_sync;
reg [31:0] request_address, request_data, response_data;
reg [2:0] request_size;
reg request_write, response_error, cpu_ready, cpu_pending_error;
reg [31:0] sampled_address;
reg [2:0] sampled_size;
reg sampled_write;
reg [31:0] logic_ahb_haddr, logic_ahb_hwdata;
reg [2:0] logic_ahb_hsize;
reg logic_ahb_hwrite;
wire [3:0] fabric_interrupt;
(* async_reg = "true" *) reg [3:0] irq_meta, irq_sync;
(* keep = "true" *) reg [3:0] irq_pipe;
reg [3:0] irq_cpu;
reg [31:0] cpu_read_data;
wire [1:0] logic_ahb_htrans = fabric_phase == FABRIC_ADDR ? 2'b10 : 2'b00;
wire logic_ahb_hreadyout, logic_ahb_hresp;
wire logic_ahb_hready = logic_ahb_hreadyout;
wire [31:0] logic_ahb_hrdata;
wire cpu_error;
wire cpu_error_next = error_start || (cpu_error && !(cpu_ready && mem_ahb_hready));
`ifdef ALTA_SYN
(* keep = "true" *) dffeas #(.is_wysiwyg("TRUE"), .power_up("low")) cpu_hresp_ff (
    .d(cpu_error_next), .q(cpu_error), .clk(sys_clock),
    .clrn(resetn), .prn(1'b1), .ena(1'b1),
    .asdata(1'b0), .aload(1'b0), .sclr(1'b0), .sload(1'b0)
);
`else
reg cpu_error_q;
assign cpu_error = cpu_error_q;
always @(posedge sys_clock or negedge resetn)
    if (!resetn) cpu_error_q <= 0;
    else cpu_error_q <= cpu_error_next;
`endif

// Suppress ready as soon as an address is accepted. The address-phase
// valid bit is captured separately from the bridge's state enables.
assign mem_ahb_hreadyout = cpu_ready;
assign mem_ahb_hresp = cpu_error;
assign local_int = irq_cpu;
assign mem_ahb_hrdata = cpu_read_data;

always @(posedge sys_clock) begin
    sampled_address <= mem_ahb_haddr;
    sampled_size <= mem_ahb_hsize;
    sampled_write <= mem_ahb_hwrite;
end

// Keep the hard-IP ready return on a single registered output. The
// transfer handshake feeds only the ready/accept registers, not the
// enables on the bridge's address, data, or phase registers.
always @(posedge sys_clock or negedge resetn) begin
    if (!resetn) begin
        cpu_ready <= 1;
        sampled_htrans <= 0;
        address_window <= 0;
        request_issue <= 0;
        error_start <= 0;
        ready_release <= 0;
    end else begin
        cpu_ready <= ready_release ||
                     (cpu_ready && !(mem_ahb_hready && mem_ahb_htrans[1]));
        sampled_htrans <= mem_ahb_htrans[1];
        address_window <= cpu_ready && mem_ahb_hready;
        request_issue <= address_pending;
        error_start <= cpu_phase == CPU_PREPARE && cpu_pending_error;
        ready_release <= (cpu_phase == CPU_PREPARE && !cpu_pending_error) ||
                         (cpu_phase == CPU_RESP && cpu_pending_error);
    end
end

always @(posedge sys_clock or negedge resetn) begin
    if (!resetn) begin
        request_toggle <= 0;
        {request_address,request_data,request_size,request_write} <= 0;
    end else begin
        if (address_pending) begin
            request_address <= sampled_address;
            request_size <= sampled_size;
            request_write <= sampled_write;
        end
        // Low HREADYOUT extends the data phase before sampling HWDATA.
        if (request_issue) begin
            request_data <= mem_ahb_hwdata;
            request_toggle <= !request_toggle;
        end
    end
end

always @(posedge sys_clock or negedge resetn) begin
    if (!resetn) begin
        cpu_phase <= CPU_IDLE;
        cpu_pending_error <= 0;
        {irq_meta,irq_sync,irq_pipe,irq_cpu} <= 0;
        {response_meta,response_sync,cpu_read_data} <= 0;
        response_arrived <= 0;
    end else begin
        {response_sync,response_meta} <= {response_meta,response_toggle};
        // Qualify the toggle comparison with WAIT, so the equality for
        // the preceding request cannot release a newly issued transfer.
        response_arrived <= cpu_phase==CPU_WAIT && response_sync==request_toggle;
        {irq_cpu,irq_pipe,irq_sync,irq_meta} <= {irq_pipe,irq_sync,irq_meta,fabric_interrupt};
        case (cpu_phase)
            CPU_WAIT: if (response_arrived) cpu_phase <= CPU_CAPTURE;
            CPU_CAPTURE: begin
                cpu_read_data <= response_data;
                cpu_pending_error <= response_error;
                cpu_phase <= CPU_PREPARE;
            end
            // Leave one full wait cycle between storing the result and
            // enabling the registered ready/error sequence.
            CPU_PREPARE: cpu_phase <= CPU_RESP;
            CPU_RESP: cpu_phase <= cpu_pending_error ? CPU_ERR_FIRST : CPU_IDLE;
            CPU_ERR_FIRST: cpu_phase <= CPU_IDLE;
            default: if (request_issue) cpu_phase <= CPU_WAIT;
        endcase
    end
end

always @(posedge bus_clock or negedge resetn) begin
    if (!resetn) begin
        fabric_phase <= FABRIC_IDLE;
        response_toggle <= 0;
        {request_meta,request_sync,response_data,response_error} <= 0;
        {logic_ahb_haddr,logic_ahb_hsize,logic_ahb_hwrite,logic_ahb_hwdata} <= 0;
    end else begin
        {request_sync,request_meta} <= {request_meta,request_toggle};
        case (fabric_phase)
            FABRIC_IDLE: if (request_sync != response_toggle) begin
                logic_ahb_haddr <= request_address;
                logic_ahb_hsize <= request_size;
                logic_ahb_hwrite <= request_write;
                logic_ahb_hwdata <= request_data;
                fabric_phase <= FABRIC_ADDR;
            end
            FABRIC_ADDR: if (logic_ahb_hreadyout) fabric_phase <= FABRIC_DATA;
            FABRIC_DATA: if (logic_ahb_hreadyout) begin
                response_data <= logic_ahb_hrdata;
                response_error <= logic_ahb_hresp;
                response_toggle <= request_sync;
                fabric_phase <= FABRIC_IDLE;
            end
            default: fabric_phase <= FABRIC_IDLE;
        endcase
    end
end




// A6..A11 bypass the FPGA through U1. Boot matching intentionally ignores them.
wire [7:0] bank = {SFC_A23,SFC_A22,SFC_A21,SFC_A20,SFC_A19,SFC_A18,SFC_A17,SFC_A16};
wire [3:0] page = {SFC_A15,SFC_A14,SFC_A13,SFC_A12};
wire [5:0] offset = {SFC_A5,SFC_A4,SFC_A3,SFC_A2,SFC_A1,SFC_A0};
wire [7:0] mem_data = {MEM_D7,MEM_D6,MEM_D5,MEM_D4,MEM_D3,MEM_D2,MEM_D1,MEM_D0};
wire read_cycle = !SFC_nRD && SFC_nWR;
wire write_cycle = SFC_nRD && !SFC_nWR;
wire system_bank = !bank[6];
wire wram_bank = bank == 8'h7e || bank == 8'h7f;

reg [7:0] map_config;
reg boot_overlay, boot_mode;
reg cpu_grant, nor_busy, return_irq;
reg power_meta, power_sync, power_hold;
wire power_service = power_sync || power_hold;
wire cpu_requested = !map_config[0] || power_service || cpu_grant;
localparam [2:0] ISOLATE=0, QUIET=1, CONFIGURE=2, GUARD=3, SFC_OWNER=4, CPU_OWNER=5;
reg [2:0] owner;
reg target_cpu, sfc_released;
localparam [2:0] GUARD_CYCLES_MINUS_ONE = 3'd3;
reg [2:0] guard_count;
reg read_meta, read_sync, write_meta, write_sync, write_previous;
wire sfc_active = resetn && owner == SFC_OWNER && map_config[0] &&
                  !POWER_FAIL && !power_service;
wire cpu_active = resetn && owner == CPU_OWNER;
wire bus_idle = !read_sync && !write_sync;

localparam [3:0] IDLE=0, REG_DATA=1, MEM_START=2, MEM_SETUP=3, MEM_STROBE=4,
                 MEM_HOLD=5, MEM_DONE=6, ERROR_FIRST=7, ERROR_LAST=8;
reg [3:0] phase;
wire memory_in_progress = phase >= MEM_START && phase <= MEM_HOLD;
always @(posedge bus_clock or negedge resetn) begin
    if (!resetn) begin
        owner <= ISOLATE;
        target_cpu <= 1'b1;
        sfc_released <= 1'b0;
        guard_count <= 0;
    end else begin
        if (!map_config[0] || power_service)
            sfc_released <= 0;
        else if (owner == SFC_OWNER)
            sfc_released <= 1;
        case (owner)
            SFC_OWNER: if (cpu_requested && (bus_idle || power_service)) owner <= ISOLATE;
            CPU_OWNER: if (!cpu_requested && !memory_in_progress && !nor_busy) owner <= ISOLATE;
            ISOLATE: begin
                target_cpu <= cpu_requested;
                guard_count <= GUARD_CYCLES_MINUS_ONE;
                owner <= QUIET;
            end
            QUIET, GUARD: begin
                if (guard_count != 0)
                    guard_count <= guard_count - 1'b1;
                else if (owner == QUIET)
                    owner <= CONFIGURE;
                else if (cpu_requested != target_cpu)
                    owner <= ISOLATE;
                else
                    owner <= target_cpu ? CPU_OWNER : SFC_OWNER;
            end
            CONFIGURE: begin
                guard_count <= GUARD_CYCLES_MINUS_ONE;
                owner <= GUARD;
            end
            default: owner <= ISOLATE;
        endcase
    end
end

wire comm = map_config[7] && system_bank && page == 4'h5;
wire comm_register = comm && offset < 6'h0d;
wire lo_save = bank[6:4] == 3'b111 && !page[3] && !wram_bank;
wire hi_save = system_bank && bank[5] && page[3:1] == 3'b011;
wire bios_page = boot_overlay && bank == 8'h2f && page[3:1] == 3'b011;
wire boot_vector = page == 4'hf && offset[5:1] == 5'h1e;
wire boot_jump = page == 4'h8 && offset[5:2] == 0;
wire fixed_read = sfc_active && boot_mode && bank == 0 && !SFC_nROMSEL &&
                  read_cycle && (boot_vector || boot_jump);
wire [7:0] fixed_data = boot_vector ? (offset[0] ? 8'h80 : 8'h00) :
                       offset[1] ? (offset[0] ? 8'h2f : 8'h60) :
                                   (offset[0] ? 8'h00 : 8'h5c);
wire save_selected = bios_page || (map_config[6] && (map_config[1] ? lo_save : hi_save));
wire rom_read = sfc_active && !boot_mode && read_cycle && !SFC_nROMSEL && !wram_bank &&
                (!system_bank || page[3]) && !save_selected && !comm;
wire ram_read = sfc_active && read_cycle && save_selected;
wire ram_write = sfc_active && write_cycle && save_selected && !bios_page;
wire comm_read = sfc_active && read_cycle && comm_register;

// SRAM high address bits are physically wired to MEM A19..A16.
wire [22:0] rom_address = {map_config[2] && !bank[7],
    map_config[1] ? {bank[6:0],page[2:0],6'b0,offset} : {bank[5:0],page,6'b0,offset}};
wire [5:0] upper_mask = 6'h3f >> ((map_config[5:3] >= 6) ? 3'd0 : (3'd6-map_config[5:3]));
wire [3:0] save_page = bios_page ? 4'hf :
                       map_config[1] ? {bank[1:0],page[2:1]} : bank[3:0];
wire [22:0] sfc_mem_address = save_selected ? {3'b0,save_page,3'b0,page[0],6'b0,offset} :
                             {rom_address[22:17] & upper_mask,rom_address[16:0]};

reg [22:0] cpu_address;
reg cpu_ram, cpu_write;
reg [1:0] lane, bytes_left;
reg [31:0] write_data, memory_result;
// Counters cover N+1 fabric clocks. NOR pin strobes still start/end on falling edges.
localparam [3:0] SETUP_COUNT=4'd3, RAM_STROBE_COUNT=4'd7, NOR_STROBE_COUNT=4'd8,
                 RAM_HOLD_COUNT=4'd3, NOR_HOLD_COUNT=4'd4;
reg [3:0] mem_count;
reg nor_interrupted, nor_strobe;
wire nor_power_abort = !cpu_ram && (power_service || nor_interrupted);
wire [22:0] cpu_pin_address = cpu_ram ? {3'b0,cpu_address[16:13],3'b0,cpu_address[12:0]} : cpu_address;
wire [22:0] mem_address = cpu_active ? cpu_pin_address : sfc_mem_address;
wire cpu_select = cpu_active && (phase == MEM_SETUP || phase == MEM_STROBE || phase == MEM_HOLD);
wire cpu_strobe = cpu_active && (cpu_ram ? phase == MEM_STROBE : nor_strobe);
wire [7:0] cpu_byte = write_data >> {lane,3'b0};

// Check power_sync after it has settled from the rising edge that enters
// MEM_STROBE. Once the pin pulse starts, hold it until the phase ends.
always @(negedge bus_clock or negedge resetn) begin
    if (!resetn)
        nor_strobe <= 0;
    else
        nor_strobe <= phase == MEM_STROBE && !cpu_ram &&
                      (nor_strobe || !nor_power_abort);
end

assign {MEM_A22,MEM_A21,MEM_A20,MEM_A19,MEM_A18,MEM_A17,MEM_A16,MEM_A15,
        MEM_A14,MEM_A13,MEM_A12,MEM_A5,MEM_A4,MEM_A3,MEM_A2,MEM_A1,MEM_A0} =
    {mem_address[22:12],mem_address[5:0]};
// The FPGA drives these six U6 inputs only while it owns the memory bus.
assign {MEM_A11,MEM_A10,MEM_A9,MEM_A8,MEM_A7,MEM_A6} =
    cpu_active ? cpu_pin_address[11:6] : 6'bz;
assign MEM_nCE_ROM = !(rom_read || (cpu_select && !cpu_ram));
assign MEM_nCE_RAM = !(ram_read || ram_write || (cpu_select && cpu_ram));
assign MEM_nOE = !(rom_read || ram_read || (cpu_strobe && !cpu_write));
assign MEM_nWE = !(ram_write || (cpu_strobe && cpu_write));
assign U1_nOE = !sfc_active;
assign U6_nOE = !cpu_active;
assign U5_nOE_FET = rom_read || ram_read || ram_write || fixed_read || comm_read ||
                     (sfc_active && write_cycle && comm_register);
assign SFC_nRESET_OD = (resetn && sfc_released && map_config[0] &&
                        !POWER_FAIL && !power_service) ? 1'bz : 1'b0;
`ifndef SFCBUILDER_AUDIO
assign {DAC0_AUDIO_L,DAC1_AUDIO_R} = 2'b0;
`endif
(* keep = "true" *) reg [1:0] spi_select, spi_output_enable;
// Sample the GPIO bundle together before decoding it in the bus domain.
always @(posedge bus_clock or negedge resetn) begin
    if (!resetn)
        {spi_output_enable,spi_select} <= 4'b0000;
    else
        {spi_output_enable,spi_select} <= {spi_sel1_out_en,spi_sel0_out_en,
                                           spi_sel1_out_data,spi_sel0_out_data};
end
wire [1:0] spi_requested =
    ((&spi_output_enable) && spi_select != 2'b11) ? spi_select : 2'b00;
reg [1:0] spi_selected;
// Pass through deselect before asserting the other device's chip select.
always @(posedge bus_clock or negedge resetn) begin
    if (!resetn)
        spi_selected <= 2'b00;
    else if (spi_selected != 2'b00 && spi_selected != spi_requested)
        spi_selected <= 2'b00;
    else
        spi_selected <= spi_requested;
end
assign SD_nCS = !spi_selected[0];
assign SPI_NOR_nCS = !spi_selected[1];
assign spi_miso_in = SD_MISO;

reg [7:0] command, reply, irq_control, error_status;
reg [15:0] length;
reg app_stop_req, app_stopped, command_pending, reply_pending;
reg [31:0] tx_fifo, rx_fifo;
reg [2:0] tx_count, rx_count;
reg [1:0] tx_head, tx_tail, rx_head, rx_tail;
wire [7:0] tx_front = tx_count != 0 ? (tx_fifo >> {tx_head,3'b0}) : 8'b0;
wire [7:0] rx_front = rx_count != 0 ? (rx_fifo >> {rx_head,3'b0}) : 8'b0;
wire [7:0] fifo_status = {1'b0,rx_count,1'b0,tx_count};
wire [7:0] irq_status = {4'b0,return_irq,rx_count != 0,reply_pending,command_pending};
wire [7:0] bus_status = {2'b0,power_service,nor_busy,boot_overlay,cpu_grant,cpu_active,sfc_active};
wire sfc_irq = sfc_active &&
               |(irq_control[3:1] & irq_status[3:1]);
assign SFC_nIRQ_OD = sfc_irq ? 1'b0 : 1'bz;
assign fabric_interrupt = {1'b0,power_service,app_stop_req,
                    irq_control[0] && (command_pending || tx_count != 0 || cpu_grant)};

wire [127:0] comm_registers = {24'b0,error_status,length[15:8],length[7:0],
    irq_status,irq_control,fifo_status,rx_front,tx_front,bus_status,reply,
    4'b0,app_stopped,1'b0,reply_pending,command_pending,command,7'b0,app_stop_req};
wire [7:0] sfc_register_data = comm_registers[{offset[3:0],3'b0} +: 8];
// Keep high impedance at the pad boundary so Native synthesis preserves I/O OE.
wire cpu_data_drive = cpu_select && cpu_write;
wire mem_data_oe = cpu_data_drive || fixed_read || comm_read;
wire [7:0] mem_data_out = cpu_data_drive ? cpu_byte :
                         fixed_read ? fixed_data : sfc_register_data;
assign {MEM_D7,MEM_D6,MEM_D5,MEM_D4,MEM_D3,MEM_D2,MEM_D1,MEM_D0} =
    mem_data_oe ? mem_data_out : 8'bz;

// Synchronize strobe and sampled address/data. Retain the final sample
// taken during the write cycle and commit once on its synchronized end.
reg [3:0] sfc_write_index;
reg [7:0] sfc_write_data;
reg sfc_write_selected;
reg sfc_read_previous;
reg [12:0] write_sample_meta, write_sample_sync;
reg rx_sample_meta, rx_sample_sync, sfc_rx_selected;
reg [12:0] status_meta, status_sync;
wire sfc_write_end = write_previous && !write_sync && sfc_write_selected;
wire sfc_rx_pop = sfc_read_previous && !read_sync && sfc_rx_selected && rx_count != 0;
always @(posedge bus_clock or negedge resetn) begin
    if (!resetn) begin
        {power_meta,power_sync,read_meta,read_sync,write_meta,write_sync,write_previous,
         sfc_read_previous,sfc_rx_selected,sfc_write_selected} <= 0;
        {write_sample_meta,write_sample_sync,rx_sample_meta,rx_sample_sync} <= 0;
        sfc_write_index <= 0;
        sfc_write_data <= 0;
        status_meta <= 0;
        status_sync <= 0;
    end else begin
        {power_sync,power_meta} <= {power_meta,POWER_FAIL};
        {read_sync,read_meta} <= {read_meta,read_cycle};
        {write_sync,write_meta} <= {write_meta,write_cycle};
        write_previous <= write_sync;
        sfc_read_previous <= read_sync;
        write_sample_meta <= {sfc_active && comm_register,offset[3:0],mem_data};
        write_sample_sync <= write_sample_meta;
        if (write_sync)
            {sfc_write_selected,sfc_write_index,sfc_write_data} <= write_sample_sync;
        rx_sample_meta <= comm_read && offset == 6 && rx_count != 0;
        rx_sample_sync <= rx_sample_meta;
        if (read_sync)
            sfc_rx_selected <= rx_sample_sync;
        status_meta <= {SFC_nIRQ_OD,SFC_nRESET_OD,SD_MISO,USB_VBUS_SENSE,POWER_FAIL,mem_data};
        status_sync <= status_meta;
    end
end

wire [31:0] address = logic_ahb_haddr;
wire nor_window = address[31:23] == 9'h0c2;
wire ram_window = address[31:17] == 15'h3100;
// A pending return drops the request, but NOR BUSY keeps the CPU owner
// in place. Let that owner read NOR status until software clears BUSY.
wire nor_status_read = nor_window && !logic_ahb_hwrite && cpu_active && nor_busy;
wire control_window = address[31:4] == 28'h6000000 && address[1:0] == 0;
wire fifo_window = address[31:6] == 26'h1800040 && address[1:0] == 0 &&
                   address[5:2] < 13;
`ifdef SFCBUILDER_AUDIO
wire audio_window = address[31:4] == 28'h6000200 && address[1:0] == 0 &&
                    ((address[3:2] == 0 && logic_ahb_hwrite) ||
                     (address[3:2] == 1 && !logic_ahb_hwrite) || address[3:2] == 2);
`else
wire audio_window = 1'b0;
`endif
wire aligned = logic_ahb_hsize == 0 ||
               (logic_ahb_hsize == 1 && !address[0]) ||
               (logic_ahb_hsize == 2 && address[1:0] == 0);
reg [4:0] reg_index;
reg reg_write, reg_reply_write;
wire [7:0] reg_byte = logic_ahb_hwdata[7:0];
wire reply_ack = sfc_write_end && sfc_write_index == 9 && sfc_write_data[1];
wire reply_full = reply_pending && !reply_ack;
wire reply_blocked = phase == REG_DATA && reg_reply_write && reply_full;
wire register_complete = phase == REG_DATA && logic_ahb_hready;
wire reg_store = register_complete && reg_write;
`ifdef SFCBUILDER_AUDIO
reg reg_pcm_write;
wire audio_full, audio_enabled, audio_underrun;
wire [7:0] audio_fifo_status;
wire register_blocked = reply_blocked || (phase == REG_DATA && reg_pcm_write && audio_full);
sfcbuilder_audio audio (
    .bus_clock(bus_clock),
    .audio_dsm_clock(audio_dsm_clock_out_data),
    .resetn(resetn), .power_service(power_service),
    .control_write(reg_store && reg_index == 22), .pcm_write(reg_store && reg_pcm_write),
    .write_data(logic_ahb_hwdata), .pcm_full(audio_full), .enabled(audio_enabled),
    .fifo_status(audio_fifo_status), .underrun(audio_underrun),
    .left_dsm(DAC0_AUDIO_L), .right_dsm(DAC1_AUDIO_R)
);
`else
wire register_blocked = reply_blocked;
`endif
wire power_release = reg_store && (reg_index == 4 || reg_index == 19) && reg_byte[5];
wire reply_publish = register_complete && reg_reply_write && !reply_full;
wire tx_pop = register_complete && !reg_write && reg_index == 5 && tx_count != 0;
wire tx_push = sfc_write_end && sfc_write_index == 5 && (tx_count != 4 || tx_pop);
wire rx_push = reg_store && reg_index == 6 && (rx_count != 4 || sfc_rx_pop);
reg [31:0] register_result;
always @* begin
    case (reg_index)
        16: register_result = {24'b0,map_config};
        17: register_result = {19'b0,status_sync};
        18: register_result = {30'b0,boot_overlay,boot_mode};
        19: register_result = {24'b0,bus_status};
`ifdef SFCBUILDER_AUDIO
        21: register_result = {23'b0,audio_underrun,audio_fifo_status};
        22: register_result = {31'b0,audio_enabled};
`endif
        default: register_result = {24'b0,comm_registers[{reg_index[3:0],3'b0} +: 8]};
    endcase
end
assign logic_ahb_hreadyout = phase == IDLE || (phase == REG_DATA && !register_blocked) ||
                          phase == MEM_DONE || phase == ERROR_LAST;
assign logic_ahb_hresp = register_blocked || phase == ERROR_FIRST || phase == ERROR_LAST;
assign logic_ahb_hrdata = phase == MEM_DONE ? memory_result : register_result;

always @(posedge bus_clock or negedge resetn) begin
    if (!resetn) begin
        phase <= IDLE;
        reg_index <= 0;
        reg_write <= 0;
        reg_reply_write <= 0;
`ifdef SFCBUILDER_AUDIO
        reg_pcm_write <= 0;
`endif
        cpu_address <= 0;
        cpu_ram <= 0;
        cpu_write <= 0;
        lane <= 0;
        bytes_left <= 0;
        write_data <= 0;
        memory_result <= 0;
        mem_count <= 0;
        nor_interrupted <= 0;
    end else begin
        // Remember even a brief power-fail indication until this AHB beat ends.
        if (!memory_in_progress)
            nor_interrupted <= 0;
        else if (power_service && !cpu_ram)
            nor_interrupted <= 1;

        case (phase)
            MEM_START: if (nor_power_abort) phase <= ERROR_FIRST;
            else if (cpu_active) begin
                write_data <= logic_ahb_hwdata;
                memory_result <= 0;
                mem_count <= SETUP_COUNT;
                phase <= MEM_SETUP;
            end else if (!cpu_requested) phase <= ERROR_FIRST;
            MEM_SETUP: if (nor_power_abort) phase <= ERROR_FIRST;
                       else if (mem_count != 0) mem_count <= mem_count - 1'b1;
                       else begin
                           mem_count <= cpu_ram ? RAM_STROBE_COUNT : NOR_STROBE_COUNT;
                           phase <= MEM_STROBE;
                       end
            // On the first NOR strobe cycle the previous rising edge left
            // power and interruption status stable for the pin gate. Use
            // that same veto here instead of feeding the falling-edge
            // pin register back into the state machine. The initial count
            // identifies the one cycle before a NOR pin pulse can have opened.
            MEM_STROBE: if (mem_count == NOR_STROBE_COUNT && nor_power_abort)
                            phase <= ERROR_FIRST;
                        else if (mem_count != 0) mem_count <= mem_count - 1'b1;
                        else begin
                            if (!cpu_write)
                                memory_result[{lane,3'b0} +: 8] <= mem_data;
                            // The NOR pin strobe ends half a clock into MEM_HOLD.
                            mem_count <= cpu_ram ? RAM_HOLD_COUNT : NOR_HOLD_COUNT;
                            phase <= MEM_HOLD;
                        end
            MEM_HOLD: if (mem_count != 0) mem_count <= mem_count - 1'b1;
                      else if (bytes_left == 0) phase <= MEM_DONE;
                      else if (nor_power_abort) phase <= ERROR_FIRST;
                      else begin
                          cpu_address <= cpu_address + 1'b1;
                          lane <= lane + 1'b1;
                          bytes_left <= bytes_left - 1'b1;
                          mem_count <= SETUP_COUNT;
                          phase <= MEM_SETUP;
                      end
            ERROR_FIRST: phase <= ERROR_LAST;
            // REG_DATA already presents the first ERROR cycle for a full register.
            default: if (register_blocked) phase <= ERROR_LAST;
            else if (logic_ahb_hready) begin
                phase <= IDLE;
                if (logic_ahb_htrans[1]) begin
                    if (logic_ahb_hsize == 2 && (control_window || fifo_window || audio_window)) begin
                        phase <= REG_DATA;
                        reg_index <= audio_window ? 5'd20 + {3'b0,address[3:2]} :
                                     {control_window,address[5:2]};
                        reg_write <= logic_ahb_hwrite;
                        reg_reply_write <= logic_ahb_hwrite && fifo_window && address[5:2] == 3;
`ifdef SFCBUILDER_AUDIO
                        reg_pcm_write <= audio_window && address[3:2] == 0;
`endif
                    end else if (aligned && (nor_window || ram_window) &&
                                 (cpu_requested || nor_status_read) &&
                                 (ram_window || !power_service)) begin
                        phase <= MEM_START;
                        cpu_address <= address[22:0];
                        cpu_ram <= ram_window;
                        cpu_write <= logic_ahb_hwrite;
                        lane <= address[1:0];
                        bytes_left <= logic_ahb_hsize == 2 ? 2'd3 : logic_ahb_hsize[1:0];
                    end else phase <= ERROR_FIRST;
                end
            end
        endcase
    end
end

always @(posedge bus_clock or negedge resetn) begin
    if (!resetn) begin
        map_config <= 8'h28;
        {boot_overlay,boot_mode,cpu_grant,nor_busy,return_irq,app_stop_req,app_stopped,
         command_pending,reply_pending} <= 0;
        {command,reply,irq_control,error_status,length} <= 0;
        {tx_count,rx_count,tx_head,tx_tail,rx_head,rx_tail} <= 0;
        {tx_fifo,rx_fifo} <= 0;
        power_hold <= 0;
    end else begin
        // Keep the power-fail interrupt and the CPU's memory ownership
        // until software finishes saving and the supply has recovered.
        if (power_sync)
            power_hold <= 1;
        else if (power_release)
            power_hold <= 0;

        // An ACK for the old reply must not clear a reply published on this edge.
        if (reply_publish) begin
            reply <= reg_byte;
            reply_pending <= 1;
        end else if (reply_ack)
            reply_pending <= 0;

        if (reg_store) begin
            case (reg_index)
                2: app_stopped <= reg_byte[3];
                4,19: begin
                    if (!reg_byte[5] && (!reg_byte[1] || reg_byte[4]))
                        nor_busy <= reg_byte[4];
                    if (reg_byte[1]) begin cpu_grant <= 0; return_irq <= 1; end
                end
                8: irq_control <= reg_byte;
                9: begin
                    if (reg_byte[0]) command_pending <= 0;
                    if (reg_byte[3]) return_irq <= 0;
                end
                10: length[7:0] <= reg_byte;
                11: length[15:8] <= reg_byte;
                12: error_status <= error_status & ~reg_byte;
                16: if (!map_config[0]) map_config <= reg_byte;
                    else if (!reg_byte[0]) map_config[0] <= 0;
                18: {boot_overlay,boot_mode} <= reg_byte[1:0];
                default: begin end
            endcase
        end
        if (sfc_write_end) begin
            case (sfc_write_index)
                0: app_stop_req <= sfc_write_data[0];
                1: begin command <= sfc_write_data; command_pending <= 1; end
                4: if (sfc_write_data[0]) begin cpu_grant <= 1; return_irq <= 0; end
                8: irq_control <= {irq_control[7:4],sfc_write_data[3:1],irq_control[0]};
                9: if (sfc_write_data[3]) return_irq <= 0;
                10: length[7:0] <= sfc_write_data;
                11: length[15:8] <= sfc_write_data;
                default: begin end
            endcase
        end

        if (tx_push) begin tx_fifo[{tx_tail,3'b0} +: 8] <= sfc_write_data; tx_tail <= tx_tail + 1'b1; end
        if (tx_pop) tx_head <= tx_head + 1'b1;
        case ({tx_push,tx_pop})
            2'b10: tx_count <= tx_count + 1'b1;
            2'b01: tx_count <= tx_count - 1'b1;
            default: begin end
        endcase
        if (rx_push) begin rx_fifo[{rx_tail,3'b0} +: 8] <= reg_byte; rx_tail <= rx_tail + 1'b1; end
        if (sfc_rx_pop) rx_head <= rx_head + 1'b1;
        case ({rx_push,sfc_rx_pop})
            2'b10: rx_count <= rx_count + 1'b1;
            2'b01: rx_count <= rx_count - 1'b1;
            default: begin end
        endcase
        if (sfc_write_end && sfc_write_index == 5 && !tx_push) error_status[0] <= 1;
        if (reg_store && reg_index == 6 && !rx_push) error_status[1] <= 1;
    end
end

assign slave_ahb_hready = 1'b1;
assign {slave_ahb_hsel,slave_ahb_htrans,slave_ahb_hsize,slave_ahb_hburst,
        slave_ahb_hwrite,slave_ahb_haddr,slave_ahb_hwdata} = 74'b0;
assign {ext_dma_DMACBREQ,ext_dma_DMACLBREQ,ext_dma_DMACSREQ,ext_dma_DMACLSREQ} = 16'b0;
endmodule
