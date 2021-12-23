`timescale 1ns/10ps

module uart_monitor(
	input txbr // Branch of the TX signal
	);

	parameter LOG_FILE = "uart-monitor.log";
	parameter BAUD_RATE = 6250000; // Max baud of DW UART in simulation with APB = 100MHz, div = 1
	//parameter BAUD_RATE = 115200; // Normal baud

	localparam MY_CLK_FREQ = 100*1000*1000; // Internal clock of fixed frequency 100MHz
	localparam MY_CLK_PERIOD_NS = 1000*1000*1000/MY_CLK_FREQ;
	localparam CLKS_PER_BIT = MY_CLK_FREQ/BAUD_RATE;

	logic my_clk;
	integer logfd;

	initial begin
		my_clk = 0;

		// Create an empty file to save log
		logfd = $fopen(LOG_FILE, "w");
		$fclose(logfd);
	end

	always
		#(MY_CLK_PERIOD_NS/2) my_clk = !my_clk;

	localparam S_IDLE    = 3'b000;
	localparam S_START   = 3'b001;
	localparam S_DATA    = 3'b010;
	localparam S_STOP    = 3'b011;
	localparam S_CLEANUP = 3'b100;

	reg [16:0] r_Clock_Count = 0;
	reg [2:0]  r_Bit_Index   = 0; //8 bits total
	reg [7:0]  r_RX_Byte     = 0;
	reg        r_RX_DV       = 0;
	reg [2:0]  r_SM_Main     = 0;

	always @(posedge my_clk) begin
		case (r_SM_Main)
			S_IDLE : begin
				r_RX_DV       <= 1'b0;
				r_Clock_Count <= 0;
				r_Bit_Index   <= 0;

				if (txbr == 1'b0)
					r_SM_Main <= S_START;
				else
					r_SM_Main <= S_IDLE;
			end

			S_START : begin
				if (r_Clock_Count == (CLKS_PER_BIT-1)/2) begin
					if (txbr == 1'b0) begin
						r_Clock_Count <= 0;
						r_SM_Main     <= S_DATA;
					end else
						r_SM_Main <= S_IDLE;
				end else begin
					r_Clock_Count <= r_Clock_Count + 1;
					r_SM_Main     <= S_START;
				end
			end

			S_DATA : begin
				if (r_Clock_Count < CLKS_PER_BIT-1) begin
					r_Clock_Count <= r_Clock_Count + 1;
					r_SM_Main     <= S_DATA;
				end else begin
					r_Clock_Count          <= 0;
					r_RX_Byte[r_Bit_Index] <= txbr;

					if (r_Bit_Index < 7) begin
						r_Bit_Index <= r_Bit_Index + 1;
						r_SM_Main   <= S_DATA;
					end else begin
						r_Bit_Index <= 0;
						r_SM_Main   <= S_STOP;
					end
				end
			end

			S_STOP : begin
				if (r_Clock_Count < CLKS_PER_BIT-1) begin
					r_Clock_Count <= r_Clock_Count + 1;
					r_SM_Main     <= S_STOP;
				end else begin
					r_RX_DV       <= 1'b1;
					r_Clock_Count <= 0;
					r_SM_Main     <= S_CLEANUP;
				end
			end

			S_CLEANUP : begin
				r_SM_Main <= S_IDLE;
				r_RX_DV   <= 1'b0;

				// Re-open logfile as flushing out
				logfd = $fopen(LOG_FILE, "a");
				$fwrite(logfd, "%c", r_RX_Byte);
				$fclose(logfd);
			end

			default :
				r_SM_Main <= S_IDLE;
		endcase
	end

endmodule
