// ============================================================================
// File: hbm3_phy_serializer.sv
// Project: Open_HBM3_PHY
// Technology: ASAP7 7nm FinFET Predictive PDK (WCK Target: 4.6 GHz)
// Description:
//   Single-lane N:1 serializer with DDR output (dq_rise, dq_fall).
//   Takes an 8-bit parallel word at beat boundary and shifts out 2 bits per WCK
//   cycle (one for rising edge, one for falling edge).
// ============================================================================

`include "hbm3_phy_defs.svh"

module hbm3_phy_serializer #(
    parameter int SER_RATIO = HBM3_SER_RATIO // Default: 8
)(
    input  logic                 wck,
    input  logic                 rst_n,
    input  logic                 load,     // Parallel data capture pulse
    input  logic [SER_RATIO-1:0] pdata,    // 8-bit parallel payload
    output logic                 dq_rise,  // Driven on WCK rising edge
    output logic                 dq_fall   // Driven on WCK falling edge
);
    // Synthesis assertion for even DDR ratio
    initial begin
        if (SER_RATIO % 2 != 0) begin
            $fatal(1, "hbm3_phy_serializer: SER_RATIO must be even for DDR (%0d)", SER_RATIO);
        end
    end

    logic [SER_RATIO-1:0] shift_q;

    // Shift register: consumes 2 bits per WCK cycle (DDR)
    always_ff @(posedge wck or negedge rst_n) begin
        if (!rst_n) begin
            shift_q <= '0;
        end else if (load) begin
            shift_q <= pdata;
        end else begin
            shift_q <= {2'b00, shift_q[SER_RATIO-1:2]};
        end
    end

    // Direct register outputs to eliminate combinatorial logic on pad path
    assign dq_rise = shift_q[0];
    assign dq_fall = shift_q[1];

endmodule
