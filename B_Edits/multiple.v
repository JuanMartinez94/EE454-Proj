module multiple (
    input CLOCK_50,       // System Clock
    input UART_RXD,      // UART Receive Line
    output UART_TXD,     // UART Transmit Line
    input SWITCH_1,      // Input for Switch 1 (active high when flipped)
    output [7:0] lcd_data,  // LCD Data Output
    output lcd_rs,       // LCD Register Select
    output lcd_rw,       // LCD Read/Write Select
    output lcd_en        // LCD Enable
);

    wire rx_ready;
    wire [7:0] rx_data;
    reg [7:0] tx_data;
    reg tx_start;
    reg [1:0] state; // State for sending multiple values
    reg [7:0] lcd_message [0:15];  // Declare the message array to be passed
    reg [3:0] lcd_index;  // Index for the lcd_message array

    // Instantiate UART Modules
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

    // Instantiate LCD Module
    lcd lcd_display (
        .clk(CLOCK_50),
        .reset_n(1'b1),  // Assume active low reset is tied high (modify as needed)
        .input_data(lcd_message[lcd_index]),  // Pass one character at a time
        .data_valid(rx_ready),  // Data valid signal from UART RX
        .data(lcd_data),
        .rs(lcd_rs),
        .rw(lcd_rw),
        .en(lcd_en)
    );

    // LED Control Logic (indicates RX data received)
    always @(posedge CLOCK_50) begin
        if (rx_ready) begin
            // Store received data into lcd_message array
            lcd_message[lcd_index] <= rx_data;  // Update the current character on the LCD
        end
    end

    // State Machine for Transmission
    always @(posedge CLOCK_50) begin
        if (SWITCH_1) begin // When SWITCH_1 is flipped (active high)
            case (state)
                2'b00: begin
                    // Send value 22 (ASCII code 50 for '2' and 52 for '4')
                    if (!tx_busy) begin
                        tx_data <= 8'd50; // ASCII '2'
                        tx_start <= 1'b1;
                        state <= 2'b01;
                    end
                end

                2'b01: begin
                    // Wait for TX to finish
                    if (tx_busy) begin
                        tx_start <= 1'b0;
                    end else if (!tx_busy) begin
                        state <= 2'b10;
                    end
                end

                2'b10: begin
                    // Send value 45 (ASCII code 52 for '4' and 53 for '5')
                    if (!tx_busy) begin
                        tx_data <= 8'd52; // ASCII '4'
                        tx_start <= 1'b1;
                        state <= 2'b11;
                    end
                end

                2'b11: begin
                    // Wait for TX to finish
                    if (tx_busy) begin
                        tx_start <= 1'b0;
                    end else if (!tx_busy) begin
                        state <= 2'b00; // Loop back to send again if needed
                    end
                end
            endcase
        end else begin
            // If SWITCH_1 is not flipped, stay in idle state
            state <= 2'b00;
        end
    end

    // Update the LCD index to display the next character
    always @(posedge CLOCK_50) begin
        if (rx_ready && lcd_index < 15) begin
            lcd_index <= lcd_index + 1;  // Move to the next character position on the LCD
        end else if (lcd_index == 15) begin
            lcd_index <= 0; // Reset the index if the message is full
        end
    end

endmodule
