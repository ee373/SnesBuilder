module $__BRAM9K_TDP_ (...);

parameter INIT = 0;
parameter PORT_A_RD_INIT_VALUE = 0;
parameter PORT_B_RD_INIT_VALUE = 0;
parameter PORT_R_RD_INIT_VALUE = 0;
parameter PORT_A_CLK_POL     = 1;
parameter PORT_A_OPTION_RDWR = "normal";
parameter PORT_A_WIDTH       = 18;
parameter PORT_A_WR_BE_WIDTH = 2;
parameter PORT_B_CLK_POL     = 1;
parameter PORT_B_OPTION_RDWR = "normal";
parameter PORT_B_WIDTH       = 18;
parameter PORT_B_WR_BE_WIDTH = 2;

input  [12:0]                   PORT_A_ADDR;
input                           PORT_A_CLK;
input                           PORT_A_CLK_EN;
input                           PORT_A_RD_EN;
input  [PORT_A_WR_BE_WIDTH-1:0] PORT_A_WR_BE;
input  [PORT_A_WIDTH-1:0]       PORT_A_WR_DATA;
input                           PORT_A_WR_EN;
output [PORT_A_WIDTH-1:0]       PORT_A_RD_DATA;
input  [12:0]                   PORT_B_ADDR;
input                           PORT_B_CLK;
input                           PORT_B_CLK_EN;
input                           PORT_B_RD_EN;
input  [PORT_B_WR_BE_WIDTH-1:0] PORT_B_WR_BE;
input  [PORT_B_WIDTH-1:0]       PORT_B_WR_DATA;
input                           PORT_B_WR_EN;
output [PORT_B_WIDTH-1:0]       PORT_B_RD_DATA;

function [7:0] addr_width(input [7:0] data_width);
  addr_width = data_width >= 16 ? 9 : data_width >= 8 ? 10 : data_width >= 4 ? 11 : data_width >= 2 ? 12 : 13;
endfunction

parameter PORT_A_ADDR_WIDTH = addr_width(PORT_A_WIDTH);
parameter PORT_B_ADDR_WIDTH = addr_width(PORT_B_WIDTH);

alta_ram9k #(
  .DATA_WIDTH_A   (PORT_A_WIDTH      ),
  .ADDR_WIDTH_A   (PORT_A_ADDR_WIDTH ),
  .BYTE_WIDTH_A   (PORT_A_WR_BE_WIDTH),
  .DATA_WIDTH_B   (PORT_B_WIDTH      ),
  .ADDR_WIDTH_B   (PORT_B_ADDR_WIDTH ),
  .BYTE_WIDTH_B   (PORT_B_WR_BE_WIDTH),
  .INIT_VAL       (INIT              ),
  .CLKMODE        ("independent"     ),
  .OPERATION_MODE ("bidir_dual_port" ),
  .PACKEDMODE     ("no"              ),
  .PORTA_CLKIN_EN ("yes"             ),
  .PORTA_CLKOUT_EN("yes"             ),
  .PORTB_CLKIN_EN ("yes"             ),
  .PORTB_CLKOUT_EN("yes"             ),
  .PORTA_RSTIN_EN ("yes"             ),
  .PORTA_RSTOUT_EN("yes"             ),
  .PORTB_RSTIN_EN ("yes"             ),
  .PORTB_RSTOUT_EN("yes"             ),
  .PORTA_WRITEMODE(PORT_A_OPTION_RDWR),
  .PORTB_WRITEMODE(PORT_B_OPTION_RDWR),
  .PORTA_OUTREG   ("no"              ),
  .PORTB_OUTREG   ("no"              ),
  .INIT_PORT      ("a"               )
) inst (
  .DataInA      (PORT_A_WR_DATA),
  .DataInB      (PORT_B_WR_DATA),
  .DataOutA     (PORT_A_RD_DATA),
  .DataOutB     (PORT_B_RD_DATA),
  .AddressA     (PORT_A_ADDR >> (13 - PORT_A_ADDR_WIDTH)),
  .AddressB     (PORT_B_ADDR >> (13 - PORT_B_ADDR_WIDTH)),
  .ByteEnA      (PORT_A_WR_BE  ),
  .ByteEnB      (PORT_B_WR_BE  ),
  .Clk0         (PORT_A_CLK    ),
  .ClkEn0       (PORT_A_CLK_EN ),
  .AsyncReset0  (1'b0          ),
  .Clk1         (PORT_B_CLK    ),
  .ClkEn1       (PORT_B_CLK_EN ),
  .AsyncReset1  (1'b0          ),
  .AddressStallA(1'b0          ),
  .WeA          (PORT_A_WR_EN  ),
  .ReA          (PORT_A_RD_EN  ),
  .AddressStallB(1'b0          ),
  .WeB          (PORT_B_WR_EN  ),
  .ReB          (PORT_B_RD_EN  )
);
endmodule

module $__BRAM9K_PDP_ (...);

parameter INIT = 0;
parameter PORT_A_RD_INIT_VALUE = 0;
parameter PORT_B_RD_INIT_VALUE = 0;
parameter PORT_R_RD_INIT_VALUE = 0;
parameter PORT_R_CLK_POL     = 1;
parameter PORT_R_WIDTH       = 36;
parameter PORT_W_CLK_POL     = 1;
parameter PORT_W_OPTION_RDWR = "normal";
parameter PORT_W_WIDTH       = 36;
parameter PORT_W_WR_BE_WIDTH = 2;

input  [12:0]                   PORT_R_ADDR;
input                           PORT_R_CLK;
input                           PORT_R_CLK_EN;
output [PORT_R_WIDTH-1:0]       PORT_R_RD_DATA;
input                           PORT_R_RD_EN;
input  [12:0]                   PORT_W_ADDR;
input                           PORT_W_CLK;
input                           PORT_W_CLK_EN;
input  [PORT_W_WR_BE_WIDTH-1:0] PORT_W_WR_BE;
input  [PORT_W_WIDTH-1:0]       PORT_W_WR_DATA;
input                           PORT_W_WR_EN;

function [7:0] addr_width(input [7:0] data_width);
  addr_width = data_width >= 32 ? 8 : data_width >= 16 ? 9 : data_width >= 8 ? 10 : data_width >= 4 ? 11 : data_width >= 2 ? 12 : 13;
endfunction

parameter PORT_W_ADDR_WIDTH = addr_width(PORT_W_WIDTH);
parameter PORT_R_ADDR_WIDTH = addr_width(PORT_R_WIDTH);

alta_ram9k #(
  .DATA_WIDTH_A   (PORT_W_WIDTH      ),
  .ADDR_WIDTH_A   (PORT_W_ADDR_WIDTH ),
  .BYTE_WIDTH_A   (PORT_W_WR_BE_WIDTH),
  .DATA_WIDTH_B   (PORT_R_WIDTH      ),
  .ADDR_WIDTH_B   (PORT_R_ADDR_WIDTH ),
  .BYTE_WIDTH_B   (PORT_R_WIDTH / 8  ),
  .INIT_VAL       (INIT              ),
  .CLKMODE        ("read_write"      ),
  .OPERATION_MODE ("psuedo_dual_port"),
  .PACKEDMODE     ("no"              ),
  .PORTA_CLKIN_EN ("yes"             ),
  .PORTA_CLKOUT_EN("yes"             ),
  .PORTB_CLKIN_EN ("yes"             ),
  .PORTB_CLKOUT_EN("yes"             ),
  .PORTA_RSTIN_EN ("yes"             ),
  .PORTA_RSTOUT_EN("yes"             ),
  .PORTB_RSTIN_EN ("yes"             ),
  .PORTB_RSTOUT_EN("yes"             ),
  .PORTA_WRITEMODE("normal"          ),
  .PORTB_WRITEMODE(PORT_W_OPTION_RDWR),
  .PORTA_OUTREG   ("no"              ),
  .PORTB_OUTREG   ("no"              ),
  .INIT_PORT      ("a"               )
) inst (
  .DataInA      (PORT_W_WR_DATA),
  .DataInB      (              ),
  .DataOutA     (              ),
  .DataOutB     (PORT_R_RD_DATA),
  .AddressA     (PORT_W_ADDR >> (13 - PORT_W_ADDR_WIDTH)),
  .AddressB     (PORT_R_ADDR >> (13 - PORT_R_ADDR_WIDTH)),
  .ByteEnA      (PORT_W_WR_BE  ),
  .ByteEnB      (              ),
  .Clk0         (PORT_W_CLK    ),
  .ClkEn0       (PORT_W_CLK_EN ),
  .AsyncReset0  (1'b0          ),
  .Clk1         (PORT_R_CLK    ),
  .ClkEn1       (PORT_R_CLK_EN ),
  .AsyncReset1  (1'b0          ),
  .AddressStallA(1'b0          ),
  .WeA          (PORT_W_WR_EN  ),
  .ReA          (              ),
  .AddressStallB(1'b0          ),
  .WeB          (              ),
  .ReB          (PORT_R_RD_EN  )
);
endmodule
