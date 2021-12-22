module uart_monitor(
	input txbr // Branch of the TX signal
	);

	parameter LOG_FILE = "uart-monitor.log";
	parameter BAUD_RATE = 6250000; // Max baud of DW UART, APB = 100MHz, div = 1
endmodule
