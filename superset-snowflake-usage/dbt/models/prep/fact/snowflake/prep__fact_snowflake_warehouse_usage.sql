{{ config(
    alias = 'snowflake_warehouse_usage',
    materialized = 'view',
    tags = ['prep', 'fact']
) }}

SELECT
    DATE(START_TIME) AS USAGE_DATE,
    WAREHOUSE_ID,
    WAREHOUSE_NAME,
    START_TIME,
    END_TIME,
    CREDITS_USED,
    CREDITS_USED_COMPUTE,
    CREDITS_USED_CLOUD_SERVICES,
    -- Cost calculation
    CREDITS_USED * {{ var('snowflake_credit_rate_usd', 3.00) }} AS ESTIMATED_COST_USD,
    -- Environment classification using dbt macro
    {{ get_environment_code('WAREHOUSE_NAME') }} AS ENVIRONMENT,
    -- Time dimensions
    EXTRACT(HOUR FROM START_TIME) AS USAGE_HOUR,
    EXTRACT(DAYOFWEEK FROM START_TIME) AS USAGE_DAY_OF_WEEK
FROM
    snowflake.account_usage.warehouse_metering_history
    {{ filter_data(
        src_column_key = 'DATE(START_TIME)',
        src_operator = '=',
        src_column_val = "'" ~ var('batch_cycle_date') ~ "'"
    ) }}