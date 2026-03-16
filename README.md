# superset-examples

## Overview
This repository contains Apache Superset examples and monitoring dashboards for Snowflake, deployable via Docker.

## Available Solutions

### Snowflake Monitoring Dashboards

#### [Snowflake Account Usage](./superset-snowflake-usage/)
Comprehensive monitoring of your Snowflake account with dbt-powered data models and Superset visualizations.
- **Compute Analytics**: Credits, warehouse utilization, query performance
- **Storage Insights**: Database sizes, growth trends, costs
- **Query Analysis**: Execution patterns, resource consumption
- **Cost Tracking**: Daily/monthly trends by warehouse and database

#### [Snowpipe Usage](./superset-snowpipe-usage/)
Monitor and analyze your Snowflake Snowpipe data ingestion pipelines.
- **Pipeline Performance**: Files processed, data volumes, processing times
- **Cost Analysis**: Credits consumed by pipes
- **Error Monitoring**: Failed files and error patterns
- **Status Dashboard**: Real-time pipe health and activity

### Other Examples

- [Superset Tools](./superset-tools/) - Standalone Superset setup and utilities
- [Superset with Snowflake](./superset-snowflake/) - Basic Snowflake integration examples

## Getting Started

Each project includes:
- Docker Compose configuration for easy deployment
- Pre-built dashboards and charts
- Sample data models (where applicable)
- Setup instructions in individual README files

## Prerequisites

- Docker and Docker Compose
- Snowflake account (for Snowflake-related dashboards)
- Basic familiarity with Apache Superset

## Contributing

Feel free to submit issues, feature requests, or pull requests to enhance these examples.