module transceiver (
    input CLOCK_50,     // System Clock
    input [0:0] SW,     // Switch Input
    output [0:0] LEDG,  // Green LED Output
    input UART_RXD,     // UART Receive Line
    output UART_TXD     // UART Transmit Line
);

    wire rx_ready;
    wire tx_busy;
    wire [7:0] rx_data;
    reg [7:0] tx_data;
    reg tx_start;
    reg led_state;
    reg prev_sw_state;

    // UART Modules
    uart_tx transmitter (
        .clk(CLOCK_50),
        .tx_start(tx_start),
        .tx_data(tx_data),
        .tx_line(UART_TXD),
        .tx_busy(tx_busy)
    );

    uart_rx receiver (
        .clk(CLOCK_50),
        .rx_line(UART_RXD),
        .rx_data(rx_data),
        .rx_ready(rx_ready)
    );

    // LED Control Logic
    always @(posedge CLOCK_50) begin
        if (rx_ready) begin
            led_state <= rx_data[0];
        end
    end
    assign LEDG[0] = led_state;

    // State Machine for Transmission
    always @(posedge CLOCK_50) begin
        prev_sw_state <= SW[0];

        if (SW[0] != prev_sw_state && !tx_busy) begin
            tx_data <= SW[0] ? 8'b00000001 : 8'b00000000;
            tx_start <= 1'b1;
        end else if (tx_busy) begin
            tx_start <= 1'b0;
        end
    end
endmodule

module uart_tx (
    input clk,
    input tx_start,
    input [7:0] tx_data,
    output reg tx_line,
    output reg tx_busy
);
    parameter CLOCK_RATE = 50_000_000;
    parameter BAUD_RATE = 9600;
    localparam CLOCK_DIVIDE = CLOCK_RATE / (BAUD_RATE * 16);

    reg [3:0] bit_count;
    reg [7:0] shift_reg;
    reg [9:0] baud_count;

    always @(posedge clk) begin
        if (!tx_busy && tx_start) begin
            // Start transmission
            tx_busy <= 1'b1;
            shift_reg <= tx_data;
            bit_count <= 4'd0;
            tx_line <= 1'b0;  // Start bit
            baud_count <= 10'd0;
        end else if (tx_busy) begin
            // Baud rate generation
            if (baud_count == CLOCK_DIVIDE) begin
                baud_count <= 10'd0;
                
                if (bit_count < 8) begin
                    // Shift out data bits
                    tx_line <= shift_reg[0];
                    shift_reg <= {1'b0, shift_reg[7:1]};
                    bit_count <= bit_count + 1'b1;
                end else if (bit_count == 8) begin
                    // Stop bit
                    tx_line <= 1'b1;
                    bit_count <= bit_count + 1'b1;
                end else begin
                    // End transmission
                    tx_busy <= 1'b0;
                end
            end else begin
                baud_count <= baud_count + 1'b1;
            end
        end
    end
endmodule

module uart_rx (
    input clk,
    input rx_line,
    output reg [7:0] rx_data,
    output reg rx_ready
);
    parameter CLOCK_RATE = 50_000_000;
    parameter BAUD_RATE = 9600;
    localparam CLOCK_DIVIDE = CLOCK_RATE / (BAUD_RATE * 16);

    reg [3:0] bit_count;
    reg [9:0] baud_count;
    reg [7:0] shift_reg;
    reg receiving;

    always @(posedge clk) begin
        // Detect start bit
        if (!receiving && !rx_line) begin
            receiving <= 1'b1;
            bit_count <= 4'd0;
            baud_count <= {10{1'b1}} - (CLOCK_DIVIDE >> 1);
            rx_ready <= 1'b0;
        end

        if (receiving) begin
            if (baud_count == CLOCK_DIVIDE) begin
                baud_count <= 10'd0;
                
                if (bit_count < 8) begin
                    shift_reg <= {rx_line, shift_reg[7:1]};
                    bit_count <= bit_count + 1'b1;
                end else if (bit_count == 8) begin
                    // Stop bit
                    rx_data <= shift_reg;
                    rx_ready <= 1'b1;
                    receiving <= 1'b0;
                end
            end else begin
                baud_count <= baud_count + 1'b1;
            end
        end
    end
endmodule