# bigquery_dbt_looker

# Code Review Summary

## 1. Model Structure
- **Original**: The model combined everything in one layer.
- **Revised**: Structured the model into distinct stages (medallion architecture), creating 2 layers (bronze and gold).
- **Explanation**:  
  By organizing the model into distinct stages, it becomes much easier to understand and manage.
  Each stage can have its own purpose, such as raw data processing, transformation, and final reporting.
  This structure not only clarifies the workflow but also makes it easier to troubleshoot and make changes, leading to a more efficient development process.
  **Action**
1. Create dbt folder with medallion-architecture:
   A medallion architecture is a data design pattern used to logically organize data in a lakehouse, with the goal of incrementally and progressively improving the structure and quality of data as it flows through each layer of the architecture (from Bronze ⇒ Silver ⇒ 
   Gold layer tables).
- `dbt/models/`
  - `bronze/`: contains raw, unprocessed data.
  - `silver/`: (Optional) Contains cleaned and enriched data, the data is matched, merged, conformed and cleansed ("just-enough") so that the Silver layer can provide an "Enterprise view"
  - `gold/`: Contains fully processed and ready-for-analysis data.
    
**Bronze Layer Setup**

   **DBT models**:
   - Create  dbt models for 3 tables:
     - `bronze_orders.sql`
     - `bronze_agents.sql`
     - `bronze_fulfillments.sql`

   - In each dbt model, write the SQL code to extract data using the `source` function. Note that you should **not** directly reference the table names in dbt model; instead, reference the source defined in the `source.yml` file.

  **YAML Files**:
   - Create a corresponding `.yml` file for each of the tables:
     - `bronze_orders.yml`
     - `bronze_agents.yml`
     - `bronze_fulfillments.yml`
.
  **Source Definition**:
   - Create a `source.yml` file. This file contains the source definitions for all raw tables, pointing to where the raw data is located in your data warehouse. Centralizing your source configuration helps with data lineage and documentation.

**Gold Layer Setup**
- Moved existing file with sql queries to gold folder
- Created daily.product.logistics.yml file with description and tests of all columns in final table
  
  ## 2. Maintainability
- **Original**: Uses `select *`, which can lead to issues if the source tables change.
- **Revised**: Selected only the necessary columns to improve clarity and protect against unexpected changes.
- **Explanation**:  
  Using `select *` can introduce vulnerabilities if the underlying source tables change, potentially leading to unexpected results or performance issues.
   By selecting only the necessary columns, the code becomes cleaner and more intentional. This reduces the risk of breaking changes and simplifies future maintenance, as the impact of changes is more predictable.
   **Action**
  use column names for each table in each dbt models in select statement

## 3. Performance
- 3.1 **Original**: Selected wrong strategy for perfomance
  ```sql
  {{ config(materialized='table') }} 

  ```
  
     **Revised**: Select incremental materialization to imrpove perfomance.

```sql
{{ config(materialized='incremental') }}
with
orders as (
    -- a raw transactional fact table for orders being placed i.e. created
    select 
       orderid, ----added column names instead of *
       productid,
       customerid,
       createdat
    from {{ ref('bronze_orders') }}  --table is not new, using ref 
    {% if is_incremental() %}
       where createdat >= (select max(createdat) - INTERVAL '1day' from {{ this }})  -- Fetch only updated records
    {% endif %}
),

```

- **Explanation**:  
  Implemented incremental logic allows for processing only the new or changed data, optimizing performance and reducing load times.

### 3.2 Original (in CTE, joined optimized code):

```sql
LEFT JOIN fulfillments AS packaged
  ON orders.orderid = packaged.order_id
LEFT JOIN fulfillments AS shipped
  ON orders.orderid = shipped.order_id
LEFT JOIN fulfillments AS delivered
  ON orders.orderid = delivered.order_id
WHERE packaged.event_name = 'order_packaged'
  AND shipped.event_name = 'order_shipped'
  AND delivered.event_name = 'order_delivered'
-- set the grain to one record per order
GROUP BY 1, 2, 3, 4

```

- **Revised**:

```sql
LEFT JOIN fulfillments AS packaged
  ON orders.orderid = packaged.orderid
  AND packaged.event_name = 'order_packaged'
LEFT JOIN fulfillments AS shipped
  ON orders.orderid = shipped.order_id
  AND shipped.event_name = 'order_shipped'
LEFT JOIN fulfillments AS delivered
  ON orders.orderid = delivered.order_id
  AND delivered.event_name = 'order_delivered'
-- set the grain to one record per order
GROUP BY 1, 2, 3, 4

```

 - **Explanation**:  
Moving the event name conditions to the join clause enhances performance by filtering records during the join operation, resulting in fewer records processed later in the pipeline


## 4. Data Integrity
- **Original**: No data quality checks
- **Revised**: Added data tests to ensure all relationships are valid, helping maintain data integrity in yml.files. Also added `utils` and `expectation` packages.
Example of tests:
```yaml
- name: avg_contractor_days_to_pack
  description: "The average number of days it took for contractors to pack orders."
  data tests:
    - not_null
    - dbt_utils.expression_is_true:
        expression: "> 0"

- name: avg_contractor_days_to_ship
  description: "The average number of days it took for contractors to ship orders."
  data tests:
    - not_null
    - dbt_utils.expression_is_true:
        expression: "> 0"

- name: avg_contractor_days_to_deliver
  description: "The average number of days it took for contractors to deliver orders."
  data tests:
    - not_null
    - dbt_utils.expression_is_true:
        expression: "> 0"

- name: current_timestamp_utc
  description: "The timestamp in UTC when the ETL process was executed."
  data tests:
    - not_null
    - unique
    - dbt_utils.date_is_in_past

```
  
- **Explanation**:  
  Ensuring data integrity is crucial for reliable reporting and analysis. By adding data quality checks, potential issues such as missing values or broken relationships can be caught early. The addition of `utils` and `expectation` packages enhances this process by providing standardized methods for testing and validation, maintaining trust in the data.

## 5. Best Practices
## Improvements

- **Macro Folder**: Added a macro folder in the dbt directory to help reuse code and simplify future changes. In the final table, added columns from macros to provide clarity.
- **Pre-commit Hook**: Implemented a pre-commit hook to enforce code quality, ensuring each model has a description and passes linting before merging. This ensures models are well-documented and consistent.
- **GitHub Folder**: Added a `.github` folder with a pull request template for standardization.
- **Workflow Creation**: Created a workflow for the pre-commit hook in GitHub to maintain consistency across team submissions.
- **Spectacles Tests**: Implemented Spectacles tests for LookerML to automate testing of Looker data models.



---

## Looker Explorer File

- **Original**: There was no differentiation between production and development environments in LookerML, and tables/columns lacked descriptions.

- **Revised**:
  - Implemented environment separation in LookerML to distinguish between production and development instances, ensuring safer data handling.
  - Added clear descriptions for all tables and columns in the Looker view and explore files.

### Explanation
Separating production from development in Looker enables safer testing and experimentation without affecting live data, making the process more controlled and secure. Adding descriptions to tables and columns improves documentation and usability, helping end-users understand the data structure and purpose of each field, leading to better data exploration and analysis.
