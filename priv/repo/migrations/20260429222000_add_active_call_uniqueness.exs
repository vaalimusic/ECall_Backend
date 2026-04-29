defmodule Ecall.Repo.Migrations.AddActiveCallUniqueness do
  use Ecto.Migration

  def up do
    execute("""
    WITH ranked_calls AS (
      SELECT
        id,
        status,
        row_number() OVER (
          PARTITION BY LEAST(caller_id, callee_id), GREATEST(caller_id, callee_id), media_type
          ORDER BY inserted_at DESC
        ) AS rank
      FROM calls
      WHERE status IN ('initiated', 'ringing', 'accepted')
    )
    UPDATE calls
    SET
      status = CASE ranked_calls.status WHEN 'accepted' THEN 'ended' ELSE 'missed' END,
      ended_at = COALESCE(calls.ended_at, now()),
      metadata = calls.metadata || '{"reason":"deduplicated_before_active_call_unique_index"}'::jsonb
    FROM ranked_calls
    WHERE calls.id = ranked_calls.id AND ranked_calls.rank > 1
    """)

    execute("""
    CREATE UNIQUE INDEX calls_one_active_between_users_per_media
    ON calls (LEAST(caller_id, callee_id), GREATEST(caller_id, callee_id), media_type)
    WHERE status IN ('initiated', 'ringing', 'accepted')
    """)
  end

  def down do
    execute("DROP INDEX IF EXISTS calls_one_active_between_users_per_media")
  end
end
