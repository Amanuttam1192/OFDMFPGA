`timescale 1ns / 1ps
// basys3_ofdm_top.v - board wrapper for the HDL Coder generated ofdm_system
//   SW0..SW3 -> data_in[0..3]        BTNU -> start      BTNC -> reset
//   LD12 <- data_out[0]   (from SW0)
//   LD13 <- data_out[1]   (from SW1)
//   LD14 <- data_out[2]   (from SW2)
//   LD15 <- data_out[3]   (from SW3)
//   LD11 <- data_valid
//   all other LEDs off
module basys3_ofdm_top (
    input  wire        clk,      // 100 MHz
    input  wire        btnC,     // reset
    input  wire        btnU,     // start
    input  wire [3:0]  sw,       // data_in
    output wire [15:0] led
);
    // ---- synchronise inputs to the clock ----
    reg [1:0] rst_s   = 2'b11;
    reg [2:0] start_s = 3'b000;
    reg [3:0] sw_s1   = 4'b0, sw_s2 = 4'b0;

    always @(posedge clk) begin
        rst_s   <= {rst_s[0], btnC};
        start_s <= {start_s[1:0], btnU};
        sw_s1   <= sw;
        sw_s2   <= sw_s1;
    end

    // one clock-wide start pulse on the button's rising edge
    wire start_pulse = start_s[1] & ~start_s[2];

    wire [3:0] data_out;
    wire       data_valid;

    ofdm_system u_ofdm (
        .clk        (clk),
        .reset      (rst_s[1]),
        .start      (start_pulse),
        .data_in    (sw_s2),
        .data_out   (data_out),
        .data_valid (data_valid)
    );

    // ---- LED mapping ----
    assign led[10:0]  = 11'b0;          // unused, off
    assign led[11]    = data_valid;
    assign led[15:12] = data_out;       // LD15..LD12 = bit3..bit0
endmodule
