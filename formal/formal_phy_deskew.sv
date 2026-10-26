// ============================================================================
// File: formal_phy_deskew.sv
// Project: Open_HBM3_PHY (Formal Verification Suite)
// Description:
//   Formal SVA Property Suite proving mathematical invariants of the
//   Per-Lane Elastic Deskew Buffer and 2-Phase Training Engine.
// ============================================================================

`include "hbm3_phy_defs.svh"

module formal_phy_deskew (
    input logic clk,
    input logic rst_n,

    // Monitored interface
    input logic        train_start,
    input logic        train_done,
    input logic        train_ok,
    input logic [63:0] train_bit_locked,
    input logic        train_deskew_locked,
    input logic        all_lanes_ready,
    input logic        err_overflow,
    input logic        err_underflow,
    input logic        par_valid,
    input logic [511:0] par_data
);

`ifdef FORMAL
    // ------------------------------------------------------------------------
    // Property 1: Bounded Liveness (Training Must Settle or Signal Done)
    // ------------------------------------------------------------------------
    // Once started, training cannot hang in an infinite loop without done
    property p_bounded_training;
        @(posedge clk) disable iff (!rst_n)
        $rose(train_start) |-> s_eventually(train_done);
    endproperty
    assert property (p_bounded_training);

    // ------------------------------------------------------------------------
    // Property 2: Conservation of Deskew (No Spurious Lock Before All Ready)
    // ------------------------------------------------------------------------
    // Deskew lock can NEVER be asserted unless all 64 lanes report ready
    property p_deskew_safety;
        @(posedge clk) disable iff (!rst_n)
        train_deskew_locked |-> all_lanes_ready;
    endproperty
    assert property (p_deskew_safety);

    // ------------------------------------------------------------------------
    // Property 3: Phase Ordering (Phase 2 Cannot Occur Before Phase 1)
    // ------------------------------------------------------------------------
    // Deskew can never lock if bit-lock is incomplete
    property p_phase_ordering;
        @(posedge clk) disable iff (!rst_n)
        train_deskew_locked |-> (&train_bit_locked);
    endproperty
    assert property (p_phase_ordering);

    // ------------------------------------------------------------------------
    // Property 4: Zero Buffer Faults Under Normal Synchronized Operation
    // ------------------------------------------------------------------------
    // Once deskew is locked, overflow and underflow must strictly remain 0
    property p_zero_faults_post_lock;
        @(posedge clk) disable iff (!rst_n)
        train_deskew_locked |-> (!err_overflow && !err_underflow);
    endproperty
    assert property (p_zero_faults_post_lock);

`endif

endmodule
