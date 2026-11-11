ExUnit.start()

# Shared memo for expensive, immutable test state (a fully generated citizen, the
# fixture model). Owned by this process, so it lives exactly as long as the test
# session and costs nothing when a run never asks for it. See
# `SpGen.FixtureRepo.shared/2` and `tools/spgen/contributions.md`.
{:ok, _memo} = Agent.start_link(fn -> %{} end, name: SpGen.TestMemo)
