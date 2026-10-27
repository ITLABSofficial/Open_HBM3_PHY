// SPDX-License-Identifier: Apache-2.0
// Formal Verification Harness: Open_HBM3_PHY 2-Phase Link Training FSM & 64-Step Phase Interpolator
`default_nettype none

module formal_hbm3_phy_training (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       dfi_init_start_i,
    input  wire       wdqs_level_ok_i,
    input  wire       rdqs_eye_ok_i,
    input  wire       Watchdog_timeout_i,
    output logic [2:0] state_o,
    output logic [5:0] pi_code_o,
    output logic       dfi_init_complete_o,
    output logic       train_err_o
);
    typedef enum logic [2:0] {
        ST_RESET       = 3'd0,
        ST_PHASE1_WDQS = 3'd1,
        ST_PHASE2_RDQS = 3'd2,
        ST_LOCKED      = 3'd3,
        ST_ERR_RECOVER = 3'd4
    } state_t;

    state_t state;
    assign state_o = state;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state               <= ST_RESET;
            pi_code_o           <= 6'd0;
            dfi_init_complete_o <= 1'b0;
            train_err_o         <= 1'b0;
        end else begin
            case (state)
                ST_RESET: begin
                    dfi_init_complete_o <= 1'b0;
                    train_err_o         <= 1'b0;
                    if (dfi_init_start_i) begin
                        state     <= ST_PHASE1_WDQS;
                        pi_code_o <= 6'd16;
                    end
                end
                ST_PHASE1_WDQS: begin
                    if (Watchdog_timeout_i) begin
                        state       <= ST_ERR_RECOVER;
                        train_err_o <= 1'b1;
                    end else if (wdqs_level_ok_i) begin
                        state     <= ST_PHASE2_RDQS;
                        pi_code_o <= 6'd32; // Center of 0.5 UI read eye
                    end else begin
                        pi_code_o <= pi_code_o + 6'd1;
                    end
                end
                ST_PHASE2_RDQS: begin
                    if (Watchdog_timeout_i) begin
                        state       <= ST_ERR_RECOVER;
                        train_err_o <= 1'b1;
                    end else if (rdqs_eye_ok_i) begin
                        state               <= ST_LOCKED;
                        dfi_init_complete_o <= 1'b1;
                    end else begin
                        pi_code_o <= pi_code_o + 6'd1;
                    end
                end
                ST_LOCKED: begin
                    if (!dfi_init_start_i) begin
                        state               <= ST_RESET;
                        dfi_init_complete_o <= 1'b0;
                    end
                end
                ST_ERR_RECOVER: begin
                    state               <= ST_RESET;
                    dfi_init_complete_o <= 1'b0;
                    train_err_o         <= 1'b0;
                end
                default: state <= ST_RESET;
            endcase
        end
    end

`ifdef FORMAL
    initial assume(!rst_n);

    always @(posedge clk) begin
        if (rst_n) begin
            // Invariant 1: Valid state encoding (Zero unreachable/illegal states)
            assert(state <= ST_ERR_RECOVER);
            // Invariant 2: Mutual exclusion between dfi_init_complete_o and train_err_o
            assert(!(dfi_init_complete_o && train_err_o));
            // Invariant 3: dfi_init_complete_o asserted if and only if state == ST_LOCKED
            assert(dfi_init_complete_o == (state == ST_LOCKED));
            // Invariant 4: Error trap state always self-recovers to ST_RESET in 1 cycle (Zero Deadlock)
            if ($past(rst_n) && ($past(state) == ST_ERR_RECOVER)) begin
                assert(state == ST_RESET);
                assert(!train_err_o);
            end
        end
    end
`endif
endmodule
