# L1 Data Cache & TLB Simulator in C

A lightweight, header-based **L1 data cache** and **Translation Lookaside Buffer (TLB)** simulator written in C11. It instruments linear algebra kernels (dot product, matrix-vector product, and matrix multiplication variants) to measure miss rates, classify misses under the 3C model, and evaluate how data layout, associativity, line size, and loop ordering impact memory hierarchy performance.

## Features

- **L1 Data Cache Simulator (`include/cache.h`)**
  - Sweeps **45 cache configurations**:
    - Cache sizes: `4`, `8`, `16`, `32`, `64` KiB
    - Line sizes: `16`, `32`, `64` B
    - Associativity: `1`-way (direct-mapped), `2`-way, and `4`-way set-associative
  - **LRU replacement** policy and **write-back / write-allocate** modeling
  - **3C miss classification**: breaks down total miss rate into *compulsory*, *conflict*, and *capacity* misses
  - Optional next-line hardware prefetching (`-DPREFETCH=1`) and contiguous array layout (`-DCUSTOM_MEMORY_LAYOUT=1`, enabled by default)
- **TLB Simulator (`include/tlb.h`)**
  - Sweeps **6 TLB configurations**:
    - Entries: `8`, `16`
    - Associativity: `1`-way, `2`-way, and `4`-way set-associative
  - **LRU replacement** policy with **1 KiB (1024 B) pages**
  - Compares `IJK` vs. `IKJ` matrix multiplication page-translation behavior
- **Unit Test Suite (`tests/test_tlb.c`)**
  - Verifies configuration sweep coverage, TLB initialization, intra-page hits, and LRU eviction ordering

## Repository Structure

```text
.
├── include/
│   ├── cache.h                # L1 data cache simulator & 3C miss classifier
│   └── tlb.h                  # Set-associative LRU TLB simulator
├── src/
│   ├── prog-dotproduct.c      # Dot product benchmark (x · y)
│   ├── prog-matvec.c          # Matrix-vector multiplication benchmark (z = X · y)
│   ├── prog-matmult-ijk.c     # Classic ijk matrix multiplication benchmark
│   ├── prog-matmult-ikj.c     # Row-major ikj matrix multiplication benchmark
│   ├── prog-matmult-bloc.c    # Cache-blocked (tiled) matrix multiplication benchmark
│   └── prog-matmult-tlb.c     # TLB simulation comparing ijk and ikj matrix multiplication
├── tests/
│   └── test_tlb.c             # TLB simulator unit tests
├── Makefile
├── LICENSE
└── README.md
```

## Build, Run & Test

### Prerequisites

- A C11-compatible compiler (`gcc` by default)
- GNU `make`

### Build All Benchmarks

```bash
make
```

Compiled binaries are placed in `build/`.

### Run Unit Tests

```bash
make test
```

Compiles `tests/test_tlb.c` to `build/test_tlb` and executes the test suite.

### Run Benchmarks & Customize Problem Size (`-DN=...`)

Each benchmark executable writes tab-separated statistics to a `res-<benchmark>` file in the working directory:

```bash
./build/prog-dotproduct
./build/prog-matvec
./build/prog-matmult-ijk
./build/prog-matmult-ikj
./build/prog-matmult-bloc
./build/prog-matmult-tlb
```

To compile with a custom problem size `N` (e.g., `N=1024` for dot product or `N=256` for matrix multiplication), override `CFLAGS` with `-DN=<value>`:

```bash
make clean
make CFLAGS="-std=c11 -O2 -DN=1024" build/prog-dotproduct
./build/prog-dotproduct
```

### Clean Build Artifacts

```bash
make clean
```

Removes compiled binaries (`build/prog-*`, `build/test_tlb`) and generated `res-*` output files.

## Experimental Results Summary

The benchmarks were evaluated on 64-bit `double` (8 B) arrays across all 45 L1 cache configurations and all 6 TLB configurations.

### 1. Dot Product (`prog-dotproduct`)

- **Spatial locality floor (`N=1000`)**: Streaming sequentially through two `double` vectors yields a compulsory miss rate of **`0.5000`** (16 B line, 2 doubles/line), **`0.2500`** (32 B line, 4 doubles/line), and **`0.1255`** (64 B line, 8 doubles/line).
- **Direct-mapped thrashing (`N=1024`)**: Because `x` and `y` are separated by `8192` B (a power of 2), `x[i]` and `y[i]` map to the exact same cache set in direct-mapped caches (`WAY=1`) when `SIZE <= 8192`, driving the miss rate to **`1.0000`** (`0.9995` at `SIZE=8192`, 64 B line). Increasing associativity to **`WAY >= 2`** (or cache size to `>= 16 KiB`) completely eliminates thrashing and restores the `0.5000` / `0.2500` / `0.1260` floor.

### 2. Matrix-Vector Product (`prog-matvec`)

- **Vector reuse**: Reusing vector `y` across rows of matrix `X` halves the compulsory miss floor relative to the dot product: **`~0.250`** (16 B), **`~0.125`** (32 B), and **`~0.0626–0.0627`** (64 B) when `y` fits in cache (`WAY >= 2`, `SIZE >= 16 KiB` for `N=512`, `SIZE >= 32 KiB` for `N=1024`).
- **Capacity doubling**: When the working set of `y` (`8 * N` bytes) saturates cache capacity (`SIZE=4096` for `N=512`; `SIZE <= 8192` for `N=1024`), `y` is evicted between rows and the `WAY >= 2` miss rate doubles to **`0.500` / `0.250` / `0.126`**.
- **Direct-mapped thrashing**: At `WAY=1`, power-of-2 aliasing causes `1.0000` miss rates at `N=512` (`SIZE=4096`) and `N=1024` (`SIZE <= 8192`), with persistent conflict/capacity overhead even at larger cache sizes.

### 3. Matrix Multiplication (`prog-matmult-ijk` vs. `prog-matmult-ikj`)

- **Column-major bottleneck in `ijk`**: Traversing `y[k*N+j]` with stride `N` causes severe conflict/capacity misses for power-of-2 dimensions (`N=128` and `N=256`), keeping the miss rate near **`~50%`** (`0.5034`–`0.5137`) across all 45 cache configurations.
- **Non-power-of-2 relief**: Shifting to `N=127` or `N=255` breaks set-index aliasing across columns, lowering the `ijk` miss rate down to **`0.0633`** (`N=127`, `SIZE >= 32 KiB`, 64 B line, `WAY >= 2`) and **`0.0629`** (`N=255`, `SIZE=64 KiB`, 64 B line, `WAY >= 2`).
- **Row-major speedup in `ikj`**: Reordering loops to `ikj` makes inner-loop accesses sequential on both `y` and `z`, reducing miss rates for `WAY >= 2` (`N=128, 256`) to **`~0.168`** (16 B line), **`~0.084`** (32 B line), and **`~0.042`** (64 B line) — over a **10x** reduction in miss rate at 64 B lines compared to `ijk`.

### 4. TLB Simulation (`prog-matmult-tlb`, `N=100`, 1 KiB Pages)

| TLB Entries | Associativity | `IJK` Miss Rate | `IKJ` Miss Rate |
| :---: | :---: | :---: | :---: |
| 8 | 1-way | `0.476483` (47.65%) | `0.087802` (8.78%) |
| 8 | 2-way | `0.402125` (40.21%) | `0.005607` (0.56%) |
| 8 | 4-way | `0.401666` (40.17%) | `0.002676` (0.27%) |
| 16 | 1-way | `0.438883` (43.89%) | `0.045548` (4.55%) |
| 16 | 2-way | `0.401069` (40.11%) | `0.002676` (0.27%) |
| 16 | 4-way | `0.401207` (40.12%) | `0.002676` (0.27%) |

Column-wise traversal in `IJK` crosses a new 1 KiB page nearly every step (`40.1%–47.6%` TLB miss rate), whereas row-major `IKJ` reuses active page translations and reaches **`0.27%` (`0.002676`)** with 16 entries (`WAY >= 2`) or 8 entries (`WAY = 4`).

## License

This project is licensed under the MIT License — see [LICENSE](LICENSE) for details.
