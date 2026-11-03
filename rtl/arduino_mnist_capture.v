// Captures 28x28 = 784 bytes from Arduino bit-serial stream
// and exposes them as write operations into a RAM.
module arduino_mnist_capture (
    input  wire       clk,            // 50 MHz system clock
    input  wire       resetn,         // active-low reset

    input  wire       serial_data_in, // from Arduino D2
    input  wire       bit_clk_in,     // from Arduino D3
    input  wire       frame_start_in, // from Arduino D4

    // Write interface to frame RAM (Port A)
    output reg        ram_we,
    output reg [9:0]  ram_addr,       // 0..783
    output reg [7:0]  ram_din,

    // Frame status
    output reg        frame_ready,

    // Debug: number of bit clocks seen since last frame_start
    output wire [12:0] bit_count_dbg
);

    // ------------------------------------------------------------------------
    // Parameters
    // ------------------------------------------------------------------------
    localparam TOTAL_PIXELS = 10'd784;

    // ------------------------------------------------------------------------
    // Synchronizers for external asynchronous signals
    // ------------------------------------------------------------------------
    reg [2:0] bit_clk_sync;
    reg [2:0] frame_start_sync;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            bit_clk_sync     <= 3'b000;
            frame_start_sync <= 3'b000;
        end else begin
            bit_clk_sync     <= {bit_clk_sync[1:0], bit_clk_in};
            frame_start_sync <= {frame_start_sync[1:0], frame_start_in};
        end
    end

    wire bit_clk_rising     = (bit_clk_sync[2:1]     == 2'b01);
    wire frame_start_rising = (frame_start_sync[2:1] == 2'b01);

    // ------------------------------------------------------------------------
    // Capture state
    // ------------------------------------------------------------------------
    reg        capturing;        // 1 while we are in the middle of a frame
    reg [2:0]  bit_index;        // 0..7 within a byte
    reg [9:0]  pixel_index;      // 0..783
    reg [7:0]  shift_reg;        // collects bits for one byte

    // Debug counter: number of bit clocks in the current frame
    reg [12:0] bit_count;
    assign bit_count_dbg = bit_count;

    // ------------------------------------------------------------------------
    // Main capture logic
    // ------------------------------------------------------------------------
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            ram_we      <= 1'b0;
            ram_addr    <= 10'd0;
            ram_din     <= 8'd0;
            frame_ready <= 1'b0;

            capturing   <= 1'b0;
            bit_index   <= 3'd0;
            pixel_index <= 10'd0;
            shift_reg   <= 8'd0;
            bit_count   <= 13'd0;
        end else begin
            // Default: no write this cycle
            ram_we <= 1'b0;

            // Start of a new frame
            if (frame_start_rising) begin
                // Only start a new capture if we are currently idle
                capturing   <= 1'b1;
                bit_index   <= 3'd0;
                pixel_index <= 10'd0;
                shift_reg   <= 8'd0;
                frame_ready <= 1'b0;
                bit_count   <= 13'd0;
            end

            // Only pay attention to bit clocks while capturing
            if (capturing && bit_clk_rising) begin
                // Count how many bit clocks we see this frame
                bit_count <= bit_count + 13'd1;

                // LSB-first: place the incoming bit into the shift register
                shift_reg[bit_index] <= serial_data_in;

                if (bit_index == 3'd7) begin
                    // 8th bit completes this byte
                    // serial_data_in is MSB for this cycle
                    ram_addr <= pixel_index;
                    ram_din  <= {serial_data_in, shift_reg[6:0]};
                    ram_we   <= 1'b1;

                    bit_index <= 3'd0;

                    if (pixel_index == (TOTAL_PIXELS - 1)) begin
                        // Last pixel of the frame
                        frame_ready <= 1'b1;
                        capturing   <= 1'b0;  // stop capturing until next frame_start
                    end else begin
                        pixel_index <= pixel_index + 10'd1;
                    end
                end else begin
                    bit_index <= bit_index + 3'd1;
                end
            end
        end
    end

endmodule





