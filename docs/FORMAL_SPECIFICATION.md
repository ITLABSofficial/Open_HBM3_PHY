# OPEN_HBM3_PHY Formal Specification and Mathematical Invariants

## 1. Mathematical Modeling
For an $N=64$ lane differential physical channel, the data vector at beat $k$ is defined as:
$$X[k] \in \{0, 1\}^{512}, \quad X_l[k] \in \{0, 1\}^8 \quad (\forall l \in \{0, \dots, 63\})$$

The propagation delay across interposer traces, packaging parasitic capacitance, and micro-bump impedance mismatch is modeled as:
$$\tau_l = D_l \cdot T_{\text{bit}} + \delta_l$$
where:
- $D_l = B_l \cdot 8 + S_l$ ($S_l \in \{0, \dots, 7\}$ represents fractional bit-slip skew, $B_l \in \{0, 1, 2\}$ represents discrete beat skew).
- $\delta_l$ is the sub-bit phase offset ($|\delta_l| < \frac{1}{2} T_{\text{bit}}$).

---

## 2. Formal Invariants (SVA Specification)

### Invariant 1: Bit Alignment Convergence (Phase 1 Liveness)
When link training is initiated ($start = 1$), all 64 lane lock signals transition to active-high within finite time $T_1 \le 24 \cdot (\text{SETTLE} + 2)$ cycles:
$$\forall l \in \{0, \dots, 63\}, \quad \text{locked}_l = 1$$

### Invariant 2: Deskew Safety (Phase 2 Safety)
The deskew lock flag (`deskew_locked`) can ONLY assert if and only if all 64 parallel lanes have successfully captured the frame delimiter (`0x7E`) and buffered payload (`all_lanes_ready = 1`):
$$\text{deskew\_locked} \implies \left( \bigwedge_{l=0}^{63} \text{lane\_marker\_seen}_l \right)$$

### Invariant 3: Conservation of Payload (Exact Reconstruction)
Following deskew lock assertion, for every read cycle $m \ge 0$, the received word $Y[m]$ matches the transmitted word $X[m]$ bit-for-bit:
$$\forall m \ge 0, \quad Y[m] \oplus X[m] = \mathbf{0}$$
No word drops, duplications, or permutations occur across the physical boundary.

### Invariant 4: Buffer Stability (Zero Underflow / Overflow)
Under normal synchronous operation ($deskew\_locked = 1$), the occupancy of each circular elastic FIFO remains strictly bounded:
$$0 < \text{occupancy}_l \le 3 \quad (\forall l \in \{0, \dots, 63\})$$
Buffer overflow and underflow flags remain strictly deasserted.
