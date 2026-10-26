// ============================================================================
// File: hbm3_phy_analog_model.sv
// Project: Open_HBM3_PHY (1.18 TB/s HBM3E PHY Subsystem)
// Technology: ASAP7 7nm FinFET Predictive PDK (WCK Target: 4.6 GHz)
// Description:
//   Simulation Contract Model for HBM3 Analog Front-End (AFE):
//   - In synthesis: synthesizes as clean bypass or declared as (* blackbox *).
//   - In simulation: models physical channel latency, per-lane trace skews,
//     and analog driver/receiver delays for 64 differential DQ lanes.
// ============================================================================

`include "hbm3_phy_defs.svh"

module hbm3_phy_analog_model #(
    parameter int DQ_LANES  = HBM3_DQ_LANES_PER_CHANNEL,       // 64
    parameter int SER_RATIO = HBM3_SER_RATIO                   // 8
)(
    input  logic                 wck,
    input  logic                 rst_n,

    // TX Side (from digital TX channel)
    input  logic [DQ_LANES-1:0]  tx_dq_rise,
    input  logic [DQ_LANES-1:0]  tx_dq_fall,

    // Channel skew injection controls (Simulation Only)
    input  logic [2:0]           lane_bit_skew [0:DQ_LANES-1], // 0..7 bit fractional skew
    input  logic [1:0]           lane_beat_skew [0:DQ_LANES-1],// 0..3 discrete beat delay

    // RX Side (to digital RX channel)
    output logic [DQ_LANES-1:0]  rx_dq_rise,
    output logic [DQ_LANES-1:0]  rx_dq_fall,

    // Status / Health
    output logic                 pll_locked_o,
    output logic                 analog_ready_o
);

`ifdef SYNTHESIS
    // Clean zero-logic pass-through for digital synthesis and STA signoff
    assign rx_dq_rise     = tx_dq_rise;
    assign rx_dq_fall     = tx_dq_fall;
    assign pll_locked_o   = 1'b1;
    assign analog_ready_o = 1'b1;

`else
    // ------------------------------------------------------------------------
    // Behavioral Simulation Channel with Per-Lane Skew Pipelines
    // ------------------------------------------------------------------------
    localparam int HIST_LEN = 32; // 32-bit history shift register per lane

    logic [HIST_LEN-1:0] pipe_r [0:DQ_LANES-1];
    logic [HIST_LEN-1:0] pipe_f [0:DQ_LANES-1];
    logic [7:0]          pll_timer_q;
    logic                pll_locked_q;

    assign pll_locked_o   = pll_locked_q;
    assign analog_ready_o = pll_locked_q;

    // Emulate PLL acquisition lock time (64 cycles)
    always_ff @(posedge wck or negedge rst_n) begin
        if (!rst_n) begin
            pll_timer_q  <= '0;
            pll_locked_q <= 1'b0;
        end else begin
            if (pll_timer_q < 8'd64) begin
                pll_timer_q  <= pll_timer_q + 1'b1;
                pll_locked_q <= 1'b0;
            end else begin
                pll_locked_q <= 1'b1;
            end
        end
    end

    // Per-Lane Delay History Shift Registers
    always_ff @(posedge wck or negedge rst_n) begin
        for (int l = 0; l < DQ_LANES; l++) begin
            if (!rst_n) begin
                pipe_r[l] <= '0;
                pipe_f[l] <= '0;
            end else begin
                pipe_r[l] <= {tx_dq_rise[l], pipe_r[l][HIST_LEN-1:1]};
                pipe_f[l] <= {tx_dq_fall[l], pipe_f[l][HIST_LEN-1:1]};
            end
        end
    end

    // Tap selection based on configured channel skew
    always_comb begin
        for (int l = 0; l < DQ_LANES; l++) begin
            int tap;
            // Tap calculation: (beat_skew * 4) + (bit_skew / 2)
            tap = (int'(lane_beat_skew[l]) * 4) + (int'(lane_bit_skew[l]) >> 1);
            if (tap >= HIST_LEN) tap = HIST_LEN - 1;

            rx_dq_rise[l] = pipe_r[l][tap];
            rx_dq_fall[l] = pipe_f[l][tap];
        end
    end

`endif

endmodule
