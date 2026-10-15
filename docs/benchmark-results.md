# Initial CLI benchmark

Measured 2026-10-15 at commit `b665fbe` on one Linux x86_64 host. Each case renders
10,000 synthetic two-column ASCII rows. Values below are arithmetic means of
five fresh-process samples following two warmups. All outputs passed the
independent row/value oracle.

| Implementation | Widths | Allowed cores | Wall ms | Child CPU ms |
| --- | --- | ---: | ---: | ---: |
| Roc | Auto | 1 | 242.632 | 239.863 |
| Roc | Auto | 12 | 264.094 | 262.157 |
| Roc | Fixed | 1 | 198.311 | 195.827 |
| Roc | Fixed | 12 | 204.155 | 202.230 |
| Zig | Auto | 1 | 48.049 | 46.994 |
| Zig | Auto | 12 | 48.189 | 47.660 |
| Zig | Fixed | 1 | 31.268 | 30.514 |
| Zig | Fixed | 12 | 33.017 | 32.376 |

The single-core Roc/Zig wall-time ratios were 5.05 for auto widths and 6.34 for
fixed widths. These results describe this input, host,
and whole-process measurement; they do not establish a general language ranking.
Both implementations are single-threaded. CLI startup, locale lookup, and
RAM-backed file I/O are included; input generation and output verification are
excluded. See [README.md](../README.md#tests-and-benchmarks) for reproduction.

All eight historical comparisons are **UNBASELINED**, and `./bm` returned 3.
The measurements are valid observations, with no approved historical epoch yet.
Raw samples and provenance remain in the configured external history store.
