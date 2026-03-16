{{ config(
    alias = 'snowflake_query_history',
    materialized = 'view',
    tags = ['prep', 'fact']
) }}

SELECT
    DATE(qh.START_TIME) AS USAGE_DATE,
    qh.QUERY_ID,
    qh.QUERY_TEXT,
    qh.DATABASE_NAME,
    qh.SCHEMA_NAME,
    qh.WAREHOUSE_ID,
    qh.WAREHOUSE_NAME,
    qh.WAREHOUSE_SIZE,
    qh.USER_NAME,
    qh.ROLE_NAME,
    qh.SESSION_ID,
    qh.QUERY_TYPE,
    qh.QUERY_TAG,
    
    -- Environment classification using database name (consistent with storage)
    {{ get_environment_code('qh.DATABASE_NAME') }} AS DATABASE_ENVIRONMENT,
    -- Environment classification using warehouse name (consistent with warehouse)
    {{ get_environment_code('qh.WAREHOUSE_NAME') }} AS WAREHOUSE_ENVIRONMENT,
    
    -- Time metrics
    qh.START_TIME,
    qh.END_TIME,
    qh.TOTAL_ELAPSED_TIME / 1000 AS EXECUTION_TIME_SECONDS,
    qh.COMPILATION_TIME / 1000 AS COMPILATION_TIME_SECONDS,
    qh.EXECUTION_TIME / 1000 AS ACTUAL_EXECUTION_TIME_SECONDS,
    qh.QUEUED_PROVISIONING_TIME / 1000 AS QUEUED_TIME_SECONDS,
    
    -- Resource usage
    qh.CREDITS_USED_CLOUD_SERVICES,
    qh.BYTES_SCANNED,
    qh.BYTES_WRITTEN,
    qh.BYTES_SPILLED_TO_LOCAL_STORAGE,
    qh.BYTES_SPILLED_TO_REMOTE_STORAGE,
    qh.ROWS_PRODUCED,
    qh.ROWS_INSERTED,
    qh.ROWS_UPDATED,
    qh.ROWS_DELETED,
    
    -- Status and performance flags
    qh.EXECUTION_STATUS,
    qh.ERROR_CODE,
    qh.ERROR_MESSAGE,
    
    -- Performance categorization
    CASE 
        WHEN qh.EXECUTION_STATUS = 'SUCCESS' THEN 1 
        ELSE 0 
    END AS IS_SUCCESSFUL,
    
    CASE 
        WHEN qh.EXECUTION_STATUS != 'SUCCESS' THEN 1 
        ELSE 0 
    END AS IS_FAILED,
    
    CASE 
        WHEN qh.TOTAL_ELAPSED_TIME >= 300000 THEN 1  -- 5+ minutes
        ELSE 0 
    END AS IS_SLOW_QUERY,
    
    CASE 
        WHEN qh.TOTAL_ELAPSED_TIME >= 1800000 THEN 1  -- 30+ minutes
        ELSE 0 
    END AS IS_VERY_SLOW_QUERY,
    
    -- Query complexity indicators
    CASE 
        WHEN qh.BYTES_SCANNED >= POWER(1024, 3) THEN 1  -- 1GB+ scanned
        ELSE 0 
    END AS IS_LARGE_SCAN,
    
    CASE 
        WHEN qh.BYTES_SPILLED_TO_LOCAL_STORAGE > 0 OR qh.BYTES_SPILLED_TO_REMOTE_STORAGE > 0 THEN 1
        ELSE 0 
    END AS HAS_SPILLING,
    
    -- Cost calculation (using credits and warehouse size as proxy)
    CASE 
        WHEN qh.WAREHOUSE_SIZE = 'X-Small' THEN (qh.TOTAL_ELAPSED_TIME / 1000.0 / 3600) * 1 * {{ var('snowflake_credit_rate_usd', 3.00) }}
        WHEN qh.WAREHOUSE_SIZE = 'Small' THEN (qh.TOTAL_ELAPSED_TIME / 1000.0 / 3600) * 2 * {{ var('snowflake_credit_rate_usd', 3.00) }}
        WHEN qh.WAREHOUSE_SIZE = 'Medium' THEN (qh.TOTAL_ELAPSED_TIME / 1000.0 / 3600) * 4 * {{ var('snowflake_credit_rate_usd', 3.00) }}
        WHEN qh.WAREHOUSE_SIZE = 'Large' THEN (qh.TOTAL_ELAPSED_TIME / 1000.0 / 3600) * 8 * {{ var('snowflake_credit_rate_usd', 3.00) }}
        WHEN qh.WAREHOUSE_SIZE = 'X-Large' THEN (qh.TOTAL_ELAPSED_TIME / 1000.0 / 3600) * 16 * {{ var('snowflake_credit_rate_usd', 3.00) }}
        WHEN qh.WAREHOUSE_SIZE = '2X-Large' THEN (qh.TOTAL_ELAPSED_TIME / 1000.0 / 3600) * 32 * {{ var('snowflake_credit_rate_usd', 3.00) }}
        WHEN qh.WAREHOUSE_SIZE = '3X-Large' THEN (qh.TOTAL_ELAPSED_TIME / 1000.0 / 3600) * 64 * {{ var('snowflake_credit_rate_usd', 3.00) }}
        WHEN qh.WAREHOUSE_SIZE = '4X-Large' THEN (qh.TOTAL_ELAPSED_TIME / 1000.0 / 3600) * 128 * {{ var('snowflake_credit_rate_usd', 3.00) }}
        ELSE 0
    END AS ESTIMATED_QUERY_COST_USD,
    
    -- Time dimensions
    EXTRACT(HOUR FROM qh.START_TIME) AS QUERY_HOUR,
    EXTRACT(DAYOFWEEK FROM qh.START_TIME) AS QUERY_DAY_OF_WEEK,
    EXTRACT(MONTH FROM qh.START_TIME) AS QUERY_MONTH
    
FROM snowflake.account_usage.query_history qh
{{ filter_data(
    src_column_key = 'DATE(qh.START_TIME)',
    src_operator = '=',
    src_column_val = "'" ~ var('batch_cycle_date') ~ "'"
) }}