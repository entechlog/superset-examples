{{ config(
  alias='date',
  materialized='table',
  transient=false,
  tags=['dw', 'dim'],
  cluster_by=['date_id'] 
) }}

SELECT {{ dbt_utils.star(ref('prep__dim_date')) }}
FROM {{ ref('prep__dim_date') }}