{{ config(
    alias = 'snowflake_pipe_status',
    materialized = 'view',
    tags = ['dw', 'obt']
) }}

WITH latest_pipes AS (
    SELECT
        DATE,
        ENVIRONMENT_NAME,
        DATABASE_NAME,
        SCHEMA_NAME,
        PIPE_NAME,
        PIPE_STATUS,
        IS_DELETED,
        TARGET_TABLE,
        CREATED_TIMESTAMP,
        LAST_ALTERED_TIMESTAMP,
        DELETED_TIMESTAMP,
        COMMENT,
        PATTERN,
        OWNER_ROLE_TYPE,
        ROW_NUMBER() OVER (PARTITION BY DATABASE_NAME, SCHEMA_NAME, PIPE_NAME ORDER BY CREATED_TIMESTAMP DESC) AS row_num
    FROM
        {{ ref('dw__fact_snowflake_pipe_status') }} f
        INNER JOIN {{ ref('dw__dim_date') }} AS d ON d.date_id = f.date_id
)

SELECT
    DATE,
    ENVIRONMENT_NAME,
    DATABASE_NAME,
    SCHEMA_NAME,
    PIPE_NAME,
    PIPE_STATUS,
    IS_DELETED,
    TARGET_TABLE,
    CREATED_TIMESTAMP,
    LAST_ALTERED_TIMESTAMP,
    DELETED_TIMESTAMP,
    COMMENT,
    PATTERN,
    OWNER_ROLE_TYPE
FROM
    latest_pipes
WHERE
    row_num = 1