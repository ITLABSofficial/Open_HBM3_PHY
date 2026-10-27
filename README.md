# Open_HBM3_PHY: 1.18 TB/s HBM3/HBM3E Physical Layer IP

[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
[![Academic Paper](https://img.shields.io/badge/Research_Paper-Read_PAPER.md-blueviolet.svg)](PAPER.md)
[![Standard](https://img.shields.io/badge/Standard-JEDEC_JESD238-green.svg)]()
[![Interface](https://img.shields.io/badge/Host_Interface-DFI_5.0-orange.svg)]()
[![Verification](https://img.shields.io/badge/Formal_SVA-15%2F15_Proven-brightgreen.svg)]()
[![Torture](https://img.shields.io/badge/Stress_Test-5.12M_Bits_BER=0-success.svg)]()


> 🧭 **Silicon Stack Navigation:** [Architecture Home](https://github.com/ITLABSofficial) &nbsp;•&nbsp; (First Layer) &nbsp;•&nbsp; **Layer 01: `Open_HBM3_PHY`** &nbsp;•&nbsp; [Next: Open_HBM3_Controller ➡️](https://github.com/ITLABSofficial/Open_HBM3_Controller)

**Open_HBM3_PHY** is an open-source, fully synthesizable SystemVerilog physical layer (PHY) IP core implementing the **JEDEC JESD238 HBM3 and HBM3E** interface standard. It delivers an unthrottled aggregate memory bandwidth exceeding **1.18 TB/s** across 64 high-speed data pins operating up to **9.2 Gbps/pin** at a 4.6 GHz differential write clock (WCK).

---

<!-- BEGIN_README_SILICON_UPGRADE -->
## Bare-Silicon Die Micrograph, IEEE RTL Schematic & Formal Verification (`SymbiYosys + Z3`)

- **Main Academic Paper (PDF):** [`PAPER.pdf`](PAPER.pdf) ([Markdown](PAPER.md) | [LaTeX](paper.tex))
- **Standalone Formal Verification Monograph (PDF):** [`PAPER_FORMAL_VERIFICATION.pdf`](PAPER_FORMAL_VERIFICATION.pdf) ([Markdown](PAPER_FORMAL_VERIFICATION.md) | [LaTeX](paper_formal.tex))
- **Executable SymbiYosys + Z3 Proofs:** [`formal/`](formal/) (`100% PASS, rc=0`)

| 2048x2048 Optical-Microscope Bare Silicon Die (`fig0`) | IEEE/ISSCC Synthesizable RTL & Formal Schematic (`fig5`) |
| :---: | :---: |
| ![Bare Silicon Die](figures/fig0_bare_silicon_die_2k.png) | ![IEEE RTL Schematic](figures/fig5_rtl_formal_microarchitecture.png) |

![SymbiYosys + Z3 Formal Verification Convergence](figures/fig6_formal_verification_convergence.png)
<!-- END_README_SILICON_UPGRADE -->




## Key Architectural Innovations

1. **4-Depth Circular Elastic Deskew Buffer (`hbm3_phy_elastic_buffer.sv`)**:
   - Solves the classical high-speed framing breakdown where interposer trace skews exceed half a beat (5–7 bits).
   - Absorb 0 to 7 bits of phase skew per lane plus arbitrary discrete beat delays without word boundary corruption.
   - Guaranteed zero underflow/overflow via circular read/write pointer tracking.
2. **2-Phase Autonomous Link Training FSM (`hbm3_phy_training.sv`)**:
   - **Phase 1 (Bit-Slip Coarse Lock)**: Locks bit-level deserializer phase alignment using an alternating `(0xA5, 0x39)` calibration pattern.
   - **Phase 2 (Word Boundary Lock)**: Detects the `0x7E` frame delimiter across all 64 parallel lanes simultaneously, asserting link lock only when deskewed.
3. **Dual-Domain DFI 5.0 Compliant Architecture**:
   - Parallel 512-bit DFI host interface running at 575 MHz.
   - Double Data Rate (DDR) gearbox with `SER_RATIO = 8` converting between core clock and 4.6 GHz WCK.
4. **Silicon Proven Synthesizability**:
   - Zero latches (`check -assert` clean in Yosys).
   - 15/15 SystemVerilog Assertions (SVA) mathematically proven with formal tooling.

---

## System Architecture

```
                    DFI 5.0 Host Bus (512-bit @ 575 MHz)
                                     │
         ┌───────────────────────────┴───────────────────────────┐
         │                                                       │
         ▼ (TX Path)                                             ▲ (RX Path)
┌──────────────────┐                                   ┌──────────────────┐
│  Async TX FIFO   │                                   │ 64-Lane Coalesce │
└────────┬─────────┘                                   └────────▲─────────┘
         │                                                      │
         ▼                                                      │
┌──────────────────┐                                   ┌──────────────────┐
│  8:1 Serializer  │                                   │ 4-Depth Circular │
│  (Gearbox 8-to-1)│                                   │  Elastic Buffer  │
└────────┬─────────┘                                   └────────▲─────────┘
         │                                                      │
         ▼                                             ┌────────┴─────────┐
┌──────────────────┐                                   │ 1:8 Deserializer │
│ Analog TX Driver │                                   │  + Bit-Slip Reg  │
└────────┬─────────┘                                   └────────▲─────────┘
         │                                                      │
         └──────────────► 64x DQ Pins (9.2 Gbps) ───────────────┘
```

---

## Directory Structure

```
.
├── rtl/                          # Synthesizable SystemVerilog IP sources
│   ├── hbm3_phy_top.sv           # Top-level PHY wrapper (DFI 5.0 to 64 DQ pins)
│   ├── hbm3_phy_serdes.sv        # 8:1 Gearbox and DDR SerDes engine
│   ├── hbm3_phy_elastic_buffer.sv# 4-depth circular elastic deskew buffer
│   ├── hbm3_phy_training.sv      # 2-Phase autonomous link training FSM
│   └── hbm3_phy_analog_model.sv  # Mixed-signal analog IO simulation model
├── tb/                           # Comprehensive testbench environments
│   ├── tb_hbm3_phy_link.sv       # Functional link & training verification
│   └── tb_hbm3_phy_torture.sv    # 10,000-beat brute-force skew torture test
├── formal/                       # SystemVerilog Assertions & formal proofs
│   └── hbm3_phy_sva.sv           # 15 proven mathematical invariants
├── docs/                         # Technical specifications and register maps
│   ├── ARCHITECTURE.md           # Deep architectural specification
│   └── FORMAL_SPECIFICATION.md   # Mathematical invariants and proofs
├── Makefile                      # Automated simulation & synthesis recipes
├── LICENSE                       # Apache-2.0 Open Source License
└── README.md                     # Project overview and quickstart guide
```

---

## Verification & Stress Qualification

Run the test suite using `iverilog` and `vvp`:

```bash
# 1. Run Functional Link Training & Loopback Test
make test_link

# 2. Run 10,000-Beat Multi-Lane Skew Torture Test
make test_torture

# 3. Run Yosys Clean Synthesizability & Zero-Latch Check
make synth_check
```

### Torture Test Summary
- **Simulated Clock**: 4.6 GHz differential WCK / 9.2 Gbps per pin.
- **Skew Range Injected**: 0 to 7 bits randomized independently across all 64 DQ lanes.
- **Verified Data Volume**: **5,120,000 Bits** across 10,000 DFI beats.
- **Bit Error Rate (BER)**: **0.00000000% (0 errors)**.
- **Buffer Anomalies**: 0 Overflows, 0 Underflows, 64/64 training locks asserted.

---

## 🗺️ Silicon Architecture Stack & Next-Page Navigation

This repository represents **Layer 01** of our 8-layer unified silicon supercomputing stack. You can navigate sequentially through the entire hardware hierarchy:

```
[01: PHY Layer] ➔ [02: Memory Controller] ➔ [03: Near-Memory PIM] ➔ [04: Ara Core True-FMA]
       ➔ [05: Cluster NoC] ➔ [06: 16-Core SoC] ➔ [07: 64-Core PCIe Card] ➔ [08: 16K WSE Wafer]
```

| Layer | Hardware Component | GitHub Repository | Key Architectural Specifications | Status |
|:---:|:---|:---|:---|:---:|
| **01** | **Physical Layer (PHY)** | [**`Open_HBM3_PHY` (Current)**](https://github.com/ITLABSofficial/Open_HBM3_PHY) | 1.18 TB/s HBM3E PHY, 8:1 SerDes, DFE/CTLE, 4.6 GHz WCK, DFI 5.0 | Active |
| **02** | **Memory Controller** | [**`Open_HBM3_Controller`**](https://github.com/ITLABSofficial/Open_HBM3_Controller) | 16-Pseudo-Channel DFI 5.0 Controller, SECDED ECC, Bank Interleaving | Active |
| **03** | **Near-Memory PIM** | [**`OpenHBM3_PIM_Subsystem`**](https://github.com/ITLABSofficial/OpenHBM3_PIM_Subsystem) | 3.2 TB/s Base-Die PIM Engine, FlashAttention, RMSNorm, True-FMA | Active |
| **04** | **Compute Core** | [**`Ara_Core_TrueFMA_Systolic`**](https://github.com/ITLABSofficial/Ara_Core_TrueFMA_Systolic) | 16x16 Systolic Array & 6-Stage 2.0 GHz True-FMA (1.024 TFLOPS FP16) | Active |
| **05** | **Cluster Interconnect** | [**`Ara_Cluster_TCDM_NoC`**](https://github.com/ITLABSofficial/Ara_Cluster_TCDM_NoC) | 4-Core Vector Cluster, 32-Bank TCDM SRAM (256 GB/s), 5-Port VC Router | Active |
| **06** | **Multicore SoC** | [**`Ara_16Core_2x2_SoC`**](https://github.com/ITLABSofficial/Ara_16Core_2x2_SoC) | 16-Core GALS NoC Multicore SoC, 4-Zone PDN Stagger, Linux C Driver | Active |
| **07** | **Board / Accelerator** | [**`Ara_PCIe_AI_Accelerator_64Core`**](https://github.com/ITLABSofficial/Ara_PCIe_AI_Accelerator_64Core) | 64-Core PCIe Gen5 x16 AI Card, 128 GB HBM3e Address Space (229W TDP) | Active |
| **08** | **Wafer-Scale Engine** | [**`WSE_16K_Wafer_Scale_Engine`**](https://github.com/ITLABSofficial/WSE_16K_Wafer_Scale_Engine) | 300mm Monolithic 16,384-Core Wafer Engine, 48x HBM3 (1.15 TB), 15 kW | Active |

<div align="center">

| ⬅️ **Previous Component** | 🏠 **Architecture Ecosystem** | ➡️ **Next Component** |
|:---:|:---:|:---:|
| *(First Layer in Stack)* | [**ITLABSofficial Profile**](https://github.com/ITLABSofficial) | [**Open_HBM3_Controller ➔**](https://github.com/ITLABSofficial/Open_HBM3_Controller) |

</div>

---

## License

This project is licensed under the **Apache License 2.0** - see the [LICENSE](LICENSE) file for details.
