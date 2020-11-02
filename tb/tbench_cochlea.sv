
 
// ODIN and SPI clock periods
`define CLK_HALF_PERIOD     10
`define SCK_HALF_PERIOD     50

// Testbench routines selection
`define PROGRAM_AND_VERIFY_NEURON_MEMORY  0
`define PROGRAM_AND_VERIFY_SYNAPSE_MEMORY 0
`define DO_LIF_NEURON_TEST                1

// ODIN global parameters and configuration registers
`define SPI_OPEN_LOOP              1'b0
`define SPI_BURST_TIMEREF          20'b0
`define SPI_OUT_AER_MONITOR_EN     1'b0
`define SPI_AER_SRC_CTRL_nNEUR     1'b0
`define SPI_MONITOR_NEUR_ADDR      8'd0
`define SPI_MONITOR_SYN_ADDR       8'd0
`define SPI_UPDATE_UNMAPPED_SYN    1'b0
`define SPI_PROPAGATE_UNMAPPED_SYN 1'b0
`define SPI_SYN_SIGN               256'h0
`define SPI_SDSP_ON_SYN_STIM       1'b0

// Leaky integrate-and-fire (LIF) parameters
`define PARAM_LEAK_STR_LIF   7'd2
`define PARAM_LEAK_EN_LIF    1'b1
`define PARAM_THR_LIF        8'd2
`define PARAM_CA_SYN_EN_LIF  1'b0
`define PARAM_THETAMEM_LIF   8'd0
`define PARAM_CA_THETA1_LIF  3'd0
`define PARAM_CA_THETA2_LIF  3'd0
`define PARAM_CA_THETA3_LIF  3'd0
`define PARAM_CALEAK_LIF     5'd0

// Phenomenological Izhikevich (IZH) parameters
`define PARAM_LEAK_STR        7'b0
`define PARAM_LEAK_EN         1'b0
`define PARAM_FI_SEL          3'b000
`define PARAM_SPK_REF         3'b000
`define PARAM_ISI_REF         4'b0000
`define PARAM_THR             3'b001
`define PARAM_RFR             3'b000
`define PARAM_DAPDEL          3'b001
`define PARAM_SPKLAT_EN       1'b1
`define PARAM_DAP_EN          1'b0
`define PARAM_STIM_THR        3'b000
`define PARAM_PHASIC_EN       1'b0
`define PARAM_MIXED_EN        1'b0
`define PARAM_CLASS2_EN       1'b0
`define PARAM_NEG_EN          1'b0
`define PARAM_REBOUND_EN      1'b0
`define PARAM_INHIN_EN        1'b0
`define PARAM_BIST_EN         1'b0
`define PARAM_RESON_EN        1'b0
`define PARAM_THRVAR_EN       1'b0
`define PARAM_THR_SEL_OF      1'b0
`define PARAM_THRLEAK         4'b0000
`define PARAM_ACC_EN          1'b0
`define PARAM_CA_SYN_EN       1'b0
`define PARAM_THETAMEM        3'b000
`define PARAM_CA_THETA1       3'b000
`define PARAM_CA_THETA2       3'b000
`define PARAM_CA_THETA3       3'b000
`define PARAM_CALEAK          5'b00000

module tbench #(
);

    logic            CLK;
    logic            RST;

    logic            SCK, MOSI, MISO;
    logic [    16:0] AERIN_ADDR;
    logic [     7:0] AEROUT_ADDR;
    logic            AERIN_REQ, AERIN_ACK, AEROUT_REQ, AEROUT_ACK;
    
    logic            SPI_config_rdy;
    logic            SPI_param_checked;
    logic            SNN_initialized_rdy;
    
    logic [    31:0] synapse_pattern , syn_data;
    logic [   127:0] neuron_pattern  , neur_data;
    logic [    31:0] shift_amt;
    logic [    15:0] addr_temp;
    logic [   255:0] data_temp;
    
    logic [    19:0] spi_read_data;
	
	logic [     3:0] syn_array [0:16] [0:16];
    
    integer i, j;
    integer param_dapdel;
	
    logic            cochlea_sim_start;
    

    /***************************
      INIT 
    ***************************/ 
    
    initial begin
        SCK        =  1'b0;
        MOSI       =  1'b0;
        AERIN_ADDR = 17'b0;
        AERIN_REQ  =  1'b0;
        AEROUT_ACK =  1'b0;
        
        SPI_config_rdy = 1'b0;
        SPI_param_checked = 1'b0;
        SNN_initialized_rdy = 1'b0;
    end
    

    /***************************
      CLK
    ***************************/ 
    
    initial begin
        CLK = 1'b1; 
        forever begin
            wait_ns(`CLK_HALF_PERIOD);
            CLK = ~CLK; 
        end
    end 

    
    /***************************
      RST
    ***************************/
    
    initial begin 
        RST = 1'b0;
        wait_ns(50);
        RST = 1'b1;
        wait_ns(50);
        RST = 1'b0;
        wait_ns(50);
        SPI_config_rdy = 1'b1;
        while (~SPI_param_checked) wait_ns(1);
        SNN_initialized_rdy = 1'b1;
    end

    /***************************
      Time event reference generation
    ***************************/ 
    
    initial begin
		cochlea_sim_start = 1'b0;
	    while(~cochlea_sim_start) wait_ns(1);
        forever begin
			$display("----- Firing time event reference.");
			aer_send (.addr_in({1'b0,8'b0,8'h7F}), .addr_out(AERIN_ADDR), .ack(AERIN_ACK), .req(AERIN_REQ));
			wait_ns(1000);
        end
    end
    
    /***************************
      STIMULI GENERATION
    ***************************/

    initial begin 
        while (~SPI_config_rdy) wait_ns(1);
        
        /*****************************************************************************************************************************************************************************************************************
                                                                              PROGRAMMING THE CONTROL REGISTERS THROUGH 20-bit SPI
        *****************************************************************************************************************************************************************************************************************/
        
        spi_write (.addr({1'b0,1'b0,2'b00,16'd0 }), .data(20'b1                    ), .MISO(MISO), .MOSI(MOSI), .SCK(SCK));   //SPI_GATE_ACTIVITY --> 1
        spi_write (.addr({1'b0,1'b0,2'b00,16'd1 }), .data(`SPI_OPEN_LOOP           ), .MISO(MISO), .MOSI(MOSI), .SCK(SCK));   //SPI_OPEN_LOOP
        data_temp = `SPI_SYN_SIGN;
        for (i=0; i<16; i++) begin
            spi_write (.addr({1'b0,1'b0,2'b00,(16'd2+i)}), .data(data_temp[15:0]), .MISO(MISO), .MOSI(MOSI), .SCK(SCK));      //SPI_SYN_SIGN
            data_temp = data_temp >> 16;
        end
        spi_write (.addr({1'b0,1'b0,2'b00,16'd18}), .data(`SPI_BURST_TIMEREF         ), .MISO(MISO), .MOSI(MOSI), .SCK(SCK)); //SPI_BURST_TIMEREF
        spi_write (.addr({1'b0,1'b0,2'b00,16'd20}), .data(`SPI_OUT_AER_MONITOR_EN    ), .MISO(MISO), .MOSI(MOSI), .SCK(SCK)); //SPI_OUT_AER_MONITOR_EN
        spi_write (.addr({1'b0,1'b0,2'b00,16'd19}), .data(`SPI_AER_SRC_CTRL_nNEUR    ), .MISO(MISO), .MOSI(MOSI), .SCK(SCK)); //SPI_AER_SRC_CTRL_nNEUR
        spi_write (.addr({1'b0,1'b0,2'b00,16'd21}), .data(`SPI_MONITOR_NEUR_ADDR     ), .MISO(MISO), .MOSI(MOSI), .SCK(SCK)); //SPI_MONITOR_NEUR_ADDR
        spi_write (.addr({1'b0,1'b0,2'b00,16'd22}), .data(`SPI_MONITOR_SYN_ADDR      ), .MISO(MISO), .MOSI(MOSI), .SCK(SCK)); //SPI_MONITOR_SYN_ADDR
        spi_write (.addr({1'b0,1'b0,2'b00,16'd23}), .data(`SPI_UPDATE_UNMAPPED_SYN   ), .MISO(MISO), .MOSI(MOSI), .SCK(SCK)); //SPI_UPDATE_UNMAPPED_SYN
        spi_write (.addr({1'b0,1'b0,2'b00,16'd24}), .data(`SPI_PROPAGATE_UNMAPPED_SYN), .MISO(MISO), .MOSI(MOSI), .SCK(SCK)); //SPI_PROPAGATE_UNMAPPED_SYN
        spi_write (.addr({1'b0,1'b0,2'b00,16'd25}), .data(`SPI_SDSP_ON_SYN_STIM      ), .MISO(MISO), .MOSI(MOSI), .SCK(SCK)); //SPI_SDSP_ON_SYN_STIM

        
        /*****************************************************************************************************************************************************************************************************************
                                                                                VERIFYING THE CONTROL REGISTERS THROUGH 20-bit SPI
        *****************************************************************************************************************************************************************************************************************/        
        
        $display("----- Starting verification of programmed SNN parameters");
        assert(snn_0.spi_slave_0.SPI_GATE_ACTIVITY          ==  1'b1                      ) else $fatal(0, "SPI_GATE_ACTIVITY parameter not correct.");
        assert(snn_0.spi_slave_0.SPI_OPEN_LOOP              == `SPI_OPEN_LOOP             ) else $fatal(0, "SPI_OPEN_LOOP parameter not correct.");
        assert(snn_0.spi_slave_0.SPI_SYN_SIGN               == `SPI_SYN_SIGN              ) else $fatal(0, "SPI_SYN_SIGN parameter not correct.");
        assert(snn_0.spi_slave_0.SPI_BURST_TIMEREF          == `SPI_BURST_TIMEREF         ) else $fatal(0, "SPI_BURST_TIMEREF parameter not correct.");
        assert(snn_0.spi_slave_0.SPI_OUT_AER_MONITOR_EN     == `SPI_OUT_AER_MONITOR_EN    ) else $fatal(0, "SPI_OUT_AER_MONITOR_EN parameter not correct.");
        assert(snn_0.spi_slave_0.SPI_AER_SRC_CTRL_nNEUR     == `SPI_AER_SRC_CTRL_nNEUR    ) else $fatal(0, "SPI_AER_SRC_CTRL_nNEUR parameter not correct.");
        assert(snn_0.spi_slave_0.SPI_MONITOR_NEUR_ADDR      == `SPI_MONITOR_NEUR_ADDR     ) else $fatal(0, "SPI_MONITOR_NEUR_ADDR parameter not correct.");
        assert(snn_0.spi_slave_0.SPI_MONITOR_SYN_ADDR       == `SPI_MONITOR_SYN_ADDR      ) else $fatal(0, "SPI_MONITOR_SYN_ADDR parameter not correct.");
        assert(snn_0.spi_slave_0.SPI_UPDATE_UNMAPPED_SYN    == `SPI_UPDATE_UNMAPPED_SYN   ) else $fatal(0, "SPI_UPDATE_UNMAPPED_SYN parameter not correct.");
        assert(snn_0.spi_slave_0.SPI_PROPAGATE_UNMAPPED_SYN == `SPI_PROPAGATE_UNMAPPED_SYN) else $fatal(0, "SPI_PROPAGATE_UNMAPPED_SYN parameter not correct.");
        assert(snn_0.spi_slave_0.SPI_SDSP_ON_SYN_STIM       == `SPI_SDSP_ON_SYN_STIM      ) else $fatal(0, "SPI_SDSP_ON_SYN_STIM parameter not correct.");
        $display("----- Ending verification of programmed SNN parameters, no error found!");
        
        SPI_param_checked = 1'b1;
        while (~SNN_initialized_rdy) wait_ns(1);
        
        
        /*****************************************************************************************************************************************************************************************************************
                                                                          COCHLEA NETWORK (controller modified to stop at neuron 16)
        *****************************************************************************************************************************************************************************************************************/
    
        fork
            auto_ack_and_monitoring(.req(AEROUT_REQ), .ack(AEROUT_ACK), .addr(AEROUT_ADDR));
        join_none

        $display("----- Launching network configuration...");

        $display("----- Disabling neurons 0-1.");   
        for (i=0; i<=1; i=i+1) begin
            addr_temp[15:8] = 15;   // Programming only last byte for disabling
            addr_temp[7:0]  = i;    // all neurons
            spi_write (.addr({1'b0,1'b1,2'b01,addr_temp[15:0]}), .data({4'b0,8'h7F,8'h80}), .MISO(MISO), .MOSI(MOSI), .SCK(SCK)); //Mask all bits in byte, except MSB
        end
        $display("----- Programming neurons 2-11 with phenomenological Izhikevich configuration (delay behavior)");
        for (i=2; i<=11; i=i+1) begin
			//Neuron programming data: asserted LSB for selecting LIF neuron model, all state information is initialized to zero
            param_dapdel = 1+((i-2)%5);
            shift_amt = 32'b0;
			neuron_pattern = {1'b0,61'b0,`PARAM_CALEAK,`PARAM_CA_THETA3,`PARAM_CA_THETA2,`PARAM_CA_THETA1,`PARAM_THETAMEM,`PARAM_CA_SYN_EN,
										 `PARAM_ACC_EN,`PARAM_THRLEAK,`PARAM_THR_SEL_OF,`PARAM_THRVAR_EN,`PARAM_RESON_EN,`PARAM_BIST_EN,
										 `PARAM_INHIN_EN,`PARAM_REBOUND_EN,`PARAM_NEG_EN,`PARAM_CLASS2_EN,`PARAM_MIXED_EN,`PARAM_PHASIC_EN,
										 `PARAM_STIM_THR,`PARAM_DAP_EN,`PARAM_SPKLAT_EN,param_dapdel[2:0],`PARAM_RFR,`PARAM_THR,`PARAM_ISI_REF,
										 `PARAM_SPK_REF,`PARAM_FI_SEL,`PARAM_LEAK_EN,`PARAM_LEAK_STR,1'b0};
	        for (j=0; j<16; j=j+1) begin
	            neur_data       = neuron_pattern >> shift_amt;
	            addr_temp[15:8] = j;    // All bytes of 
	            addr_temp[7:0]  = i;    // neuron i
	            spi_write (.addr({1'b0,1'b1,2'b01,addr_temp[15:0]}), .data({4'b0,8'h00,neur_data[7:0]}), .MISO(MISO), .MOSI(MOSI), .SCK(SCK));
	            shift_amt       = shift_amt + 32'd8;
	        end
	    end
        $display("----- Programming neurons 12-16 with LIF configuration");
        //Neuron programming data: asserted LSB for selecting LIF neuron model, all state information is initialized to zero
        for (i=12; i<=16; i=i+1) begin
            shift_amt = 32'b0;
            neuron_pattern = {1'b0,89'b0,`PARAM_CALEAK_LIF,`PARAM_CA_THETA3_LIF,`PARAM_CA_THETA2_LIF,`PARAM_CA_THETA1_LIF,`PARAM_THETAMEM_LIF,`PARAM_CA_SYN_EN_LIF,`PARAM_THR_LIF,`PARAM_LEAK_EN_LIF,`PARAM_LEAK_STR_LIF,1'b1};
	        for (j=0; j<16; j=j+1) begin
	            neur_data       = neuron_pattern >> shift_amt;
	            addr_temp[15:8] = j;    // All bytes of 
	            addr_temp[7:0]  = i;    // neuron i
	            spi_write (.addr({1'b0,1'b1,2'b01,addr_temp[15:0]}), .data({4'b0,8'h00,neur_data[7:0]}), .MISO(MISO), .MOSI(MOSI), .SCK(SCK));
	            shift_amt       = shift_amt + 32'd8;
	        end
	    end
        
        $display("----- Programming the synaptic array");
	
		// 				             0           1           2           3           4           5           6           7           8           9          10          11          12          13          14          15          16             
		syn_array =		'{'{{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd4},{1'b1,3'd4},{1'b1,3'd4},{1'b1,3'd4},{1'b1,3'd4},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0}},
						  '{{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd4},{1'b1,3'd4},{1'b1,3'd4},{1'b1,3'd4},{1'b1,3'd4},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0}},
						  '{{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd1},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0}},
						  '{{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd1},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0}},
						  '{{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd1},{1'b1,3'd0},{1'b1,3'd0}},
						  '{{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd1},{1'b1,3'd0}},
						  '{{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd1}},
						  '{{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd1}},
						  '{{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd1},{1'b1,3'd0}},
						  '{{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd1},{1'b1,3'd0},{1'b1,3'd0}},
						  '{{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd1},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0}},
						  '{{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd1},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0}},
						  '{{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0}},
						  '{{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0}},
						  '{{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0}},
						  '{{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0}},
						  '{{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0},{1'b1,3'd0}}};

        for (i=0; i<=16; i=i+1) begin // for each pre-neur
	        for (j=0; j<=16; j=j+1) begin // for each post-neur
				$display("Synapse pre %0d, post %0d is %0d", i, j, syn_array[i][j]);
                addr_temp[12: 0] = {i[7:0],j[7:3]};
                addr_temp[15:13] = {1'b0,j[2:1]};
                if (j[0])
                	spi_write (.addr({1'b0,1'b1,2'b10,addr_temp[15:0]}), .data({4'b0,8'h0F,{syn_array[i][j],4'b0}}), .MISO(MISO), .MOSI(MOSI), .SCK(SCK));
               	else
               		spi_write (.addr({1'b0,1'b1,2'b10,addr_temp[15:0]}), .data({4'b0,8'hF0,{4'b0,syn_array[i][j]}}), .MISO(MISO), .MOSI(MOSI), .SCK(SCK));
            end
        end

        //Re-enable network operation, keep it open-loop
        spi_write (.addr({1'b0,1'b0,2'b00,16'd0}), .data(20'd0), .MISO(MISO), .MOSI(MOSI), .SCK(SCK)); //SPI_GATE_ACTIVITY --> 0
        wait_ns(5000); // Wait for SPI transaction to be over
        
        

        /****************************************************************************************************************************
         *
		 *										          [INSERT INPUT STIMULUS HERE]
         *
         * Commands for input stimulus (x2):
         * 		right: aer_send (.addr_in({1'b0,8'd0,8'h07}), .addr_out(AERIN_ADDR), .ack(AERIN_ACK), .req(AERIN_REQ));
         * 		left : aer_send (.addr_in({1'b0,8'd1,8'h07}), .addr_out(AERIN_ADDR), .ack(AERIN_ACK), .req(AERIN_REQ));
         * Make sure that a time reference event is provided every 100µs with the following command:
         * 		aer_send (.addr_in({1'b0,8'b0,8'h7F}), .addr_out(AERIN_ADDR), .ack(AERIN_ACK), .req(AERIN_REQ));
         *
         ****************************************************************************************************************************/
		

		/*************************
		* Right stimulus
		*************************/
		// Spike from right cochlea comes in (x2)
		$display("----- Firing right stimulus 1");
		aer_send (.addr_in({1'b0,8'd0,8'h07}), .addr_out(AERIN_ADDR), .ack(AERIN_ACK), .req(AERIN_REQ));
		//$display("----- Firing right stimulus 2");
		//aer_send (.addr_in({1'b0,8'd0,8'h07}), .addr_out(AERIN_ADDR), .ack(AERIN_ACK), .req(AERIN_REQ));

		wait_ns(50);
		
		cochlea_sim_start = 1'b1;
		
		/*************************
		* Time difference
		*************************/
		wait_ns(38000);
		
		/*************************
		* Left stimulus
		*************************/
		$display("----- Firing left stimulus 1");
		aer_send (.addr_in({1'b0,8'd1,8'h07}), .addr_out(AERIN_ADDR), .ack(AERIN_ACK), .req(AERIN_REQ));
		//$display("----- Firing left stimulus 2");
		//aer_send (.addr_in({1'b0,8'd1,8'h07}), .addr_out(AERIN_ADDR), .ack(AERIN_ACK), .req(AERIN_REQ));

		/*$display("----- Firing time reference event");
		aer_send (.addr_in({1'b0,8'b0,8'h7F}), .addr_out(AERIN_ADDR), .ack(AERIN_ACK), .req(AERIN_REQ));
		wait_ns(10000);
		$display("----- Firing time reference event");
		aer_send (.addr_in({1'b0,8'b0,8'h7F}), .addr_out(AERIN_ADDR), .ack(AERIN_ACK), .req(AERIN_REQ));
		wait_ns(10000);
		$display("----- Firing time reference event");
		aer_send (.addr_in({1'b0,8'b0,8'h7F}), .addr_out(AERIN_ADDR), .ack(AERIN_ACK), .req(AERIN_REQ));
		wait_ns(10000);
		$display("----- Firing time reference event");
		aer_send (.addr_in({1'b0,8'b0,8'h7F}), .addr_out(AERIN_ADDR), .ack(AERIN_ACK), .req(AERIN_REQ));
		wait_ns(10000);
		$display("----- Firing time reference event");
		aer_send (.addr_in({1'b0,8'b0,8'h7F}), .addr_out(AERIN_ADDR), .ack(AERIN_ACK), .req(AERIN_REQ));
		wait_ns(10000);
		$display("----- Firing time reference event");
		aer_send (.addr_in({1'b0,8'b0,8'h7F}), .addr_out(AERIN_ADDR), .ack(AERIN_ACK), .req(AERIN_REQ));
		wait_ns(10000);
		$display("----- Firing time reference event");
		aer_send (.addr_in({1'b0,8'b0,8'h7F}), .addr_out(AERIN_ADDR), .ack(AERIN_ACK), .req(AERIN_REQ));
		wait_ns(10000);*/
		
    wait_ns(200000);
    $stop;
	 
	end
    
    
    /***************************
      SNN INSTANTIATION
    ***************************/
    
    ODIN snn_0 (
        // Global input     -------------------------------
        .CLK(CLK),
        .RST(RST),
        
        // SPI slave        -------------------------------
        .SCK(SCK),
        .MOSI(MOSI),
        .MISO(MISO),
        
        // Input 17-bit AER -------------------------------
        .AERIN_ADDR(AERIN_ADDR),
        .AERIN_REQ(AERIN_REQ),
        .AERIN_ACK(AERIN_ACK),

        // Output 8-bit AER -------------------------------
        .AEROUT_ADDR(AEROUT_ADDR),
        .AEROUT_REQ(AEROUT_REQ),
        .AEROUT_ACK(AEROUT_ACK)
    );    
    
    
    /***********************************************************************
                            TASK IMPLEMENTATIONS
    ************************************************************************/ 

    /***************************
     SIMPLE TIME-HANDLING TASK
    ***************************/
    
    // This routine is based on a correct definition of the simulation timescale.
    task wait_ns;
        input   tics_ns;
        integer tics_ns;
        #tics_ns;
    endtask

    
    /***************************
     AER send event
    ***************************/
    
    task automatic aer_send (
        input  logic [  16:0] addr_in,
        ref    logic [  16:0] addr_out,
        ref    logic          ack,
        ref    logic          req
    );
        while (ack) wait_ns(1);
        addr_out = addr_in;
        wait_ns(5);
        req = 1'b1;
        while (!ack) wait_ns(1);
        wait_ns(5);
        req = 1'b0;
    endtask

    
    /***************************
     AER automatic acknowledge
    ***************************/

    task automatic auto_ack_and_monitoring (
        ref    logic       req,
        ref    logic       ack,
        ref    logic [7:0] addr
    );
    
        //Simple automatic acknowledge task (retrieves the address of the source spiking neuron if automatic monitoring format is not enabled)
        forever begin
            while (~req) wait_ns(1);
            if (!`SPI_OUT_AER_MONITOR_EN)
                $display("Neuron %0d spiked!", addr);
            ack = 1'b1;
            while (req) wait_ns(1);
            ack = 1'b0;
        end
    endtask

    
    /***************************
     SPI write data
    ***************************/

    task automatic spi_write (
        input  logic [19:0] addr,
        input  logic [19:0] data,
        input  logic        MISO, // not used for SPI write
        ref    logic        MOSI,
        ref    logic        SCK
    );
        integer i;
        
        for (i=0; i<20; i=i+1) begin
            MOSI = addr[19-i];
            wait_ns(`SCK_HALF_PERIOD);
            SCK  = 1'b1;
            wait_ns(`SCK_HALF_PERIOD);
            SCK  = 1'b0;
        end
        for (i=0; i<20; i=i+1) begin
            MOSI = data[19-i];
            wait_ns(`SCK_HALF_PERIOD);
            SCK  = 1'b1;
            wait_ns(`SCK_HALF_PERIOD);
            SCK  = 1'b0;
        end
    endtask
    
    /***************************
     SPI read data
    ***************************/

    task automatic spi_read (
        input  logic [19:0] addr,
        output logic [19:0] data,
        ref    logic        MISO,
        ref    logic        MOSI,
        ref    logic        SCK
    );
        integer i;
        
        for (i=0; i<20; i=i+1) begin
            MOSI = addr[19-i];
            wait_ns(`SCK_HALF_PERIOD);
            SCK  = 1'b1;
            wait_ns(`SCK_HALF_PERIOD);
            SCK  = 1'b0;
        end
        for (i=0; i<20; i=i+1) begin
            wait_ns(`SCK_HALF_PERIOD);
            data = {data[18:0],MISO};
            SCK  = 1'b1;
            wait_ns(`SCK_HALF_PERIOD);
            SCK  = 1'b0;
        end
    endtask
    
    
endmodule 
