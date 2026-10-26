# ==============================================================================
# Open_HBM3_PHY Subsystem Makefile
# 1.18 TB/s HBM3/HBM3E Complete Physical Layer (ASAP7 7nm FinFET)
# ==============================================================================

RTL_SRCS = \
	rtl/hbm3_phy_serializer.sv \
	rtl/hbm3_phy_deserializer.sv \
	rtl/hbm3_phy_elastic_buffer.sv \
	rtl/hbm3_phy_rx_channel.sv \
	rtl/hbm3_phy_tx_channel.sv \
	rtl/hbm3_phy_training.sv \
	rtl/hbm3_phy_rst_buf.sv \
	rtl/hbm3_phy_async_fifo.sv \
	rtl/hbm3_phy_gearbox_2to1_cdc.sv \
	rtl/open_hbm3_phy_top.sv

all: test_all

test_link:
	iverilog -g2012 -DSIMULATION -I rtl -o sim_phy_link \
		$(RTL_SRCS) tb/tb_open_hbm3_phy_link.sv
	vvp sim_phy_link

test_torture:
	iverilog -g2012 -DSIMULATION -I rtl -o sim_phy_torture \
		$(RTL_SRCS) tb/tb_open_hbm3_phy_torture.sv
	vvp sim_phy_torture

synth_check:
	yosys -p "read_verilog -sv -I rtl $(RTL_SRCS); hierarchy -check -top open_hbm3_phy_top; proc; opt; check -assert"

test_all: test_link test_torture synth_check
	@echo "================================================================================"
	@echo "   >>> ALL OPEN_HBM3_PHY VERIFICATION & SYNTHESIS SUITES PASSED! <<<"
	@echo "================================================================================"

clean:
	rm -f sim_phy_link sim_phy_torture *.vcd

.PHONY: all test_link test_torture synth_check test_all clean
