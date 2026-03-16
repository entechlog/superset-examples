# Snowflake Account Usage DBT Project

This DBT project provides comprehensive monitoring and analytics for Snowflake account usage, including compute, storage, and query performance tracking.

## Setup & Usage

### Environment Setup

1. Copy `.env.template` to `.env` and add your credentials
2. Source the environment variables
3. Validate credentials:
   ```bash
   env | grep -e SNOW -e CODE
   ```

### Full Refresh OBT Models

```bash
dbt run --model +tag:obt --full-refresh --vars '{"run_type":"full-refresh"}'
```

## Project Structure

### Data Models

**Prep Layer (`prep__*`)**
- Raw data transformation and standardization
- Environment classification and metric calculations

**Data Warehouse Layer (`dw__*`)**
- Fact tables: Core business events and measurements
- Dimension tables: Reference data and hierarchies
- OBT tables: Optimized for reporting and analytics

**Model Categories:**
- **Compute**: Warehouse usage, credits, and costs
- **Storage**: Database storage by type and environment
- **Query**: Query performance, costs, and patterns

### Key Features

- **Environment Classification**: Automatic PRD/DEV/TEST/STG categorization
- **Cost Tracking**: Detailed cost allocation and trending
- **Performance Monitoring**: Query execution and warehouse utilization
- **Date Spine Logic**: Ensures continuous trend lines in dashboards
- **Incremental Loading**: Efficient daily data processing

## Dashboard Integration

The models support comprehensive Snowflake monitoring dashboards with:

- **Cost Analytics**: Daily spend tracking by environment and resource type
- **Performance Metrics**: Query execution times, success rates, and bottlenecks
- **Resource Optimization**: Warehouse utilization and storage growth patterns
- **Operational Insights**: User activity, database usage, and trend analysis

## Data Lineage

```
Snowflake Account Usage Views
├── prep__* (Staging & Transformation)
├── dw__fact_* (Core Facts)
├── dw__dim_* (Dimensions)
└── dw__obt_* (Reporting Tables)
```

## Contributing

- Follow existing naming conventions
- Update documentation for new models
- Test thoroughly before merging changes