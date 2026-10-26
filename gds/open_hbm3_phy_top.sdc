###############################################################################
# Created by write_sdc
# Mon Oct 12 22:14:57 2026
###############################################################################
current_design open_hbm3_phy_top
###############################################################################
# Timing Constraints
###############################################################################
create_clock -name wck -period 217.4000 [get_ports {wck}]
set_propagated_clock [get_clocks {wck}]
create_clock -name phy_clk -period 869.6000 [get_ports {phy_clk}]
set_propagated_clock [get_clocks {phy_clk}]
create_clock -name core_clk -period 500.0000 [get_ports {core_clk}]
set_propagated_clock [get_clocks {core_clk}]
set_clock_groups -name group1 -asynchronous \
 -group [get_clocks {core_clk}]\
 -group [get_clocks {phy_clk}]\
 -group [get_clocks {wck}]
set_false_path\
    -from [list [get_ports {core_rst_n}]\
           [get_ports {core_tx_flush}]\
           [get_ports {phy_rst_n}]\
           [get_ports {train_start}]]
###############################################################################
# Environment
###############################################################################
###############################################################################
# Design Rules
###############################################################################
set_max_fanout 32.0000 [current_design]
