module cnn_conv5x5_core (
    input        clk,
    input        reset_n,      // active-low reset
    input        start,        // start signal
    output reg   done,         // goes high when all convs finished

    // ---- act_buf connections (read-only) ----
    output reg [9:0] act_address,   // 0..783
    output reg       act_wren,      // always 0
    input      [7:0] act_q,         // pixel data from act_buf_ram

    // ---- wgt_buf (rom_byte) connections ----
    output reg [8:0] wgt_address,   // 0..199 (8 filters * 25 weights)
    output reg       wgt_rden,      // read enable
    input      [7:0] wgt_q,         // weight data (signed)

    // ---- out_buf write port ----
    output reg [12:0] out_wraddress, // 0..8*24*24-1
    output reg [7:0]  out_data,      // output activation
    output reg        out_wren,      // write enable

    // ---- debug outputs ----
    output reg [9:0]  offset_k,     // current input address (debug)
    output reg [4:0]  k             // current kernel index 0..24 (debug)
);

    // ----------------------------------------------------------------
    // Parameters
    // ----------------------------------------------------------------
    localparam NUM_FILTERS    = 8;
    localparam OUT_H          = 24;
    localparam OUT_W          = 24;
    localparam OUT_PER_FILTER = OUT_H * OUT_W;      // 576
    localparam WEIGHTS_PER_F  = 25;                 // 5x5

    // FSM states
    localparam S_IDLE        = 3'd0;
    localparam S_SETUP_PIXEL = 3'd1;
    localparam S_ADDR_TAP    = 3'd2;
    localparam S_WAIT_TAP    = 3'd3;
    localparam S_ACCUM_TAP   = 3'd4;
    localparam S_WRITE_RES   = 3'd5;
    localparam S_NEXT_PIXEL  = 3'd6;
    localparam S_DONE        = 3'd7;

    reg [2:0] state;

    // Loop indices
    reg [2:0]  filter_idx;    // 0..7
    reg [4:0]  row_idx;       // 0..23
    reg [4:0]  col_idx;       // 0..23

    // Kernel tap index (0..24)
    reg [4:0]  local_k;

    // Base address of current 5x5 window in the 28x28 image
    reg [9:0]  base_addr;

    // ----------------------------------------------------------------
    // Convolution math
    // ----------------------------------------------------------------

    // Invert + threshold pixel if you want (helps match MNIST convention)
 

    wire signed [8:0]  pixel_sext  = {1'b0, act_q};     // 0..255
    wire signed [7:0]  weight_sext = wgt_q;                   // signed
    wire signed [16:0] product     = pixel_sext * weight_sext;

    reg  signed [23:0] sum;                                   // accumulator

    // Row/col inside kernel from local_k
    wire [2:0] k_row = local_k / 5;
    wire [2:0] k_col = local_k % 5;

    // Address for current tap
    wire [9:0] tap_act_addr = base_addr + k_row * 28 + k_col;
    wire [8:0] tap_wgt_addr = filter_idx * WEIGHTS_PER_F + local_k;

    // ----------------------------------------------------------------
    // Main FSM with address issue, RAM/ROM latency, then MAC
    // ----------------------------------------------------------------
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state         <= S_IDLE;
            done          <= 1'b0;

            act_address   <= 10'd0;
            act_wren      <= 1'b0;

            wgt_address   <= 9'd0;
            wgt_rden      <= 1'b0;

            out_wraddress <= 13'd0;
            out_data      <= 8'd0;
            out_wren      <= 1'b0;

            filter_idx    <= 3'd0;
            row_idx       <= 5'd0;
            col_idx       <= 5'd0;
            local_k       <= 5'd0;
            base_addr     <= 10'd0;
            sum           <= 24'sd0;
            offset_k      <= 10'd0;
            k             <= 5'd0;
        end else begin
            // Defaults
            act_wren <= 1'b0;
            wgt_rden <= 1'b0;
            out_wren <= 1'b0;
            done     <= 1'b0;

            case (state)
                // ------------------
                S_IDLE: begin
                    if (start) begin
                        filter_idx <= 3'd0;
                        row_idx    <= 5'd0;
                        col_idx    <= 5'd0;
                        state      <= S_SETUP_PIXEL;
                    end
                end

                // ------------------
                // Compute base_addr, reset sum and tap index
                // ------------------
                S_SETUP_PIXEL: begin
                    base_addr <= row_idx * 28 + col_idx;
                    local_k   <= 5'd0;
                    sum       <= 24'sd0;
                    state     <= S_ADDR_TAP;
                end

                // ------------------
                // Cycle 1 for this tap: set addresses, DON'T use q yet
                // ------------------
                S_ADDR_TAP: begin
                    act_address <= tap_act_addr;
                    wgt_address <= tap_wgt_addr;
                    wgt_rden    <= 1'b1;

                    offset_k    <= tap_act_addr;  // debug
                    k           <= local_k;       // debug

                    state       <= S_WAIT_TAP;
                end

                // ------------------
                // Registered addresses issued in S_ADDR_TAP are sampled by
                // the RAM/ROM on this edge; consume the outputs NEXT cycle.
                // ------------------
                S_WAIT_TAP: begin
                    state <= S_ACCUM_TAP;
                end

                // Both input and weight data now correspond to this tap.
                S_ACCUM_TAP: begin
                    sum <= sum + product;

                    if (local_k < WEIGHTS_PER_F - 1) begin
                        local_k <= local_k + 5'd1;
                        state   <= S_ADDR_TAP;  // next tap
                    end else begin
                        // all 25 taps done
                        state <= S_WRITE_RES;
                    end
                end

                // ------------------
                // Write conv result to out_buf with ReLU + saturation
                // ------------------
                S_WRITE_RES: begin
                    if (sum <= 0)
                        out_data <= 8'd0;
                    else if (sum > 24'sd255)
                        out_data <= 8'd255;
                    else
                        out_data <= sum[7:0];

                    out_wraddress <= filter_idx * OUT_PER_FILTER +
                                     row_idx    * OUT_W +
                                     col_idx;
                    out_wren      <= 1'b1;

                    state         <= S_NEXT_PIXEL;
                end

                // ------------------
                // Advance col/row/filter
                // ------------------
                S_NEXT_PIXEL: begin
                    if (col_idx < OUT_W - 1) begin
                        col_idx <= col_idx + 5'd1;
                        state   <= S_SETUP_PIXEL;
                    end else if (row_idx < OUT_H - 1) begin
                        col_idx <= 5'd0;
                        row_idx <= row_idx + 5'd1;
                        state   <= S_SETUP_PIXEL;
                    end else if (filter_idx < NUM_FILTERS - 1) begin
                        col_idx    <= 5'd0;
                        row_idx    <= 5'd0;
                        filter_idx <= filter_idx + 3'd1;
                        state      <= S_SETUP_PIXEL;
                    end else begin
                        done  <= 1'b1;
                        state <= S_DONE;
                    end
                end

                // ------------------
                S_DONE: begin
                    state <= S_IDLE;  // permit future frames
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule

