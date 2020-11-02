//========= ODIN testbench in CapoCaccia 2019 =========// 

`timescale 1ns/1ps

module ODIN_tb;

	localparam CLK_period = 20;

	localparam M = 8;
	localparam N = 256; 

	reg CLK;
	reg RST;

	reg SCK;
	reg MOSI;
	wire MISO;

	reg [2*M:0] AERIN_ADDR;
	reg AERIN_REQ;
	wire AERIN_ACK;

	wire [M-1:0] AEROUT_ADDR;
	wire AEROUT_REQ;
	reg AEROUT_ACK;

	ODIN UUT (.CLK(CLK), .RST(RST), 
		.SCK(SCK), .MOSI(MOSI), .MISO(MISO), 
		.AERIN_ADDR(AERIN_ADDR), .AERIN_REQ(AERIN_REQ), .AERIN_ACK(AERIN_ACK), 
		.AEROUT_ADDR(AEROUT_ADDR), .AEROUT_REQ(AEROUT_REQ), .AEROUT_ACK(AEROUT_ACK)
	);
	
	//========= Clock generation =========//
	
	initial 
	begin
		CLK = 0;
	end

	always#(CLK_period/2) CLK = !CLK; 
	
	//========= Initial reset =========//
	initial 
	begin 
		RST = 1;
		#(CLK_period*10);
		RST = 0;
	end
	
endmodule