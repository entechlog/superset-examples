{{ config(
    alias = 'snowflake_query_history',
    materialized = 'incremental',
    incremental_strategy = 'merge',
    unique_key = ['date_id', 'query_id'],
    on_schema_change = 'sync_all_columns',
    cluster_by = ['date_id', 'database_environment', 'warehouse_environment'],
    tags = ['dw', 'fact'],
    pre_hook = "{{ delete_data('DATE_ID', var('batch_cycle_date') | replace('-', ''), this) }}"
) }}

SELECT 
    d.date_id,
    q.QUERY_ID,
    q.DATABASE_NAME,
    q.SCHEMA_NAME,
    q.WAREHOUSE_ID,
    q.WAREHOUSE_NAME,
    q.WAREHOUSE_SIZE,
    q.USER_NAME,
    q.ROLE_NAME,
    q.SESSION_ID,
    q.QUERY_TYPE,
    q.QUERY_TAG,
    
    -- Environment classifications (consistent with other models)
    q.DATABASE_ENVIRONMENT,
    q.WAREHOUSE_ENVIRONMENT,
    
    -- Time metrics
    q.START_TIME,
    q.END_TIME,
    q.EXECUTION_TIME_SECONDS,
    q.COMPILATION_TIME_SECONDS,
    q.ACTUAL_EXECUTION_TIME_SECONDS,
    q.QUEUED_TIME_SECONDS,
    
    -- Resource usage metrics
    q.CREDITS_USED_CLOUD_SERVICES,
    q.BYTES_SCANNED,
    q.BYTES_WRITTEN,
    q.BYTES_SPILLED_TO_LOCAL_STORAGE,
    q.BYTES_SPILLED_TO_REMOTE_STORAGE,
    q.ROWS_PRODUCED,
    q.ROWS_INSERTED,
    q.ROWS_UPDATED,
    q.ROWS_DELETED,
    
    -- Status and performance flags
    q.EXECUTION_STATUS,
    q.ERROR_CODE,
    q.ERROR_MESSAGE,
    q.IS_SUCCESSFUL,
    q.IS_FAILED,
    q.IS_SLOW_QUERY,
    q.IS_VERY_SLOW_QUERY,
    q.IS_LARGE_SCAN,
    q.HAS_SPILLING,
    
    -- Cost metrics
    q.ESTIMATED_QUERY_COST_USD,
    
    -- Time dimensions
    q.QUERY_HOUR,
    q.QUERY_DAY_OF_WEEK,
    q.QUERY_MONTH
    
FROM {{ ref('prep__fact_snowflake_query_history') }} q
JOIN {{ ref('dw__dim_date') }} d ON d.date = q.USAGE_DATE