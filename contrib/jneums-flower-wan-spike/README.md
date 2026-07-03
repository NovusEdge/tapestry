# Flower WAN Weight-Transfer Spike

De-risk spike for the [issue #70](https://github.com/The-AI-Alliance/tapestry/issues/70)
epic: **can a ~2B-parameter model's weights round-trip through a Flower SuperLink over a
real WAN, and how long does a round take?** This measures transport only — the "training"
node echoes the weights back unchanged.

## Design

- **Payload**: 2,000,000,000 parameters in float16 = **4.0 GB** each direction, split into
  80 × 50 MB tensors (like a real model's layer tensors; each message object stays far below
  gRPC size limits). float16 stands in for bfloat16 — NumPy has no bf16; wire size is identical.
  Values are random so transparent compression can't flatter the numbers.
- **Topology**: SuperLink + ServerApp on one host (the "central node"), one SuperNode +
  ClientApp on another (a "sovereign node"). The ServerApp sends the payload via a
  single-node FedAvg round; the client echoes it back; FedAvg aggregates (N=1 identity).
- **NumPy-only** app: node setup is `pip install flwr numpy`, no torch.

## Results

WAN topology used: SuperLink + ServerApp on a Quebec (CA) vast.ai instance, SuperNode +
ClientApp on a Sweden (SE) instance. Measured path RTT ≈ 106 ms; raw single-stream TCP on
the same path: 114 Mbit/s (QC→SE), 167 Mbit/s (SE→QC).

| leg | payload | round-trip (1 round) | effective throughput* |
| :-- | :-- | :-- | :-- |
| loopback (WSL2, same host) | 0.5 GB ×2 | 20.5 s | ~0.39 Gbit/s |
| loopback (WSL2, same host) | 4.0 GB ×2 | 138.1 s | ~0.46 Gbit/s |
| WAN Quebec↔Sweden (106 ms) | 0.5 GB ×2 | 10 min 30 s | ~13 Mbit/s |
| WAN Quebec↔Sweden (106 ms) | 4.0 GB ×2 | 1 h 24 min | ~12.7 Mbit/s |
| WAN Quebec↔Norway (97 ms), unpatched | 0.5 GB ×2 | 8 min 13 s | ~16 Mbit/s |
| WAN Quebec↔Norway, lookahead patch | 0.5 GB ×2 | 6–9 min (3 runs; one 78 s outlier) | pull fixed, push not |
| WAN Quebec↔Norway, lookahead patch | 4.0 GB ×2 | 1 h 1 min | pull ~128 Mbit/s, push ~10 Mbit/s |

\* total bytes moved ÷ round time; includes flwr's serialization and store-and-forward
through the SuperLink object store, so this is *system* throughput, not link speed.

**Loopback finding:** even with no real network, the stack tops out around ~0.5 Gbit/s —
Flower's object store/serialization path, not bandwidth, is the first ceiling. For DiLoCo-class
outer loops (sync every ~500+ inner steps) a couple of minutes per exchange is comfortably
affordable; for frequent-sync patterns it would dominate.

**WAN finding (the important one):** the WAN round is dominated by Flower's object
transfer layer, not the network. Per-leg reconstruction of the 0.5 GB round: server→node
delivery ran at ~47 Mbit/s (~2.4× below raw TCP on that path), but the node→server **push
of the reply ran at ~7.5 Mbit/s — ~20× below raw TCP** (167 Mbit/s measured with a plain
socket seconds later on the same path). The rate corresponds to only ~100 KB in flight
per 106 ms round trip — a small effective window somewhere in the push path.

The 4.0 GB round scales linearly from the 0.5 GB one (~12.7 vs ~13 Mbit/s effective), so
the overhead is proportional to bytes moved, not a fixed per-round cost: **a 2B-param
model exchange on this path costs ~1.5 h per round as shipped.** Arrays are split into
5 MB chunk objects (`FLWR_PRIVATE_MAX_ARRAY_CHUNK_SIZE`); raising the chunk size 13×
did not change the round time (table below), so the cost is *per byte in flight*, not
per chunk boundary — consistent with a small effective in-flight window on the 106 ms
path rather than chunk-setup overhead.

**Knob A/B tests** (0.5 GB payload, same path, both daemons restarted with the env
override each time; baseline 10 min 30 s):

| variant | round-trip | conclusion |
| :-- | :-- | :-- |
| `FLWR_PRIVATE_MAX_ARRAY_CHUNK_SIZE` 5 MB → 64 MB | 10 min 21 s | no effect — chunk granularity is not the bottleneck |
| + `FLWR_PRIVATE_MAX_CONCURRENT_OBJ_{PUSHES,PULLS}` 2 → 16 | 12 min 42 s | no effect — parallel streams over one connection don't help |

(Env vars verified present in the running SuperNode's `/proc/<pid>/environ`.)

**Root cause class — confirmed; fix verified for one direction.** The measured
~100 KB in flight per RTT matches gRPC C-core's per-stream read-ahead limit,
[`grpc.http2.lookahead_bytes`](https://grpc.github.io/grpc/core/group__grpc__arg__keys.html)
(`GRPC_ARG_HTTP2_STREAM_LOOKAHEAD_BYTES`, default 64 KB) — documented as the knob to
raise "on high-latency connections." Flower's channel construction
(`flwr/supercore/grpc.py`) sets only message-length options, so it runs the 64 KB
default, and the option is not operator-configurable.

**Patch results** (fresh Quebec↔Norway pair, 97 ms RTT; `patch_lookahead.py` in this
directory adds `("grpc.http2.lookahead_bytes", 16 MB)` to Flower's client channels and
server options; unpatched same-pair baseline 8 min 13 s for 0.5 GB ×2):

- **Pull leg (SuperLink→node) is reliably fixed**: ~47 Mbit/s unpatched →
  **~90–128 Mbit/s patched**, reproduced across three runs including 4 GB — near raw
  single-stream TCP for the path. Consistent with flow-control mechanics: the pull
  receiver is the patched *client channel*.
- **Push leg (node→SuperLink) is NOT fixed by the channel arg**: ~10–16 Mbit/s in every
  steady-state run, patched or not (4 GB patched round: 1 h 1 m, vs 1 h 24 m unpatched).
  The push receiver is Flower's gRPC *server*; the equivalent server-side receive-window
  fix needs to happen inside Flower/gRPC-core (or the object push path needs streaming/
  multiple connections). Also ruled out for the push leg: chunk size, app-level transfer
  concurrency, connection age (fresh-SuperNode rerun), and SuperLink state (fresh-SuperLink
  rerun).
- One 0.5 GB patched run completed in 78 s (~103 Mbit/s both legs) but did **not
  reproduce** under identical fresh-restart conditions (6–9 min in three attempts).
  Possible object-store dedup effect (the echo payload's content hashes match objects the
  store may still hold) or transient path conditions — flagged as an open question for
  upstream rather than claimed as a result.

Implications for the epic:

- **Functionally proven**: a 2B-param payload round-trips intact through SuperLink over
  a real WAN; no message-size or memory failures at 4 GB per direction.
- **Cost as shipped**: ~1.5 h per 2B exchange on a ~100 ms path (flwr 1.32.1 defaults).
  DiLoCo-cadence sync absorbs this; frequent-sync patterns cannot.
- **Cost with the 2-line client-side fix**: the SuperLink→node direction becomes
  raw-TCP-limited (2–3× on our path); the node→SuperLink push still needs an upstream
  server-side fix, and it dominates the round (patched 4 GB round: 1 h 1 m).
- No matching issue exists in the Flower tracker (checked 2026-07-03) — file upstream
  with these numbers, the patch, and the open push-leg question; until it ships, nodes
  can apply `patch_lookahead.py` for the pull-leg win.
- Channel-level gzip compression would not help: weights are near-incompressible and the
  bottleneck is flow-control round trips, not bytes.

## Gotchas found (flwr 1.32)

- `FedAvg` defaults to `min_train_nodes=2` / `min_available_nodes=2`; with one node,
  `strategy.start` waits forever with no message. Set them to 1 for a single-node spike.
- ClientApp/ServerApp `print` output is block-buffered before it reaches `flwr run --stream`;
  use `flush=True`.
- `MetricRecord` values must be numeric — a string value fails the whole client reply.
- If the SuperLink becomes unreachable, the SuperNode retries briefly and then **exits**
  rather than backing off indefinitely; node-side supervision (systemd restart or similar)
  is required for unattended sovereign nodes.
- flwr ≥1.31 requires Python ≥3.11 (common GPU images still ship 3.10; `uv venv --python 3.12`
  is a quick fix).

## Reproducing

Environment (both hosts): Python ≥3.10, `pip install "flwr>=1.32,<1.33" numpy`, plus this
app installed (`pip install -e .`) wherever the SuperNode and SuperLink run.

Central node:

```shell
flower-superlink --insecure   # control API :9093, fleet API :9092
```

Sovereign node:

```shell
flower-supernode --insecure --superlink <central-host>:9092
```

Driver (any machine that can reach the control API) — add to `~/.flwr/config.toml`:

```toml
[superlink.spike]
address = "<central-host>:9093"
insecure = true
```

then, from this directory:

```shell
flwr run . spike --stream
# smaller payload: flwr run . spike --run-config "payload-params=250000000" --stream
```

`--insecure` is acceptable for this throwaway spike on random weights; a real deployment
uses TLS + SuperNode auth (both built into Flower).

## Scope

This spike informs the "Flower as connectivity layer" recommendation on #70. It does not
test training, aggregation quality, node failure, or TLS — only that the epic's weight
payload fits through the pipe and what a round costs.
