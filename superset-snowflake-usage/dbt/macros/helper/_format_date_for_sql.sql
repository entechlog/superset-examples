{% macro _format_date_for_sql(date_obj, include_quotes=true) %}
    {#
    Format a datetime object for SQL use.
    Returns date in 'YYYY-MM-DD' format with optional quotes.
    #}
    {%- set formatted = date_obj.strftime("%Y-%m-%d") -%}
    {%- if include_quotes -%}
        {{ return("'" ~ formatted ~ "'") }}
    {%- else -%}
        {{ return(formatted) }}
    {%- endif -%}
{% endmacro %}