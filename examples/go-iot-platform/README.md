# Go IoT Platform Example

This example shows how Agent-Repo-Harness can be applied to a Go-based IoT platform repository.

## Typical Repo Shape

- `cmd/gateway/`
- `cmd/ingestor/`
- `internal/devices/`
- `internal/telemetry/`
- `internal/rules/`
- `pkg/contracts/`
- `deploy/`

## Suggested Harness Focus

- `agent.md`: map device ingestion, telemetry processing, command/control entrypoints, and deploy boundaries
- `handoff.md`: capture the current subsystem under work and what was last verified
- `docs/agent/discoveries.md`: store flaky device-simulator or integration findings
- `docs/agent/known-issues.md`: promote recurring transport, firmware, or environment gotchas

## Example `known-issues.md` Topics

- signal type mismatches across device firmware and ingestion
- bucket name case sensitivity
- aggregation target pollution from mixed telemetry sources

## Example `debug-recipes/` Topics

- MQTT publish -> queue -> handler -> DB flow verification
- device simulator replay for intermittent ingestion bugs

## Likely Policy Risks

- device auth and credentials
- MQTT, gRPC, or HTTP contract changes
- edge deployment and environment config
- generated protobuf or client updates
- Docker, queue config, and DB schema changes as high-risk paths

## Likely Verification

- `go test ./...`
- `gofmt -l .`
- smoke checks for ingest or simulator paths
