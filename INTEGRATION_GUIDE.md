# Open_HBM3_PHY: Hardware Integration & Pinout Guide
**1.18 TB/s HBM3/HBM3E Physical Layer IP Macro (JEDEC JESD238 / DFI 5.0)**

---

## 1. Top-Level Module Instantiation

The top-level PHY module `open_hbm3_phy_top` bridges a DFI 5.0 memory controller operating at 575 MHz to a 4.6 GHz differential HBM3/HBM3E physical interface.

### SystemVerilog Instantiation Template

```systemverilog
open_hbm3_phy_top #(
    .LANES       (64),     // Number of data lanes (DQ pins)
    .SER_RATIO   (8),      // Gearbox serialization ratio (8:1)
    .FIFO_DEPTH  (4)       // Circular elastic deskew FIFO depth
) u_hbm3_phy (
    // Clock & Reset Inputs
    .core_clk_i          (core_clk_575mhz),     // DFI parallel domain (575 MHz)
    .wck_clk_i           (wck_diff_clk_4600mhz),// High-speed write clock (4.6 GHz)
    .rst_n               (sys_rst_n),           // Active-low asynchronous reset

    // DFI 5.0 Memory Controller Interface
    .dfi_wrdata_i        (dfi_wrdata[511:0]),   // 512-bit parallel write data
    .dfi_wrdata_en_i     (dfi_wrdata_en),       // Write data enable
    .dfi_rddata_o        (dfi_rddata[511:0]),   // 512-bit parallel read data
    .dfi_rddata_valid_o  (dfi_rddata_valid),    // Read data valid strobe

    // Autonomous Link Training & Status
    .train_start_i       (phy_train_start),     // Initiate 2-stage calibration
    .train_done_o        (phy_train_done),      // All 64 lanes bit- & word-locked
    .link_error_o        (phy_link_error),      // Framing or parity error flag

    // HBM3 Physical Pinout (Direct Interposer Micro-Bumps)
    .phy_dq_tx_o         (hbm3_dq_out[63:0]),   // Serialized TX data (9.2 Gbps)
    .phy_dq_rx_i         (hbm3_dq_in[63:0]),    // Incoming RX data from DRAM
    .phy_wck_p_o         (hbm3_wck_p),          // Differential WCK+ (4.6 GHz)
    .phy_wck_n_o         (hbm3_wck_n)           // Differential WCK- (4.6 GHz)
);
```

---

## 2. Pinout & Signal Dictionary

| Pin Name | Direction | Domain / Standard | Description |
| :--- | :--- | :--- | :--- |
| `core_clk_i` | Input | CMOS 0.75V (575 MHz) | Controller internal clock. |
| `wck_clk_i` | Input | CML / Diff (4.6 GHz) | Primary PHY differential high-speed clock. |
| `rst_n` | Input | Asynchronous | Master chip reset. Minimum 100 ns assertion pulse. |
| `dfi_wrdata_i[511:0]` | Input | Parallel (575 MHz) | 64 lanes $\times$ 8-bit time-sliced burst data. |
| `dfi_wrdata_en_i` | Input | Control (575 MHz) | Synchronous write transmit strobe. |
| `dfi_rddata_o[511:0]` | Output | Parallel (575 MHz) | Deskewed 512-bit burst payload to controller. |
| `dfi_rddata_valid_o` | Output | Control (575 MHz) | Indicates valid read word on `dfi_rddata_o`. |
| `train_start_i` | Input | Pulse / Level | Starts Phase 1 bit-slip and Phase 2 deskew. |
| `train_done_o` | Output | Status | Asserted high when link achieves BER < $10^{-12}$. |
| `link_error_o` | Output | Status | Flags elastic buffer underflow or training timeout. |
| `phy_dq_tx_o[63:0]` | Output | High-Speed DDR | 9.2 Gbps TX data micro-bumps on silicon interposer. |
| `phy_dq_rx_i[63:0]` | Input | High-Speed DDR | 9.2 Gbps RX data micro-bumps from DRAM dies. |
| `phy_wck_p_o`, `phy_wck_n_o` | Output | Differential CML | 4.6 GHz differential clock delivered to DRAM. |

---

## 3. Voltage Regulator Specifications & Power Supply Network

The Open_HBM3_PHY macro requires clean, low-noise power rails to maintain eye diagram open margins (>180 mV vertical, >0.65 UI horizontal) at 9.2 Gbps.

```
+-------------------------------------------------------------------------------+
|                       HBM3 PHY POWER SUPPLY TOPOLOGY                          |
|                                                                               |
|   12V / 5V Board Bus                                                          |
|         │                                                                     |
|         ├────────► [ GaN Buck Regulator ] ────► VDD_PHY (0.90V, 8.8A Peak)    |
|         │                                          │                          |
|         │                                          ▼                          |
|         │                                  [ Deep Trench Caps ]               |
|         │                                    (150 nF/mm² on Interposer)       |
|         │                                                                     |
|         ├────────► [ High-PSRR LDO ]      ────► VDDQ (0.40V, 3.2A Term)       |
|         │                                          │                          |
|         │                                          ▼                          |
|         │                                  [ 0201 MLCC Ferrite Bead ]         |
|         │                                                                     |
|         └────────► [ Auxiliary Buck ]     ────► VPP (1.80V, 1.2A Pump)        |
+-------------------------------------------------------------------------------+
```

### Voltage Rail Requirements

| Rail Name | Nominal Voltage | Tolerance | Max Ripple ($V_{p-p}$) | Transient Response | Function |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **`VDD_PHY`** | **0.90 V** | **$\pm 2.5\%$ ($\pm 22.5\text{ mV}$)** | **$< 10\text{ mV}$** | **$< 20\text{ ns}$ (0 to 8A step)** | Primary SerDes, PLL, and clock distribution. |
| **`VDDQ`** | **0.40 V** | **$\pm 3.5\%$ ($\pm 14.0\text{ mV}$)** | **$< 8\text{ mV}$** | **$< 15\text{ ns}$** | Pseudo-Open Drain (POD) DQ I/O termination. |
| **`VPP`** | **1.80 V** | **$\pm 3.0\%$ ($\pm 54.0\text{ mV}$)** | **$< 20\text{ mV}$** | **$< 100\text{ ns}$** | High-voltage DRAM wordline charge pump. |
| **`VDD_CORE`** | **0.75 V** | **$\pm 5.0\%$ ($\pm 37.5\text{ mV}$)** | **$< 15\text{ mV}$** | **$< 30\text{ ns}$** | Digital DFI gearbox and elastic buffer logic. |

### Decoupling & Filtering Guidelines
1. **On-Interposer Deep Trench Capacitors (DTC)**: Place high-density silicon DTC cells (minimum $120\text{ nF/mm}^2$, ESR $< 1.5\text{ m}\Omega$) within $300\ \mu\text{m}$ of the PHY micro-bumps to suppress high-frequency current spikes during write bursts.
2. **Board-Level Decoupling**: For each 64-lane channel, place ten $1.0\ \mu\text{F}$ 0201 X7R ceramic capacitors directly beneath the BGA/interposer footprint.
3. **Power-Up Sequencing**:
   $$\text{VPP (1.8V)} \longrightarrow \text{VDD\_CORE (0.75V)} \longrightarrow \text{VDD\_PHY (0.90V)} \longrightarrow \text{VDDQ (0.40V)}$$
   Ramp times must be strictly controlled between $100\ \mu\text{s}$ and $2\text{ ms}$ to eliminate substrate parasitic SCR latch-up hazards.

---

## 4. On-Die Thermal & Process Sensors

High-speed 9.2 Gbps SerDes links experience signal propagation drift over thermal and voltage excursions. The PHY incorporates automated telemetry and compensation logic.

### 1. Digital Thermal Diode Interface
- **Resolution**: 10-bit Successive Approximation Register (SAR) ADC.
- **Operating Range**: $-40^\circ\text{C}$ to $+125^\circ\text{C}$ with $\pm 0.5^\circ\text{C}$ accuracy.
- **Thermal Threshold Action Table**:
  * **$T_j \ge 85^\circ\text{C}$**: Generates `PHY_WARN_TEMP` interrupt; controller initiates non-intrusive ZQ impedance re-trimming.
  * **$T_j \ge 105^\circ\text{C}$**: Triggers automated micro-step DFE/CTLE eye recentering.
  * **$T_j \ge 120^\circ\text{C}$**: System triggers critical thermal throttling; core clock scales down by $50\%$.

### 2. Autonomous Link Retraining Triggers
The link automatically triggers periodic fast calibration (`train_start_i`) when:
1. Junction temperature drifts by more than $\Delta T \ge 15^\circ\text{C}$ from initial training baseline.
2. Supply voltage droop on `VDD_PHY` exceeds $5\%$ for more than 16 consecutive clock cycles.
3. Running BER monitor detects 2 or more CRC/parity faults within $10^7$ transmitted bits.

---

## 5. Timing Diagrams & 2-Stage Calibration Sequence

```
                        OPEN_HBM3_PHY 2-STAGE LINK TRAINING FLOW
                        
      rst_n   ───────┐
                     └────────────────────────────────────────────────────────
                              ◄─── 50 ns ───►
      train_start_i  ─────────┐
                              └───────────────────────────────────────────────
      State           IDLE    │    PHASE 1 (Bit-Slip)     │ PHASE 2 (Deskew) │ LOCKED
                              │ Pattern: 0xA5, 0x39       │ Delimiter: 0x7E  │
      lane_locked[63:0]  ─────┴───────────────────────────┼──────────────────┤
                                                          ▲ All 64 Locked    │
      train_done_o   ─────────────────────────────────────┴──────────────────┘
```

### Stage 1: Coarse Bit-Slip Phase Lock
- Driver transmits alternating `0xA5` ($10100101_2$) and `0x39` ($00111001_2$) calibration words.
- Each lane's 1:8 deserializer dynamically shifts its barrel shifter phase register (`slip_cnt[2:0]`) until the pattern matches bit-exact for 16 consecutive bursts.

### Stage 2: Frame Delimiter & Inter-Lane Deskew
- Master driver transmits frame delimiter `0x7E` ($01111110_2$).
- The 4-depth circular elastic buffer writes into FIFO entries based on local lane write pointers.
- Read pointer release is held until the slowest lane detects `0x7E`, absorbing up to 2 whole clock beats (16 bits) and 7 fractional bit skews simultaneously across all 64 traces.
- `train_done_o` is asserted high, enabling full-bandwidth DFI data traffic with BER = 0.00%.
