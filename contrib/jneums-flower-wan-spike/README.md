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

| leg | payload | round-trip (1 round) | effective throughput* |
| :-- | :-- | :-- | :-- |
| loopback (WSL2, same host) | 0.5 GB ×2 | 20.5 s | ~0.39 Gbit/s |
| loopback (WSL2, same host) | 4.0 GB ×2 | 138.1 s | ~0.46 Gbit/s |
| WAN (two vast.ai datacenters) | 4.0 GB ×2 | _pending_ | _pending_ |

\* total bytes moved ÷ round time; includes flwr's serialization and store-and-forward
through the SuperLink object store, so this is *system* throughput, not link speed.

**Loopback finding:** even with no real network, the stack tops out around ~0.5 Gbit/s —
Flower's object store/serialization path, not bandwidth, is the first ceiling. For DiLoCo-class
outer loops (sync every ~500+ inner steps) a couple of minutes per exchange is comfortably
affordable; for frequent-sync patterns it would dominate.

## Gotchas found (flwr 1.32)

- `FedAvg` defaults to `min_train_nodes=2` / `min_available_nodes=2`; with one node,
  `strategy.start` waits forever with no message. Set them to 1 for a single-node spike.
- ClientApp/ServerApp `print` output is block-buffered before it reaches `flwr run --stream`;
  use `flush=True`.
- `MetricRecord` values must be numeric — a string value fails the whole client reply.

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
