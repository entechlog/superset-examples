{{ config(
  alias='date',
  materialized='view',
  tags=['prep', 'dim']
) }}
with
    source as (
        select
            date::date as date,
            extract(year from date) as year,
            extract(month from date) as month,
            extract(day from date) as day,
            extract(quarter from date) as quarter,
            upper(dayname(date)) as day_name,
            upper(monthname(date)) as month_name,
            dayofweekiso(date) as day_of_week_iso,
            dayofweek(date) as day_of_week,
            dayofyear(date) as day_of_year,
            weekofyear(date) as week_of_year,
            case
                when upper(dayname(date)) in ('SATURDAY', 'SUNDAY') then true else false
            end as is_weekend,
            case 
                when day <= 15 then 1 
                else 2 
            end as half_month,
            last_day(date) as month_end_date,
            date_trunc('month', date) as month_start_date
        from
            (
                select
                    dateadd(
                        day, row_number() over (order by null) - 1, '1900-01-01'
                    ) as date
                from table(generator(rowcount => 219511))  -- Generate dates from 1900 to 2500
            )
    ),
    union_with_defaults as (
        select
            to_char(date, 'YYYYMMDD')::varchar(128) as date_id,
            date::date as date,
            year::varchar(128) as year,
            month::varchar(128) as month,
            day::varchar(128) as day,
            quarter::varchar(128) as quarter,
            day_name::varchar(128) as day_name,
            month_name::varchar(128) as month_name,
            day_of_week_iso::varchar(128) as day_of_week_iso,
            day_of_week::varchar(128) as day_of_week,
            day_of_year::varchar(128) as day_of_year,
            week_of_year::varchar(128) as week_of_year,
            is_weekend::varchar(128) as is_weekend,
            half_month::varchar(128) as half_month,
            month_end_date::varchar(128) as month_end_date,
            month_start_date::varchar(128) as month_start_date
        from source
        union
        select
            '0'::varchar(128) as date_id,
            null::date as date,
            'Unknown'::varchar(128) as year,
            'Unknown'::varchar(128) as month,
            'Unknown'::varchar(128) as day,
            'Unknown'::varchar(128) as quarter,
            'Unknown'::varchar(128) as day_name,
            'Unknown'::varchar(128) as month_name,
            'Unknown'::varchar(128) as day_of_week_iso,
            'Unknown'::varchar(128) as day_of_week,
            'Unknown'::varchar(128) as day_of_year,
            'Unknown'::varchar(128) as week_of_year,
            'Unknown'::varchar(128) as is_weekend,
            'Unknown'::varchar(128) as half_month,
            'Unknown'::varchar(128) as month_end_date,
            'Unknown'::varchar(128) as month_start_date
    ),
    deduplicated as (
        select
            *,
            row_number() over (
                partition by
                    date,
                    year,
                    month,
                    day,
                    quarter,
                    day_name,
                    month_name,
                    day_of_week_iso,
                    day_of_week,
                    day_of_year,
                    week_of_year,
                    is_weekend,
                    half_month,
                    month_end_date,
                    month_start_date
                order by
                    date_id,
                    date,
                    year,
                    month,
                    day,
                    quarter,
                    day_name,
                    month_name,
                    day_of_week_iso,
                    day_of_week,
                    day_of_year,
                    week_of_year,
                    is_weekend,
                    half_month,
                    month_end_date,
                    month_start_date
            ) as row_num
        from union_with_defaults
    )
select
    date_id,
    date,
    year,
    month,
    day,
    quarter,
    day_name,
    month_name,
    day_of_week_iso,
    day_of_week,
    day_of_year,
    week_of_year,
    is_weekend,
    half_month,
    month_end_date,
    month_start_date
from deduplicated
where row_num = 1