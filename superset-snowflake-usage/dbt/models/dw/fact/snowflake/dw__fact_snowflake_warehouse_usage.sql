{{ config(
    alias = 'snowflake_warehouse_usage',
    materialized = 'incremental',
    incremental_strategy = 'merge',
    unique_key = ['date_id', 'warehouse_id', 'start_time'],
    on_schema_change = 'sync_all_columns',
    cluster_by = ['date_id', 'environment'],
    tags = ['dw', 'fact'],
    pre_hook = "{{ delete_data('DATE_ID', var('batch_cycle_date') | replace('-', ''), this) }}"
) }}

SELECT 
    d.date_id,
    w.WAREHOUSE_ID,
    w.WAREHOUSE_NAME,
    w.ENVIRONMENT,
    w.START_TIME,
    w.END_TIME,
    w.USAGE_HOUR,
    w.USAGE_DAY_OF_WEEK,
    w.CREDITS_USED,
    w.CREDITS_USED_COMPUTE,
    w.CREDITS_USED_CLOUD_SERVICES,
    w.ESTIMATED_COST_USD
FROM {{ ref('prep__fact_snowflake_warehouse_usage') }} w
JOIN {{ ref('dw__dim_date') }} d ON d.date = w.USAGE_DATE