module lcd (
    input wire clk,        // 50 MHz clock
    input wire reset_n,    // Active-low reset
    input wire [7:0] input_data, // Input data to display (received from the board)
    input wire data_valid,  // Signal to indicate that new data is available
    output reg [7:0] data, // LCD data lines
    output reg rs,         // Register select (0 = Command, 1 = Data)
    output reg rw,         // Read/Write select (0 = Write, 1 = Read)
    output reg en          // Enable signal
);

    // Internal states
    localparam IDLE     = 3'b000,
               INIT     = 3'b001,
               WRITE    = 3'b010,
               FINISH   = 3'b011;

    reg [2:0] state;
    reg [19:0] delay_counter;  // Delay for initialization and timing control
    reg [3:0] char_index;
    reg [7:0] lcd_message [0:15];  // 16 characters of LCD message

    // Clock Divider: Generate a ~1 kHz clock from 50 MHz clock
    reg [15:0] clk_divider;
    reg slow_clk;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            clk_divider <= 0;
            slow_clk <= 0;
        end else if (clk_divider == 16'd24_999) begin // 50,000 clock cycles for 50 MHz to 1 kHz
            clk_divider <= 0;
            slow_clk <= ~slow_clk;
        end else begin
            clk_divider <= clk_divider + 1;
        end
    end

    // Main FSM
    always @(posedge slow_clk or negedge reset_n) begin
        if (!reset_n) begin
            state <= IDLE;
            delay_counter <= 0;
            char_index <= 0;
            en <= 0;
            data <= 8'h00;
            rs <= 0;
            rw <= 0;
        end else begin
            case (state)
                IDLE: begin
                    delay_counter <= 20'd0;
                    en <= 0;
                    state <= INIT;
                end

                INIT: begin
                    // Initial delay after power-up
                    if (delay_counter < 20'd1_000) begin // Adjust as needed
                        delay_counter <= delay_counter + 1;
                    end else begin
                        delay_counter <= 0;
                        state <= WRITE;
                    end
                end

                WRITE: begin
                    if (data_valid) begin
                        // If new data is valid, update the message array
                        data <= input_data;
                        rs <= 1; // Data mode
                        en <= 1;

                        if (delay_counter < 20'd20) begin
                            delay_counter <= delay_counter + 1;
                        end else begin
                            en <= 0;
                            delay_counter <= 0;
                            if (char_index < 15) begin
                                char_index <= char_index + 1;
                            end else begin
                                state <= FINISH;
                            end
                        end
                    end
                end

                FINISH: begin
                    // Hold in this state after completing the display
                    en <= 0;
                end
            endcase
        end
    end

endmodule
