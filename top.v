/*
	MIT License

	Copyright (c) 2020 Truong Hy
	
	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:
	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.
	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.

	Developer: Truong Hy
	HDL      : Verilog
	Target   : For the DE10-Nano development kit board (SoC FPGA Cyclone V)
	Version  : 20221029
    
	A hardware design showing the FPGA portion directly sending & receiving serial data using the on-board UART-USB on the DE10-Nano.
	It achieves this using the FPGA-to-HPS bridge and HPS UART0 controller (hard-IP).

	See readme.md for more information.
*/
module top(
	// FPGA clock
	input FPGA_CLK1_50,
	input FPGA_CLK2_50,
	input FPGA_CLK3_50,
	
	// FPGA ADC LTC2308 (SPI)
	/*
	output ADC_CONVST,
	output ADC_SCK,
	output ADC_SDI,
	input  ADC_SDO,
	*/
	
	// FPGA Arduino IO
	/*
	inout [15:0] ARDUINO_IO,
	inout        ARDUINO_RESET_N,
	*/
	
	// FPGA GPIO
	/*
	inout [35:0] GPIO_0,
	inout [35:0] GPIO_1,
	*/
	
	// FPGA HDMI
	/*
	inout          HDMI_I2C_SCL,
	inout          HDMI_I2C_SDA,
	inout          HDMI_I2S,
	inout          HDMI_LRCLK,
	inout          HDMI_MCLK,
	inout          HDMI_SCLK,
	output         HDMI_TX_CLK,
	output [23: 0] HDMI_TX_D,
	output         HDMI_TX_DE,
	output         HDMI_TX_HS,
	input          HDMI_TX_INT,
	output         HDMI_TX_VS,
	*/

	// FPGA push button, LEDs and slide switches
	input  [1:0] KEY,
	output [7:0] LED,
	input  [3:0] SW,

	// HPS DDR-3 SDRAM
	output [14:0] HPS_DDR3_ADDR,
	output [2:0]  HPS_DDR3_BA,
	output        HPS_DDR3_CAS_N,
	output        HPS_DDR3_CKE,
	output        HPS_DDR3_CK_N,
	output        HPS_DDR3_CK_P,
	output        HPS_DDR3_CS_N,
	output [3:0]  HPS_DDR3_DM,
	inout  [31:0] HPS_DDR3_DQ,
	inout  [3:0]  HPS_DDR3_DQS_N,
	inout  [3:0]  HPS_DDR3_DQS_P,
	output        HPS_DDR3_ODT,
	output        HPS_DDR3_RAS_N,
	output        HPS_DDR3_RESET_N,
	input         HPS_DDR3_RZQ,
	output        HPS_DDR3_WE_N,
	
	// HPS SD-CARD
	output      HPS_SD_CLK,
	inout       HPS_SD_CMD,
	inout [3:0] HPS_SD_DATA,

	// HPS UART (UART-USB)
	input  HPS_UART_RX,
	output HPS_UART_TX,
	
	// HPS USB OTG
	input       HPS_USB_CLKOUT,
	inout [7:0] HPS_USB_DATA,
	input       HPS_USB_DIR,
	input       HPS_USB_NXT,
	output      HPS_USB_STP,
	
	// HPS EMAC (Ethernet)
	output       HPS_ENET_GTX_CLK,
	inout        HPS_ENET_INT_N,
	output       HPS_ENET_MDC,
	inout        HPS_ENET_MDIO,
	input        HPS_ENET_RX_CLK,
	input [3:0]  HPS_ENET_RX_DATA,
	input        HPS_ENET_RX_DV,
	output [3:0] HPS_ENET_TX_DATA,
	output       HPS_ENET_TX_EN,

	// HPS SPI (hardwired to the LTC 2x7 connector)
	output HPS_SPIM_CLK,
	input  HPS_SPIM_MISO,
	output HPS_SPIM_MOSI,
	inout  HPS_SPIM_SS,
	
	// HPS Accelerometer interrupt line (a physical pin)
	//inout HPS_GSENSOR_INT,
	
	// Disabled because 0ohm resistor is not populated (hardwired to the LTC 2x7 connector)
	//inout HPS_LTC_GPIO,
	
	// HPS I2C 0 (hardwired to the Accelerometer)
	inout HPS_I2C0_SCLK,
	inout HPS_I2C0_SDAT,
	
	// HPS I2C 1 (hardwired to the LTC 2x7 connector)
	inout HPS_I2C1_SCLK,
	inout HPS_I2C1_SDAT
);
	// ----------------
	// HPS (SoC) module
	// ----------------

	// Wires for the PLL clock and reset
	wire pll_0_clock;
	wire pll_0_locked;
	wire hps_reset_n;
	wire master_reset = ~hps_reset_n;
	//wire master_reset2 = ~hps_reset_n | ~pll_0_locked;  // Stay in reset if pll is not locked

	// Wires for the AXI interface to the FPGA-to-HPS Bridge (provides FPGA access to the HPS 4GB address map)
	wire [7:0]   f2h_axi_slave_awid;
	wire [31:0]  f2h_axi_slave_awaddr;
	wire [3:0]   f2h_axi_slave_awlen;
	wire [2:0]   f2h_axi_slave_awsize;
	wire [1:0]   f2h_axi_slave_awburst;
	wire [1:0]   f2h_axi_slave_awlock;
	wire [3:0]   f2h_axi_slave_awcache;
	wire [2:0]   f2h_axi_slave_awprot;
	wire         f2h_axi_slave_awvalid;
	wire         f2h_axi_slave_awready;
	wire [4:0]   f2h_axi_slave_awuser;
	wire [7:0]   f2h_axi_slave_wid;
	wire [31:0]  f2h_axi_slave_wdata;
	wire [3:0]   f2h_axi_slave_wstrb;
	wire         f2h_axi_slave_wlast;
	wire         f2h_axi_slave_wvalid;
	wire         f2h_axi_slave_wready;
	wire [7:0]   f2h_axi_slave_bid;
	wire [1:0]   f2h_axi_slave_bresp;
	wire         f2h_axi_slave_bvalid;
	wire         f2h_axi_slave_bready;
	wire [7:0]   f2h_axi_slave_arid;
	wire [31:0]  f2h_axi_slave_araddr;
	wire [3:0]   f2h_axi_slave_arlen;
	wire [2:0]   f2h_axi_slave_arsize;
	wire [1:0]   f2h_axi_slave_arburst;
	wire [1:0]   f2h_axi_slave_arlock;
	wire [3:0]   f2h_axi_slave_arcache;
	wire [2:0]   f2h_axi_slave_arprot;
	wire         f2h_axi_slave_arvalid;
	wire         f2h_axi_slave_arready;
	wire [4:0]   f2h_axi_slave_aruser;
	wire [7:0]   f2h_axi_slave_rid;
	wire [31:0]  f2h_axi_slave_rdata;
	wire [1:0]   f2h_axi_slave_rresp;
	wire         f2h_axi_slave_rlast;
	wire         f2h_axi_slave_rvalid;
	wire         f2h_axi_slave_rready;

	// HPS (SoC) instance
	soc_system u0(
		// Clock
		.clk_clk(FPGA_CLK1_50),
		.pll_0_outclk0_clk(pll_0_clock),
		.pll_0_locked_export(pll_0_locked),

		// HPS DDR-3 SDRAM pin connections
		.memory_mem_a(HPS_DDR3_ADDR),
		.memory_mem_ba(HPS_DDR3_BA),
		.memory_mem_ck(HPS_DDR3_CK_P),
		.memory_mem_ck_n(HPS_DDR3_CK_N),
		.memory_mem_cke(HPS_DDR3_CKE),
		.memory_mem_cs_n(HPS_DDR3_CS_N),
		.memory_mem_ras_n(HPS_DDR3_RAS_N),
		.memory_mem_cas_n(HPS_DDR3_CAS_N),
		.memory_mem_we_n(HPS_DDR3_WE_N),
		.memory_mem_reset_n(HPS_DDR3_RESET_N),
		.memory_mem_dq(HPS_DDR3_DQ),
		.memory_mem_dqs(HPS_DDR3_DQS_P),
		.memory_mem_dqs_n(HPS_DDR3_DQS_N),
		.memory_mem_odt(HPS_DDR3_ODT),
		.memory_mem_dm(HPS_DDR3_DM),
		.memory_oct_rzqin(HPS_DDR3_RZQ),
		
		// HPS SD-card pin connections
		.hps_io_hps_io_sdio_inst_CMD(HPS_SD_CMD),
		.hps_io_hps_io_sdio_inst_D0(HPS_SD_DATA[0]),
		.hps_io_hps_io_sdio_inst_D1(HPS_SD_DATA[1]),
		.hps_io_hps_io_sdio_inst_CLK(HPS_SD_CLK),
		.hps_io_hps_io_sdio_inst_D2(HPS_SD_DATA[2]),
		.hps_io_hps_io_sdio_inst_D3(HPS_SD_DATA[3]),
		
		// HPS UART0 (UART-USB) pin connections
		.hps_io_hps_io_uart0_inst_RX(HPS_UART_RX),
		.hps_io_hps_io_uart0_inst_TX(HPS_UART_TX),
		
		// HPS EMAC1 (Ethernet) pin connections
		.hps_io_hps_io_emac1_inst_TX_CLK(HPS_ENET_GTX_CLK),
		.hps_io_hps_io_emac1_inst_TXD0(HPS_ENET_TX_DATA[0]),
		.hps_io_hps_io_emac1_inst_TXD1(HPS_ENET_TX_DATA[1]),
		.hps_io_hps_io_emac1_inst_TXD2(HPS_ENET_TX_DATA[2]),
		.hps_io_hps_io_emac1_inst_TXD3(HPS_ENET_TX_DATA[3]),
		.hps_io_hps_io_emac1_inst_RXD0(HPS_ENET_RX_DATA[0]),
		.hps_io_hps_io_emac1_inst_MDIO(HPS_ENET_MDIO),
		.hps_io_hps_io_emac1_inst_MDC(HPS_ENET_MDC),
		.hps_io_hps_io_emac1_inst_RX_CTL(HPS_ENET_RX_DV),
		.hps_io_hps_io_emac1_inst_TX_CTL(HPS_ENET_TX_EN),
		.hps_io_hps_io_emac1_inst_RX_CLK(HPS_ENET_RX_CLK),
		.hps_io_hps_io_emac1_inst_RXD1(HPS_ENET_RX_DATA[1]),
		.hps_io_hps_io_emac1_inst_RXD2(HPS_ENET_RX_DATA[2]),
		.hps_io_hps_io_emac1_inst_RXD3(HPS_ENET_RX_DATA[3]),

		// HPS USB1 2.0 OTG pin connections
		.hps_io_hps_io_usb1_inst_D0(HPS_USB_DATA[0]),
		.hps_io_hps_io_usb1_inst_D1(HPS_USB_DATA[1]),
		.hps_io_hps_io_usb1_inst_D2(HPS_USB_DATA[2]),
		.hps_io_hps_io_usb1_inst_D3(HPS_USB_DATA[3]),
		.hps_io_hps_io_usb1_inst_D4(HPS_USB_DATA[4]),
		.hps_io_hps_io_usb1_inst_D5(HPS_USB_DATA[5]),
		.hps_io_hps_io_usb1_inst_D6(HPS_USB_DATA[6]),
		.hps_io_hps_io_usb1_inst_D7(HPS_USB_DATA[7]),
		.hps_io_hps_io_usb1_inst_CLK(HPS_USB_CLKOUT),
		.hps_io_hps_io_usb1_inst_STP(HPS_USB_STP),
		.hps_io_hps_io_usb1_inst_DIR(HPS_USB_DIR),
		.hps_io_hps_io_usb1_inst_NXT(HPS_USB_NXT),
		
		// HPS SPI1 pin connections
		.hps_io_hps_io_spim1_inst_CLK(HPS_SPIM_CLK),
		.hps_io_hps_io_spim1_inst_MOSI(HPS_SPIM_MOSI),
		.hps_io_hps_io_spim1_inst_MISO(HPS_SPIM_MISO),
		.hps_io_hps_io_spim1_inst_SS0(HPS_SPIM_SS),
		
		// HPS I2C0 pin connections
		.hps_io_hps_io_i2c0_inst_SDA(HPS_I2C0_SDAT),
		.hps_io_hps_io_i2c0_inst_SCL(HPS_I2C0_SCLK),
		
		// HPS I2C1 pin connections
		.hps_io_hps_io_i2c1_inst_SDA(HPS_I2C1_SDAT),
		.hps_io_hps_io_i2c1_inst_SCL(HPS_I2C1_SCLK),
		
		// AXI interface to FPGA-to-HPS Bridge (4GB address map via L3 Interconnect. See Interconnect Block Diagram in Cyclone V Tech Ref Man.)
		.hps_0_f2h_axi_clock_clk(pll_0_clock),
		.hps_0_f2h_axi_slave_awid(f2h_axi_slave_awid),
		.hps_0_f2h_axi_slave_awaddr(f2h_axi_slave_awaddr),
		.hps_0_f2h_axi_slave_awlen(f2h_axi_slave_awlen),
		.hps_0_f2h_axi_slave_awsize(f2h_axi_slave_awsize),
		.hps_0_f2h_axi_slave_awburst(f2h_axi_slave_awburst),
		.hps_0_f2h_axi_slave_awlock(f2h_axi_slave_awlock),
		.hps_0_f2h_axi_slave_awcache(f2h_axi_slave_awcache),
		.hps_0_f2h_axi_slave_awprot(f2h_axi_slave_awprot),
		.hps_0_f2h_axi_slave_awvalid(f2h_axi_slave_awvalid),
		.hps_0_f2h_axi_slave_awready(f2h_axi_slave_awready),
		.hps_0_f2h_axi_slave_awuser(f2h_axi_slave_awuser),
		.hps_0_f2h_axi_slave_wid(f2h_axi_slave_wid),
		.hps_0_f2h_axi_slave_wdata(f2h_axi_slave_wdata),
		.hps_0_f2h_axi_slave_wstrb(f2h_axi_slave_wstrb),
		.hps_0_f2h_axi_slave_wlast(f2h_axi_slave_wlast),
		.hps_0_f2h_axi_slave_wvalid(f2h_axi_slave_wvalid),
		.hps_0_f2h_axi_slave_wready(f2h_axi_slave_wready),
		.hps_0_f2h_axi_slave_bid(f2h_axi_slave_bid),
		.hps_0_f2h_axi_slave_bresp(f2h_axi_slave_bresp),
		.hps_0_f2h_axi_slave_bvalid(f2h_axi_slave_bvalid),
		.hps_0_f2h_axi_slave_bready(f2h_axi_slave_bready),
		.hps_0_f2h_axi_slave_arid(f2h_axi_slave_arid),
		.hps_0_f2h_axi_slave_araddr(f2h_axi_slave_araddr),
		.hps_0_f2h_axi_slave_arlen(f2h_axi_slave_arlen),
		.hps_0_f2h_axi_slave_arsize(f2h_axi_slave_arsize),
		.hps_0_f2h_axi_slave_arburst(f2h_axi_slave_arburst),
		.hps_0_f2h_axi_slave_arlock(f2h_axi_slave_arlock),
		.hps_0_f2h_axi_slave_arcache(f2h_axi_slave_arcache),
		.hps_0_f2h_axi_slave_arprot(f2h_axi_slave_arprot),
		.hps_0_f2h_axi_slave_arvalid(f2h_axi_slave_arvalid),
		.hps_0_f2h_axi_slave_arready(f2h_axi_slave_arready),
		.hps_0_f2h_axi_slave_aruser(f2h_axi_slave_aruser),
		.hps_0_f2h_axi_slave_rid(f2h_axi_slave_rid),
		.hps_0_f2h_axi_slave_rdata(f2h_axi_slave_rdata),
		.hps_0_f2h_axi_slave_rresp(f2h_axi_slave_rresp),
		.hps_0_f2h_axi_slave_rlast(f2h_axi_slave_rlast),
		.hps_0_f2h_axi_slave_rvalid(f2h_axi_slave_rvalid),
		.hps_0_f2h_axi_slave_rready(f2h_axi_slave_rready),

		// Reset
		.hps_0_h2f_reset_reset_n(hps_reset_n),
		.reset_reset_n(hps_reset_n)
	);
	
	// ------------
	// Push buttons
	// ------------
	
	wire debounced_key0;
	wire debounced_key1;
	debounce #(
		.CLK_CNT_WIDTH(21),
		.SW_WIDTH(2)
	)
	debounce_inst(
		.rst(master_reset),
		.clk(FPGA_CLK1_50),
		.div(1250000),
		.sw_in({ ~KEY[1], ~KEY[0] }),
		.sw_out({ debounced_key1, debounced_key0 })
	);
	
	// ----
	// LEDs
	// ----
	
	//assign LED[0] = debounced_key0;
	//assign LED[1] = debounced_key1;
	//assign LED[7] = heart_beat[25];
	reg [7:0] led;
	assign LED[7:0] = led;

	// -----------
	// LED blinker
	// -----------
	
	/*
	reg [25:0] heart_beat;
	always @ (posedge FPGA_CLK1_50 or posedge master_reset) begin
		if(master_reset) begin
			heart_beat <= 0;
		end
		else begin
			heart_beat <= heart_beat + 1;
		end
	end
	*/
	
	// ------------------
	// AXI support module
	// ------------------
	
	// For my AXI reader and writer modules
	localparam RD_AXI_ADDR_WIDTH = 32;
	localparam RD_AXI_BUS_WIDTH = 32;  // Should match the HPS AXI bridge FPGA-to-HPS interface width in Platform Designer
	localparam RD_AXI_MAX_BURST_LEN = 1;
	localparam WR_AXI_ADDR_WIDTH = 32;
	localparam WR_AXI_BUS_WIDTH = 32;  // Should match the HPS AXI bridge FPGA-to-HPS interface width in Platform Designer
	localparam WR_AXI_MAX_BURST_LEN = 1;
	
	reg rd_axi_enable;
	reg [RD_AXI_ADDR_WIDTH-1:0] rd_axi_addr;
	wire [RD_AXI_BUS_WIDTH*RD_AXI_MAX_BURST_LEN-1:0] rd_axi_data;
	reg [3:0] rd_axi_burst_len;
	reg [2:0] rd_axi_burst_size;
	wire [1:0] rd_axi_status;	
	// AXI reader instance
	rd_axi #(
		.RD_AXI_ADDR_WIDTH(RD_AXI_ADDR_WIDTH),
		.RD_AXI_BUS_WIDTH(RD_AXI_BUS_WIDTH),
		.RD_AXI_MAX_BURST_LEN(RD_AXI_MAX_BURST_LEN)
	) rd_axi_inst(
		.clock(pll_0_clock),
		.reset(master_reset),
		
		.enable(rd_axi_enable),
		.addr(rd_axi_addr),
		.data(rd_axi_data),
		.burst_len(rd_axi_burst_len),
		.burst_size(rd_axi_burst_size),
		.status(rd_axi_status),

		.ar_addr(f2h_axi_slave_araddr),
		.ar_len(f2h_axi_slave_arlen),
		.ar_size(f2h_axi_slave_arsize),
		.ar_burst(f2h_axi_slave_arburst),
		.ar_prot(f2h_axi_slave_arprot),
		.ar_valid(f2h_axi_slave_arvalid),
		.ar_ready(f2h_axi_slave_arready),
		.r_data(f2h_axi_slave_rdata),
		.r_last(f2h_axi_slave_rlast),
		.r_resp(f2h_axi_slave_rresp),
		.r_valid(f2h_axi_slave_rvalid),
		.r_ready(f2h_axi_slave_rready)
	);

	reg wr_axi_enable;
	reg [WR_AXI_ADDR_WIDTH-1:0] wr_axi_addr;
	reg [WR_AXI_BUS_WIDTH*WR_AXI_MAX_BURST_LEN-1:0] wr_axi_data;
	reg [3:0] wr_axi_burst_len;
	reg [2:0] wr_axi_burst_size;
	reg [3:0] wr_axi_burst_mask;
	wire [1:0] wr_axi_status;
	// AXI writer instance
	wr_axi #(
		.WR_AXI_ADDR_WIDTH(WR_AXI_ADDR_WIDTH),
		.WR_AXI_BUS_WIDTH(WR_AXI_BUS_WIDTH),
		.WR_AXI_MAX_BURST_LEN(WR_AXI_MAX_BURST_LEN)
	) wr_axi_inst(
		.clock(pll_0_clock),
		.reset(master_reset),
		
		.enable(wr_axi_enable),
		.addr(wr_axi_addr),
		.data(wr_axi_data),
		.burst_len(wr_axi_burst_len),
		.burst_size(wr_axi_burst_size),
		.burst_mask(wr_axi_burst_mask),
		.status(wr_axi_status),
		
		.aw_addr(f2h_axi_slave_awaddr),
		.aw_len(f2h_axi_slave_awlen),
		.aw_size(f2h_axi_slave_awsize),
		.aw_burst(f2h_axi_slave_awburst),
		.aw_prot(f2h_axi_slave_awprot),
		.aw_valid(f2h_axi_slave_awvalid),
		.aw_ready(f2h_axi_slave_awready),
		.w_data(f2h_axi_slave_wdata),
		.w_strb(f2h_axi_slave_wstrb),
		.w_last(f2h_axi_slave_wlast),
		.w_valid(f2h_axi_slave_wvalid),
		.w_ready(f2h_axi_slave_wready),
		.b_resp(f2h_axi_slave_bresp),
		.b_valid(f2h_axi_slave_bvalid),
		.b_ready(f2h_axi_slave_bready)
	);
	
	// AXI reader wires for passing to uart dev module
	wire rd_axi_enable_uart;
	wire [RD_AXI_ADDR_WIDTH-1:0] rd_axi_addr_uart;
	wire [RD_AXI_BUS_WIDTH*RD_AXI_MAX_BURST_LEN-1:0] rd_axi_data_uart;
	wire [3:0] rd_axi_burst_len_uart;
	wire [2:0] rd_axi_burst_size_uart;
	wire [1:0] rd_axi_status_uart;
	assign rd_axi_enable_uart = rd_axi_enable;
	assign rd_axi_addr_uart = rd_axi_addr;
	assign rd_axi_data_uart = rd_axi_data;
	assign rd_axi_burst_len_uart = rd_axi_burst_len;
	assign rd_axi_burst_size_uart = rd_axi_burst_size;
	assign rd_axi_status_uart = rd_axi_status;
	
	// AXI writer wires for passing to uart dev module
	wire wr_axi_enable_uart;
	wire [WR_AXI_ADDR_WIDTH-1:0] wr_axi_addr_uart;
	wire [WR_AXI_BUS_WIDTH*WR_AXI_MAX_BURST_LEN-1:0] wr_axi_data_uart;
	wire [3:0] wr_axi_burst_len_uart;
	wire [2:0] wr_axi_burst_size_uart;
	wire [3:0] wr_axi_burst_mask_uart;
	wire [1:0] wr_axi_status_uart;
	assign wr_axi_enable_uart = wr_axi_enable;
	assign wr_axi_addr_uart = wr_axi_addr;
	assign wr_axi_data_uart = wr_axi_data;
	assign wr_axi_burst_len_uart = wr_axi_burst_len;
	assign wr_axi_burst_size_uart = wr_axi_burst_size;
	assign wr_axi_burst_mask_uart = wr_axi_burst_mask;
	assign wr_axi_status_uart = wr_axi_status;

	// -----------
	// UART module
	// -----------
	
	reg [1:0] uart_enable;
	wire [1:0] uart_status;
	reg [7:0] uart_tx_data;
	reg uart_tx_input_type;
	reg [32:0] uart_tx_addr;
	reg [7:0] uart_tx_len;
	reg uart_tx_hex;
	reg [7:0] uart_tx_hex_start;
	reg uart_tx_new_line;
	wire [7:0] uart_rx_data;
	// HPS UART controller device module instance
	uart_dev #(
		.UART_BASE_ADDR(32'hFFC02000),
		.UART_TX_DATA_BUF_LEN(1),
		.UART_THRE_FIFO_MODE(0),
		.RD_AXI_ADDR_WIDTH(RD_AXI_ADDR_WIDTH),
		.RD_AXI_BUS_WIDTH(RD_AXI_BUS_WIDTH),
		.RD_AXI_MAX_BURST_LEN(RD_AXI_MAX_BURST_LEN),
		.WR_AXI_ADDR_WIDTH(WR_AXI_ADDR_WIDTH),
		.WR_AXI_BUS_WIDTH(WR_AXI_BUS_WIDTH),
		.WR_AXI_MAX_BURST_LEN(WR_AXI_MAX_BURST_LEN)
	) uart_dev_inst(
		.clock(pll_0_clock),
		.reset(master_reset),
		
		.enable(uart_enable),
		.status(uart_status),
		.tx_input_type(uart_tx_input_type),
		.tx_data(uart_tx_data),
		.tx_addr(uart_tx_addr),
		.tx_len(uart_tx_len),
		.tx_hex(uart_tx_hex),
		.tx_hex_start(uart_tx_hex_start),
		.tx_new_line(uart_tx_new_line),
		.rx_data(uart_rx_data),
		
		.rd_axi_enable(rd_axi_enable_uart),
		.rd_axi_addr(rd_axi_addr_uart),
		.rd_axi_data(rd_axi_data_uart),
		.rd_axi_burst_len(rd_axi_burst_len_uart),
		.rd_axi_burst_size(rd_axi_burst_size_uart),
		.rd_axi_status(rd_axi_status_uart),
		.wr_axi_enable(wr_axi_enable_uart),
		.wr_axi_addr(wr_axi_addr_uart),
		.wr_axi_data(wr_axi_data_uart),
		.wr_axi_burst_len(wr_axi_burst_len_uart),
		.wr_axi_burst_size(wr_axi_burst_size_uart),
		.wr_axi_burst_mask(wr_axi_burst_mask_uart),
		.wr_axi_status(wr_axi_status_uart)
	);
	
	// -----------------------------------------------
	// A slow clock for polling the UART receive check
	// -----------------------------------------------
	
	wire uart_rx_poll_clk_out;
	reg uart_rx_poll_clk_reset;
	clk_div #(
		.CLK_CNT_WIDTH(21)
	)
	clk_div_inst(
		.rst(master_reset | uart_rx_poll_clk_reset),
		.clk(pll_0_clock),
		.div(1250000),
		.clk_out(uart_rx_poll_clk_out)
	);
	
	// ------------------
	// Main state machine
	// ------------------
	
	// UART messages, etc..
	localparam UART_HELLO_MSG_LEN = 26;
	localparam [8*UART_HELLO_MSG_LEN-1:0] uart_hello_msg = "Hello from the FPGA side\r\n";
	localparam UART_ADDR_MSG_LEN = 12;
	localparam [8*UART_ADDR_MSG_LEN-1:0] uart_addr_msg = "0xffc020f8: ";
	reg [5:0] uart_msg_counter;  // Max value = 2^(5+1) - 1 = 63. Value must be equal or greater than longest message
	
	reg [3:0] state;
	always @ (posedge pll_0_clock or posedge master_reset) begin
		// STATE: Reset?
		if(master_reset) begin
			uart_enable <= 0;
			state <= 0;
		end
		else begin
		
			// -------------
			// State machine
			// -------------
			
			case(state)
			
				0: begin
					uart_rx_poll_clk_reset <= 0;
					state <= state + 1;
				end
				
				// Wait for key press
				1: begin
					if(debounced_key0) begin
						state <= state + 1;
					end else if(uart_rx_poll_clk_out) begin
						uart_rx_poll_clk_reset <= 1;
						state <= 6;
					end
				end
				
				// Wait for key depress
				2: begin
					if(debounced_key0 == 0) begin
						uart_msg_counter <= UART_HELLO_MSG_LEN - 1;
						state <= state + 1;
					end
				end
				
				// Transmit a string message to UART (Part 1 - init)
				3: begin
					case(uart_status)
						0: begin
							uart_tx_data <= uart_hello_msg[8*uart_msg_counter +: 8];
							uart_tx_input_type <= 0;
							uart_tx_len <= 1;
							uart_tx_hex <= 0;
							uart_tx_new_line <= 0;
							uart_enable <= 1;
						end
						2: begin
							uart_enable <= 0;
							if(uart_msg_counter > 0) begin
								uart_msg_counter <= uart_msg_counter - 1;
							end
							else begin
								uart_msg_counter <= UART_ADDR_MSG_LEN - 1;
								state <= state + 1;
							end
						end
					endcase
				end
				
				// Transmit string message to UART (Part 2 - loop for each character)
				4: begin
					case(uart_status)
						0: begin
							uart_tx_data <= uart_addr_msg[8*uart_msg_counter +: 8];
							uart_tx_input_type <= 0;
							uart_tx_len <= 1;
							uart_tx_hex <= 0;
							uart_tx_new_line <= 0;
							uart_enable <= 1;
						end
						2: begin
							uart_enable <= 0;
							if(uart_msg_counter > 0) begin
								uart_msg_counter <= uart_msg_counter - 1;
							end
							else begin
								state <= state + 1;
							end
						end
					endcase
				end
				
				// Transmit RAM content (4 bytes in hex format) to UART
				5: begin
					case(uart_status)
						0: begin
							uart_tx_input_type <= 1;  // Read from FPGA-to-HPS bridge AXI address
							uart_tx_addr <= 32'hFFC020F8;  // UART Controller Version
							uart_tx_len <= 4;
							uart_tx_hex <= 1;  // Display as hex string
							uart_tx_new_line <= 1;  // Display a new line
							uart_enable <= 1;
						end
						2: begin
							uart_enable <= 0;
							state <= 0;
						end
					endcase
				end
				
				// Check and if available get the received byte from the UART controller
				6: begin
					case(uart_status)
						0: begin
							uart_enable <= 2;
						end
						2: begin  // Received data
							uart_enable <= 0;
							state <= state + 1;
						end
						3: begin  // No data received
							uart_enable <= 0;
							state <= 0;
						end
					endcase
				end
				
				// If the received character is between (and including) 0 to 7 then toggle the corresponding LED
				7: begin
					if(uart_rx_data >= 48 && uart_rx_data <= 55) begin
						led[uart_rx_data - 48] <= ~led[uart_rx_data - 48];
					end
					state <= state + 1;
				end
				
				// Echo the received data back to the UART controller
				8: begin
					case(uart_status)
						0: begin
							uart_tx_data <= uart_rx_data;
							uart_tx_input_type <= 0;
							uart_tx_len <= 1;
							uart_tx_hex <= 0;
							uart_tx_new_line <= 0;
							uart_enable <= 1;
						end
						2: begin
							uart_enable <= 0;
							state <= 0;
						end
					endcase
				end

			endcase
		end
	end
endmodule
