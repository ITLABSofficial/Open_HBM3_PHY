// ============================================================================
// File: hbm3_phy_tx_channel.sv
// Project: Open_HBM3_PHY (1.18 TB/s HBM3E PHY Subsystem)
// Technology: ASAP7 7nm FinFET Predictive PDK (WCK Target: 4.6 GHz)
// Description:
//   64-Lane Physical TX Channel converting a 512-bit parallel bus into 64 DQ
//   differential DDR pin streams. Features registered 1-cycle lookahead load
//   to meet timing closure at 4.6 GHz WCK in 7nm FinFET.
// ============================================================================

`include "hbm3_phy_defs.svh"

module hbm3_phy_tx_channel #(
    parameter int DQ_LANES  = HBM3_DQ_LANES_PER_CHANNEL,       // 64
    parameter int SER_RATIO = HBM3_SER_RATIO                   // 8
)(
    input  logic                                 wck,
    input  logic                                 rst_n,

    // Parallel interface (from Gearbox / Controller)
    input  logic                                 par_valid,
    output logic                                 par_ready,
    input  logic [DQ_LANES*SER_RATIO-1:0]        par_data,

    // Serial physical pin interface (to pad ring / analog driver)
    output logic [DQ_LANES-1:0]                  dq_rise,
    output logic [DQ_LANES-1:0]                  dq_fall,
    output logic                                 dq_active,
    output logic                                 beat_start
);
    localparam int HALF     = SER_RATIO / 2; // 4 WCK cycles
    localparam int CNT_BITS = (HALF > 1) ? $clog2(HALF) : 1;

    logic [CNT_BITS-1:0] cnt;
    logic                load;

    always_ff @(posedge wck or negedge rst_n)
        if (!rst_n) cnt <= '0;
        else        cnt <= (cnt == CNT_BITS'(HALF - 1)) ? '0 : cnt + 1'b1;

    // Load signal is registered one cycle early: (cnt == HALF-1) asserts on the
    // cycle before cnt rolls over to 0. Registered output becomes high precisely at cnt==0.
    always_ff @(posedge wck or negedge rst_n)
        if (!rst_n) load <= 1'b1;      // First beat boundary right after reset
        else        load <= (cnt == CNT_BITS'(HALF - 1));

    assign par_ready  = load;          // Accepted only at beat boundary
    assign beat_start = load;

    logic [DQ_LANES*SER_RATIO-1:0] beat_data;
    always_comb beat_data = (par_valid) ? par_data : '0;

    always_ff @(posedge wck or negedge rst_n)
        if (!rst_n)     dq_active <= 1'b0;
        else if (load)  dq_active <= par_valid;

    genvar l;
    generate
        for (l = 0; l < DQ_LANES; l = l + 1) begin : g_lane
            hbm3_phy_serializer #(
                .SER_RATIO (SER_RATIO)
            ) u_ser (
                .wck     (wck),
                .rst_n   (rst_n),
                .load    (load),
                .pdata   (beat_data[l*SER_RATIO +: SER_RATIO]),
                .dq_rise (dq_rise[l]),
                .dq_fall (dq_fall[l])
            );
        end
    endgenerate

endmodule
