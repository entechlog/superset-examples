{{ config(
	  alias='snowflake_pipe_usage_history'
	, materialized = 'incremental'
	, incremental_strategy='merge'
	, unique_key=['date_id', 'start_time','end_time','pipe_name']
	, on_schema_change='sync_all_columns'
	, transient=false
	, cluster_by=['date_id']
	, tags=['dw', 'fact']
	, pre_hook="{{ delete_data('DATE_ID', var('batch_cycle_date') | replace('-', ''), this) }}"
) }}

SELECT d.date_id, {{ dbt_utils.star(ref('prep__fact_snowflake_pipe_usage_history'), except = ['created_timestamp', 'created_by']) }}
FROM {{ ref('prep__fact_snowflake_pipe_usage_history') }} as f
join {{ ref('dw__dim_date') }} as d on d.date = f.load_date