{% macro _parse_date(date_string, input_format="%Y-%m-%d") %}
    {#
    Parse a date string into a datetime object.
    Handles both quoted and unquoted strings, and different formats.
    #}
    {%- if date_string is string -%}
        {%- set clean_date = date_string | replace("'", "") | replace('"', '') -%}
        {%- if clean_date | length == 8 and clean_date.isdigit() -%}
            {# Handle YYYYMMDD format #}
            {%- set parsed_date = modules.datetime.datetime.strptime(clean_date, "%Y%m%d") -%}
        {%- else -%}
            {# Handle YYYY-MM-DD format #}
            {%- set parsed_date = modules.datetime.datetime.strptime(clean_date, input_format) -%}
        {%- endif -%}
    {%- else -%}
        {%- set parsed_date = date_string -%}
    {%- endif -%}
    {{ return(parsed_date) }}
{% endmacro %}