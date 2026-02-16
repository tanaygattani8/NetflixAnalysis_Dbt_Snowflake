{% snapshot snap_tags %}
    {{
        config(
            target_schema='snapshots',
            unique_key='row_key',
            strategy='timestamp',
            updated_at='tag_timestamp',
            invalidate_hard_deletes=True
        )
    }}
    SELECT
    {{ dbt_utils.generate_surrogate_key(['user_id','movie_id','tag']) }} AS row_key,
    user_id,
    movie_id,
    tag,
    CAST (rating_timestamp AS TIMESTAMP_NTZ) AS tag_timestamp
    FROM {{ ref('src_tags') }}
{% endsnapshot %}