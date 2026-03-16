# Snowflake Account Usage Monitoring

Monitor and visualize your Snowflake account usage using dbt for data transformation and Apache Superset for dashboards.

## Quick Start

### Prerequisites
- Docker and Docker Compose
- Snowflake account with ACCOUNTADMIN role
- Environment variables configured

### Setup

1. **Configure Environment Variables**
```bash
# Create .env file with:
ENV_CODE=DEV
PROJ_CODE=ENTECHLOG
SNOWFLAKE_ACCOUNT=your_account
SNOWFLAKE_USER=your_user
SNOWFLAKE_PASSWORD=your_password
SNOWFLAKE_ROLE=ACCOUNTADMIN
SNOWFLAKE_DATABASE=${ENV_CODE}_${PROJ_CODE}_PREP_DB
SNOWFLAKE_WAREHOUSE=${ENV_CODE}_${PROJ_CODE}_DBT_WH_XS
SNOWFLAKE_SCHEMA=PUBLIC
```

2. **Start Services**
```bash
docker-compose up -d
```

3. **Run dbt Models**
```bash
cd dbt
dbt deps
dbt run --model +tag:obt --full-refresh --vars '{"run_type":"full-refresh"}'
```

4. **Import Superset Assets**
```bash
docker exec -it apache-superset /bin/bash
cd /usr/src/
superset import-directory assets --overwrite
```

## What's Included

### Monitoring Capabilities
- **Compute Usage**: Credits consumed, warehouse utilization, query performance
- **Storage Usage**: Database sizes, storage costs, growth trends
- **Query Analytics**: Execution times, resource consumption, cost analysis

### Data Models
- **snowflake_warehouse_usage_1d**: Daily warehouse metrics and costs
- **snowflake_query_usage_1d**: Query patterns and performance metrics
- **snowflake_storage_usage_1d**: Storage usage and growth rates

## Common Issues

### Empty Charts
- Check if data exists in the expected date range
- Verify dashboard time filters match your data
- Ensure dbt models ran successfully

### Dashboard Filter Behavior
- The main Time Range filter applies to most charts
- Query Date filter is scoped to specific query detail charts only
- Storage Date filter applies to storage-specific visualizations

## Maintenance

### Incremental Updates
```bash
# Run incremental updates (after initial full refresh)
dbt run --model +tag:obt
```

### Troubleshooting
- Check dbt logs: `dbt/logs/dbt.log`
- Verify Snowflake connection and permissions
- Review Superset import logs for any errors

## Getting Help

- [Superset Documentation](https://superset.apache.org/)
- [dbt Documentation](https://docs.getdbt.com/)
- [Snowflake ACCOUNT_USAGE Schema](https://docs.snowflake.com/en/sql-reference/account-usage)