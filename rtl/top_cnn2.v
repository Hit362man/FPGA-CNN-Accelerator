module m2 (
    input         CLOCK_50,      // DE1-SoC main clock
    input  [3:0]  KEY,           // KEY[0] = reset_n (active-low)
    input  [9:0]  SW,            // SW[0] = start
    output [6:0]  HEX0,

    input         serial_data_in,   // from Arduino D2
    input         bit_clk_in,       // from Arduino D3
    input         frame_start_in    // from Arduino D4
);

    //---------------------------------------------------
    // Reset / control
    //---------------------------------------------------
    wire reset_n  = KEY[0];
    wire start_sw = SW[0];

    //---------------------------------------------------
    // Arduino capture -> activation buffer
    //---------------------------------------------------
    wire        cap_we;
    wire [9:0]  cap_addr;
    wire [7:0]  cap_din;
    wire        frame_ready;
    wire [12:0] bit_count_dbg;

    arduino_mnist_capture cap_inst (
        .clk            (CLOCK_50),
        .resetn         (reset_n),
        .serial_data_in (serial_data_in),
        .bit_clk_in     (bit_clk_in),
        .frame_start_in (frame_start_in),
        .ram_we         (cap_we),
        .ram_addr       (cap_addr),
        .ram_din        (cap_din),
        .frame_ready    (frame_ready),
        .bit_count_dbg  (bit_count_dbg)
    );

    //---------------------------------------------------
    // act_buf RAM (28x28 input image)
    //---------------------------------------------------
    wire [9:0] act_addr_b;
    wire [7:0] act_q_b;

    act_buf_ram act_buf_inst (
        .clk    (CLOCK_50),
        .we_a   (cap_we),
        .addr_a (cap_addr),
        .din_a  (cap_din),
        .addr_b (act_addr_b),
        .dout_b (act_q_b)
    );

    //---------------------------------------------------
    // Convolution weights ROM (rom_byte)
    //---------------------------------------------------
    wire [8:0] wgt_address;
    wire       wgt_rden;
    wire [7:0] wgt_q;

    rom_byte wgt_rom_inst (
        .address (wgt_address),
        .clock   (CLOCK_50),
        .rden    (wgt_rden),
        .q       (wgt_q)
    );

    //---------------------------------------------------
    // out_buf for conv output feature maps
    //---------------------------------------------------
    wire [7:0]  out_data;
    wire [12:0] out_wraddress;
    wire        out_wren;

    wire [12:0] out_rdaddress;
    wire        out_rden;
    wire [7:0]  out_q;

    out_buf out_buf_inst (
        .clock     (CLOCK_50),
        .data      (out_data),
        .rdaddress (out_rdaddress),
        .rden      (out_rden),
        .wraddress (out_wraddress),
        .wren      (out_wren),
        .q         (out_q)
    );

    //---------------------------------------------------
    // Convolution core
    //---------------------------------------------------
    wire        conv_done;
    reg         conv_start;

    wire [9:0]  conv_act_address;
    wire        conv_act_wren_unused;

    wire [9:0]  offset_k;
    wire [4:0]  k_debug;

    cnn_conv5x5_core conv_inst (
        .clk           (CLOCK_50),
        .reset_n       (reset_n),
        .start         (conv_start),
        .done          (conv_done),

        .act_address   (conv_act_address),
        .act_wren      (conv_act_wren_unused),
        .act_q         (act_q_b),

        .wgt_address   (wgt_address),
        .wgt_rden      (wgt_rden),
        .wgt_q         (wgt_q),

        .out_wraddress (out_wraddress),
        .out_data      (out_data),
        .out_wren      (out_wren),

        .offset_k      (offset_k),
        .k             (k_debug)
    );

    assign act_addr_b = conv_act_address;

    //---------------------------------------------------
    // Predictor (sums per filter + argmax)
    //---------------------------------------------------
    wire        pred_done;
    reg         pred_start;
    wire [2:0]  pred_digit_raw;

    wire [18:0] filter_sum_0;
    wire [18:0] filter_sum_1;
    wire [18:0] filter_sum_2;
    wire [18:0] filter_sum_3;
    wire [18:0] filter_sum_4;
    wire [18:0] filter_sum_5;
    wire [18:0] filter_sum_6;
    wire [18:0] filter_sum_7;

    cnn_predictor pred_inst (
        .clk          (CLOCK_50),
        .reset_n      (reset_n),
        .start        (pred_start),
        .done         (pred_done),
        .digit        (pred_digit_raw),
        .rdaddress    (out_rdaddress),
        .rden         (out_rden),
        .q            (out_q),
        .filter_sum_0 (filter_sum_0),
        .filter_sum_1 (filter_sum_1),
        .filter_sum_2 (filter_sum_2),
        .filter_sum_3 (filter_sum_3),
        .filter_sum_4 (filter_sum_4),
        .filter_sum_5 (filter_sum_5),
        .filter_sum_6 (filter_sum_6),
        .filter_sum_7 (filter_sum_7)
    );

    //---------------------------------------------------
    // FC weights ROM (fc_rom, using fc_weights.mif)
    //---------------------------------------------------
    wire [6:0] fc_addr;
    wire       fc_rden;
    wire [7:0] fc_q;

    fc_rom fc_weights_inst (
        .address (fc_addr),
        .clock   (CLOCK_50),
        .rden    (fc_rden),
        .q       (fc_q)
    );

    //---------------------------------------------------
    // Fully-connected classifier
    //---------------------------------------------------
    wire        fc_done;
    reg         fc_start;
    wire [3:0]  fc_digit;

    cnn_fc_classifier fc_inst (
        .clk             (CLOCK_50),
        .reset_n         (reset_n),
        .start           (fc_start),
        .done            (fc_done),

        .filter_sum_0    (filter_sum_0),
        .filter_sum_1    (filter_sum_1),
        .filter_sum_2    (filter_sum_2),
        .filter_sum_3    (filter_sum_3),
        .filter_sum_4    (filter_sum_4),
        .filter_sum_5    (filter_sum_5),
        .filter_sum_6    (filter_sum_6),
        .filter_sum_7    (filter_sum_7),

        .fc_addr         (fc_addr),
        .fc_rden         (fc_rden),
        .fc_q            (fc_q),

        .predicted_digit (fc_digit)
    );

    //---------------------------------------------------
    // Seven-segment display driven by the FPGA FC classifier
    //---------------------------------------------------
    digit_to_hex0 hex0_inst (
        .digit (fc_digit),
        .HEX0  (HEX0)
    );

    //---------------------------------------------------
    // Top-level control FSM: IDLE -> CONV -> PRED -> FC -> DONE
    //---------------------------------------------------
    localparam T_IDLE     = 3'd0;
    localparam T_RUN_CONV = 3'd1;
    localparam T_RUN_PRED = 3'd2;
    localparam T_RUN_FC   = 3'd3;
    localparam T_DONE     = 3'd4;

    reg [2:0] top_state;
    // frame_ready remains high after capture completes. A pending-frame flag
    // ensures a frame is processed at most once, even if SW[0] is toggled.
    reg frame_ready_prev;
    reg frame_pending;

    always @(posedge CLOCK_50 or negedge reset_n) begin
        if (!reset_n) begin
            top_state  <= T_IDLE;
            conv_start <= 1'b0;
            pred_start <= 1'b0;
            fc_start   <= 1'b0;
            frame_ready_prev <= 1'b0;
            frame_pending    <= 1'b0;
        end else begin
            conv_start <= 1'b0;
            pred_start <= 1'b0;
            fc_start   <= 1'b0;

            frame_ready_prev <= frame_ready;
            if (frame_ready && !frame_ready_prev)
                frame_pending <= 1'b1;

            case (top_state)
                T_IDLE: begin
                    if (frame_pending && start_sw) begin
                        frame_pending <= 1'b0;
                        conv_start <= 1'b1;
                        top_state  <= T_RUN_CONV;
                    end
                end

                T_RUN_CONV: begin
                    if (conv_done) begin
                        pred_start <= 1'b1;
                        top_state  <= T_RUN_PRED;
                    end
                end

                T_RUN_PRED: begin
                    if (pred_done) begin
                        fc_start  <= 1'b1;
                        top_state <= T_RUN_FC;
                    end
                end

                T_RUN_FC: begin
                    if (fc_done) begin
                        top_state <= T_DONE;
                    end
                end

                T_DONE: begin
                    if (!start_sw) begin
                        top_state <= T_IDLE;
                    end
                end

                default: top_state <= T_IDLE;
            endcase
        end
    end

endmodule
