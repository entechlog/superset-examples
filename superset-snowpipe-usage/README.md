# Snowpipe Usage Monitoring

Monitor and visualize your Snowflake Snowpipe data ingestion pipelines using Apache Superset dashboards.

## Quick Start

### Prerequisites
- Docker and Docker Compose
- Snowflake account with access to pipe usage data
- Snowpipe data models deployed (snowflake_pipe_* tables)

### Setup

1. **Configure Environment Variables**
```bash
# Create .env file with database connection details
# Ensure your Snowflake database contains the required pipe monitoring tables
```

2. **Start Superset**
```bash
docker-compose up -d
```

3. **Import Dashboard Assets**
```bash
docker exec -it apache-superset /bin/bash
cd /usr/src/
superset import-directory assets --overwrite
```

## What's Included

### Monitoring Capabilities
- **Pipe Performance**: Files processed, data loaded (GB), processing times
- **Cost Analysis**: Credits used, daily costs, cost trends
- **Error Tracking**: Failed file counts, error patterns
- **Status Overview**: Current pipe status and health

### Required Data Models
- **snowflake_pipe_copy_history**: Detailed copy operation history
- **snowflake_pipe_stats**: Aggregated pipe statistics
- **snowflake_pipe_status**: Current status of all pipes

## Common Issues

### Missing Data
- Verify Snowpipe usage tables exist in your database
- Check that pipes have recent activity to display
- Ensure proper permissions on PIPE_USAGE_HISTORY views

### Dashboard Filters
- Time Range filter for historical analysis
- Pipe Name filter to focus on specific pipelines
- Database/Schema filters for multi-tenant environments

## Maintenance

### Data Refresh
- Pipe usage data typically updates every few hours
- Dashboard auto-refreshes based on configured intervals
- Manual refresh available via dashboard controls

## Getting Help

- [Snowpipe Documentation](https://docs.snowflake.com/en/user-guide/data-load-snowpipe)
- [Superset Documentation](https://superset.apache.org/)
- [Snowflake PIPE_USAGE_HISTORY](https://docs.snowflake.com/en/sql-reference/account-usage/pipe_usage_history)