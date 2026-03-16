{{ config(
    alias = 'snowflake_pipe_status',
    materialized = 'table',
    tags = ['prep', 'fact']
) }}

WITH source AS (
    SELECT
        CASE
            WHEN SUBSTRING(PIPE_CATALOG, 1, 3) IN ('DEV', 'STG', 'PRD') THEN SUBSTRING(PIPE_CATALOG, 1, 3)
            WHEN UPPER(SUBSTRING(PIPE_CATALOG, LENGTH(PIPE_CATALOG) - 4, 5)) = '-TEST' THEN 'TEST'
            WHEN SUBSTRING(PIPE_CATALOG, LENGTH(PIPE_CATALOG) - 2, 3) = 'EST' THEN CONCAT('OLD-', 'TEST')
            ELSE CONCAT('OLD-', SUBSTRING(PIPE_CATALOG, LENGTH(PIPE_CATALOG) - 2, 3))
        END AS ENVIRONMENT_NAME,
        PIPE_CATALOG AS DATABASE_NAME,
        PIPE_SCHEMA AS SCHEMA_NAME,
        PIPE_NAME,
        REGEXP_SUBSTR(DEFINITION, 'COPY INTO ([^ ]+)', 1, 1, 'i', 1) AS TARGET_TABLE,
        CREATED AS CREATED_TIMESTAMP,
        LAST_ALTERED AS LAST_ALTERED_TIMESTAMP,
        COMMENT,
        PATTERN,
        DELETED AS DELETED_TIMESTAMP,
        CASE WHEN DELETED IS NOT NULL THEN TRUE ELSE FALSE END AS IS_DELETED,
        OWNER_ROLE_TYPE,
        CONCAT(PIPE_CATALOG, '.', PIPE_SCHEMA, '.', PIPE_NAME) AS FULL_PIPE_NAME
    FROM
        snowflake.account_usage.pipes
    {{ filter_data(
        src_column_key = 'to_date(CREATED)',
        src_operator = '=',
        src_column_val = "'" ~ var('batch_cycle_date') ~ "'"
    ) }}
),

{# Fetch pipe details using the macro #}
{%- set pipe_details = get_snowpipe_details() -%}

{# Build the pipe status CTE with proper handling for empty results #}
get_pipe_status AS (
    {% if pipe_details and pipe_details|length > 0 %}
        {% for pipe_detail in pipe_details %}
            {%- set pipe_database_name = pipe_detail[1] -%}
            {%- set pipe_schema_name = pipe_detail[2] -%}
            {%- set pipe_name = pipe_detail[3] -%}
            {%- set full_pipe_name = pipe_database_name ~ '.' ~ pipe_schema_name ~ '.' ~ pipe_name -%}
            
            {% if not loop.first %} UNION ALL {% endif %}
           
            SELECT
                '{{ full_pipe_name }}' AS full_pipe_name,
                parse_json(SYSTEM$PIPE_STATUS('{{ full_pipe_name }}')):executionState::VARCHAR AS pipe_status
        {% endfor %}
    {% else %}
        -- Handle case when no pipe details are found
        SELECT
            NULL AS full_pipe_name,
            NULL AS pipe_status
        WHERE 1 = 0  -- This ensures no rows are returned
    {% endif %}
)

SELECT
    s.ENVIRONMENT_NAME,
    s.DATABASE_NAME,
    s.SCHEMA_NAME,
    s.PIPE_NAME,
    s.TARGET_TABLE,
    s.CREATED_TIMESTAMP,
    s.LAST_ALTERED_TIMESTAMP,
    s.COMMENT,
    s.PATTERN,
    s.DELETED_TIMESTAMP,
    s.IS_DELETED,
    s.OWNER_ROLE_TYPE,
    CASE
        WHEN s.IS_DELETED THEN 'DELETED'
        ELSE COALESCE(p.pipe_status, 'UNKNOWN')
    END AS PIPE_STATUS
FROM
    source s
LEFT JOIN get_pipe_status p
    ON LOWER(s.FULL_PIPE_NAME) = LOWER(p.full_pipe_name)
WHERE 
    (CASE
        WHEN s.IS_DELETED THEN 'DELETED'
        ELSE COALESCE(p.pipe_status, 'UNKNOWN')
    END) IS NOT NULL