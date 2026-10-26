// ============================================================================
// File: hbm3_phy_deserializer.sv
// Project: Open_HBM3_PHY
// Technology: ASAP7 7nm FinFET Predictive PDK (WCK Target: 4.6 GHz)
// Description:
//   Single-lane 1:N DDR deserializer with dynamic bitslip fine phase alignment.
//   Captures 2 bits per WCK cycle (rising & falling edge) into a 32-bit shift window.
//   The bitslip input adjusts the 8-bit output slice pointer by 1 bit per pulse.
// ============================================================================

`include "hbm3_phy_defs.svh"

module hbm3_phy_deserializer #(
    parameter int SER_RATIO = HBM3_SER_RATIO // Default: 8
)(
    input  logic                 wck,
    input  logic                 rst_n,
    input  logic                 dq_rise,  // Sampled from WCK rising edge
    input  logic                 dq_fall,  // Sampled from WCK falling edge
    input  logic                 align,    // Global beat boundary reset pulse
    input  logic                 bitslip,  // Pulse to shift sampling window by 1 bit
    output logic [SER_RATIO-1:0] pdata,    // Deserialized parallel word
    output logic                 pvalid    // Asserted when a new beat is assembled
);
    localparam int HALF     = SER_RATIO / 2; // 4 WCK cycles per beat
    localparam int WIN      = 4 * SER_RATIO; // 32-bit window
    localparam int CNT_BITS = (HALF > 1) ? $clog2(HALF) : 1;
    localparam int SEL_MAX  = WIN - SER_RATIO; // 32 - 8 = 24
    localparam int SEL_BITS = $clog2(SEL_MAX + 1); // 5 bits

    logic [WIN-1:0]      window_q;
    logic [CNT_BITS-1:0] cnt_q;
    logic [SEL_BITS-1:0] sel_q;
    wire  [SEL_BITS-1:0] sel = sel_q; // Hierarchical probe alias for testbenches
    logic [WIN-1:0]      window_nxt;

    // Window update with incoming DDR bits
    assign window_nxt = {dq_fall, dq_rise, window_q[WIN-1:2]};

    always_ff @(posedge wck or negedge rst_n) begin
        if (!rst_n) begin
            window_q <= '0;
            cnt_q    <= '0;
            sel_q    <= SEL_BITS'(SEL_MAX);
            pdata    <= '0;
            pvalid   <= 1'b0;
        end else begin
            window_q <= window_nxt;

            // Bitslip pointer adjustment
            if (bitslip) begin
                sel_q <= (sel_q == '0) ? SEL_BITS'(SEL_MAX) : (sel_q - 1'b1);
            end

            // Beat boundary counter & parallel output generation
            if (align) begin
                cnt_q  <= '0;
                pvalid <= 1'b0;
            end else if (cnt_q == CNT_BITS'(HALF - 1)) begin
                cnt_q  <= '0;
                pvalid <= 1'b1;
                pdata  <= window_nxt[sel_q +: SER_RATIO];
            end else begin
                cnt_q  <= cnt_q + 1'b1;
                pvalid <= 1'b0;
            end
        end
    end

endmodule
