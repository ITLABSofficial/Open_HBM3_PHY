// ============================================================================
// File: hbm3_phy_rx_channel.sv
// Project: Open_HBM3_PHY (1.18 TB/s HBM3E PHY Subsystem)
// Technology: ASAP7 7nm FinFET Predictive PDK (WCK Target: 4.6 GHz)
// Description:
//   64-Lane Physical RX Channel combining 1:8 DDR Deserializers with Per-Lane
//   Elastic Deskew Buffers. Converts 64 DQ differential pin streams into
//   a 512-bit deskewed, cycle-aligned, and bit-exact parallel bus.
// ============================================================================

`include "hbm3_phy_defs.svh"

module hbm3_phy_rx_channel #(
    parameter int DQ_LANES  = HBM3_DQ_LANES_PER_CHANNEL,       // 64
    parameter int SER_RATIO = HBM3_SER_RATIO                   // 8
)(
    input  logic                                 wck,
    input  logic                                 rst_n,

    // Physical pin interface (from pad ring / analog receiver)
    input  logic [DQ_LANES-1:0]                  dq_rise,
    input  logic [DQ_LANES-1:0]                  dq_fall,

    // Training & Alignment Controls
    input  logic                                 align,            // Global beat boundary pulse
    input  logic [DQ_LANES-1:0]                  bitslip,          // Per-lane bitslip pulses
    input  logic                                 arm_deskew    = 1'b0, // Enable frame marker detection
    input  logic                                 clr_deskew    = 1'b0, // Clear/re-arm elastic buffers
    input  logic                                 bypass_deskew = 1'b1, // 1: Direct deserializer output, 0: Deskewed
    input  logic [SER_RATIO-1:0]                 frame_marker  = 8'h7E,// Frame delimiter marker (8'h7E)

    // Parallel Interface to Controller / Gearbox
    output logic [DQ_LANES*SER_RATIO-1:0]        par_data,
    output logic                                 par_valid,

    // Status & Diagnostics
    output logic [DQ_LANES-1:0]                  lane_marker_seen,
    output logic [DQ_LANES-1:0]                  lane_has_payload,
    output logic                                 all_lanes_ready,
    output logic                                 deskew_active_o,
    output logic                                 overflow_err_o,
    output logic                                 underflow_err_o
);
    localparam int HALF     = SER_RATIO / 2; // 4 WCK cycles
    localparam int CNT_BITS = (HALF > 1) ? $clog2(HALF) : 1;

    logic [SER_RATIO-1:0]         deser_pdata [0:DQ_LANES-1];
    logic [DQ_LANES-1:0]          deser_pvalid;
    logic [SER_RATIO-1:0]         buf_rdata   [0:DQ_LANES-1];
    logic [DQ_LANES-1:0]          buf_ovf, buf_udf;
    logic                         global_rd_en;
    logic                         deskew_running_q;
    logic [CNT_BITS-1:0]          pop_cnt_q;
    logic                         all_lanes_buffered;

    assign all_lanes_ready    = &lane_marker_seen;
    assign all_lanes_buffered = &lane_has_payload;
    assign overflow_err_o     = |buf_ovf;
    assign underflow_err_o    = |buf_udf;
    assign deskew_active_o    = deskew_running_q;

    // ------------------------------------------------------------------------
    // Deskew Global Read Synchronization FSM
    // ------------------------------------------------------------------------
    always_ff @(posedge wck or negedge rst_n) begin
        if (!rst_n) begin
            deskew_running_q <= 1'b0;
            pop_cnt_q        <= '0;
            global_rd_en     <= 1'b0;
        end else if (clr_deskew) begin
            deskew_running_q <= 1'b0;
            pop_cnt_q        <= '0;
            global_rd_en     <= 1'b0;
        end else begin
            if (!deskew_running_q) begin
                if (all_lanes_buffered && !bypass_deskew) begin
                    deskew_running_q <= 1'b1;
                    pop_cnt_q        <= '0;
                    global_rd_en     <= 1'b1; // Trigger first synchronous pop
                end else begin
                    global_rd_en     <= 1'b0;
                end
            end else begin
                // Synchronous pop cadence: exactly once every 4 WCK cycles (1 beat)
                if (pop_cnt_q == CNT_BITS'(HALF - 1)) begin
                    pop_cnt_q    <= '0;
                    global_rd_en <= 1'b1;
                end else begin
                    pop_cnt_q    <= pop_cnt_q + 1'b1;
                    global_rd_en <= 1'b0;
                end
            end
        end
    end

    // ------------------------------------------------------------------------
    // Generate 64 Deserializers and 64 Elastic Deskew Buffers
    // ------------------------------------------------------------------------
    genvar l;
    generate
        for (l = 0; l < DQ_LANES; l = l + 1) begin : g_lane
            // Tier 1: Intra-Beat Bit Alignment via Bitslip Deserializer
            hbm3_phy_deserializer #(
                .SER_RATIO (SER_RATIO)
            ) u_des (
                .wck     (wck),
                .rst_n   (rst_n),
                .dq_rise (dq_rise[l]),
                .dq_fall (dq_fall[l]),
                .align   (align),
                .bitslip (bitslip[l]),
                .pdata   (deser_pdata[l]),
                .pvalid  (deser_pvalid[l])
            );

            // Tier 2: Inter-Beat Frame Deskew via Elastic FIFO
            hbm3_phy_elastic_buffer #(
                .SER_RATIO (SER_RATIO),
                .DEPTH     (HBM3_ELASTIC_BUF_DEPTH)
            ) u_elastic_buf (
                .wck             (wck),
                .rst_n           (rst_n),
                .clr_deskew      (clr_deskew),
                .arm_deskew      (arm_deskew),
                .frame_marker_i  (frame_marker),
                .wr_en           (deser_pvalid[l]),
                .wr_data         (deser_pdata[l]),
                .rd_en           (global_rd_en),
                .rd_data         (buf_rdata[l]),
                .marker_seen_o   (lane_marker_seen[l]),
                .has_payload_o   (lane_has_payload[l]),
                .occupancy_o     (),
                .overflow_err_o  (buf_ovf[l]),
                .underflow_err_o (buf_udf[l])
            );

            // Output multiplexing: bypass vs. deskewed
            assign par_data[l*SER_RATIO +: SER_RATIO] = bypass_deskew ? deser_pdata[l] : buf_rdata[l];
        end
    endgenerate

    // Output valid pulse
    assign par_valid = bypass_deskew ? deser_pvalid[0] : global_rd_en;

endmodule
