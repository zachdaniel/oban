defmodule Oban.Peers.DatabaseTest do
  use Oban.Case

  import ExUnit.CaptureLog

  alias Oban.Peer
  alias Oban.Peers.Database
  alias Oban.TelemetryHandler

  test "only a single peer is leader" do
    TelemetryHandler.attach_events()

    name = start_supervised_oban!(peer: false)
    conf = %{Oban.config(name) | peer: {Database, []}}

    assert [_leader] =
             [A, B, C]
             |> Enum.map(&start_supervised!({Peer, conf: conf, name: &1}))
             |> Enum.filter(&Database.leader?/1)

    assert_received {:event, [:election, :start], _measure,
                     %{leader: _, peer: Database, was_leader: nil}}

    assert_received {:event, [:election, :stop], _measure,
                     %{leader: _, peer: Database, was_leader: false}}
  end

  test "gracefully handling a missing oban_peers table" do
    mangle_peers_table!()

    logged =
      capture_log(fn ->
        name = start_supervised_oban!(peer: Database)
        conf = Oban.config(name)

        start_supervised!({Peer, conf: conf, name: Peer})

        refute Database.leader?(Peer)
      end)

    assert logged =~ "leadership is disabled"
  after
    reform_peers_table!()
  end

  defp mangle_peers_table! do
    Repo.query!("ALTER TABLE oban_peers RENAME TO oban_reeps")
  end

  defp reform_peers_table! do
    Repo.query!("ALTER TABLE oban_reeps RENAME TO oban_peers")
  end
end
