defmodule Nostrum.Shard.ProgressingGuilds do
  use Agent

  alias Nostrum.Error.CacheError

  alias Nostrum.Cache.Mapping.GuildShard

  def start_link(_) do
    Agent.start_link(fn -> MapSet.new() end)
  end

  def add_guild(pid, guild_id) do
    Agent.update(pid, &(MapSet.put(&1, guild_id)))
  end

  def remove_guild(pid, guild_id) do
    Agent.update(pid, &(MapSet.delete(&1, guild_id)))
  end

  def has_guilds(pid) do
    Agent.get(pid, &(MapSet.size(&1) != 0))
  end

  def get_progressing_agent(:guild, guild_id) do
    case GuildShard.get_shard(guild_id) do
      {:ok, shard_id} ->
        get_progressing_agent(:shard, shard_id)

      {:error, :id_not_found} ->
        raise CacheError, key: guild_id, cache_name: GuildShardMapping
    end
  end

  def get_progressing_agent(:shard, shard_id) do
    ShardSupervisor
        |> Supervisor.which_children()
        |> Enum.filter(fn {_id, _pid, _type, [modules]} -> modules == Nostrum.Shard end)
        |> Enum.filter(fn {id, _pid, _type, _modules} -> id == shard_id end)
        |> Enum.map(fn {_id, pid, _type, _modules} -> Supervisor.which_children(pid) end)
        |> List.flatten()
        |> Enum.filter(fn {_id, _pid, _type, [modules]} -> modules == Nostrum.Shard.ProgressingGuilds end)
        |> List.first()
        |> elem(1)
  end
end
