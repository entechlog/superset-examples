{{ config(
	  alias='snowflake_pipe_status'
	, materialized = 'incremental'
	, incremental_strategy='merge'
	, unique_key=['database_name', 'schema_name','pipe_name','created_timestamp']
	, on_schema_change='sync_all_columns'
	, transient=false
	, cluster_by=['date_id']
	, tags=['dw', 'fact']
	, pre_hook="{{ delete_data('DATE_ID', var('batch_cycle_date') | replace('-', ''), this) }}"
) }}

SELECT d.date_id, {{ dbt_utils.star(ref('prep__fact_snowflake_pipe_status')) }}
FROM {{ ref('prep__fact_snowflake_pipe_status') }} as f
join {{ ref('dw__dim_date') }} as d on d.date = TO_DATE(f.created_timestamp)