{% macro delete_data(del_key, del_value, this, offset_days=0) %}
    {#
    Delete data from target table to maintain idempotency.
    
    Parameters:
    - del_key: Column name to filter deletions on (required)
    - del_value: Reference date for daily runs (format: 'YYYY-MM-DD' or 'YYYYMMDD')
    - this: DBT model reference (required)
    - offset_days: Days to shift the reference date (can be negative)
    
    Run Types:
    - full-refresh: Truncates the entire table
    - daily: Deletes records for specific date
    - backfill: Deletes records for date range from backfill variables
    #}
    
    {%- set relation = adapter.get_relation(this.database, this.schema, this.table) -%}
    
    {%- if relation is not none -%}
        {%- set run_type = var("run_type", "daily") -%}
        
        {%- if run_type == 'full-refresh' -%}
            {%- call statement('truncate_table_' ~ this.table, fetch_result=False, auto_begin=True) -%}
                truncate table {{ relation }}
            {%- endcall -%}
            
        {%- elif run_type == 'daily' -%}
            {%- if del_value is none -%}
                {%- do exceptions.raise_compiler_error("del_value is required for daily run_type") -%}
            {%- endif -%}
            
            {%- set date_range = _calculate_date_range(del_value, offset_days, 0) -%}
            {%- set target_date = date_range[0] -%}
            
            {%- call statement('delete_daily_' ~ this.table, fetch_result=False, auto_begin=True) -%}
                delete from {{ relation }} where {{ del_key }} = {{ target_date }}
            {%- endcall -%}
            
        {%- elif run_type == 'backfill' -%}
            {%- set start_date = var("backfill_start_date") -%}
            {%- set end_date = var("backfill_end_date") -%}
            
            {%- if offset_days != 0 -%}
                {# Apply offset to both start and end dates #}
                {%- set start_range = _calculate_date_range(start_date, offset_days, 0) -%}
                {%- set end_range = _calculate_date_range(end_date, offset_days, 0) -%}
                {%- set adj_start_date = start_range[0] -%}
                {%- set adj_end_date = end_range[0] -%}
            {%- else -%}
                {%- set adj_start_date = "'" ~ start_date ~ "'" -%}
                {%- set adj_end_date = "'" ~ end_date ~ "'" -%}
            {%- endif -%}
            
            {%- call statement('delete_backfill_' ~ this.table, fetch_result=False, auto_begin=True) -%}
                delete from {{ relation }} 
                where {{ del_key }} between {{ adj_start_date }} and {{ adj_end_date }}
            {%- endcall -%}
            
        {%- endif -%}
    {%- else -%}
        {# Table doesnt exist yet - no deletion needed #}
        {{ log("Table " ~ this ~ " does not exist. Skipping deletion.", info=True) }}
    {%- endif -%}
    
{% endmacro %}