# bigquery_dbt_looker

# Code Review Summary

## 1. Model Structure
- **Original**: The model combined everything in one layer.
- **Revised**: Structured the model into distinct stages (medallion architecture), creating 2 layers (bronze and gold).
- **Explanation**:  
  By organizing the model into distinct stages, it becomes much easier to understand and manage.
  Each stage can have its own purpose, such as raw data processing, transformation, and final reporting.
  This structure not only clarifies the workflow but also makes it easier to troubleshoot and make changes, leading to a more efficient development process.
- **Action**
   Create dbt folder with medallion-architecture:
   A medallion architecture is a data design pattern used to logically organize data in a lakehouse, with the goal of incrementally and progressively improving the structure and quality of data as it flows through each layer of the architecture (from Bronze ⇒ Silver ⇒ 
   Gold layer tables).
- `dbt/models/`
  - `bronze/`: contains raw, unprocessed data.
  - `silver/`: (Optional) Contains cleaned and enriched data, the data is matched, merged, conformed and cleansed ("just-enough") so that the Silver layer can provide an "Enterprise view"
  - `gold/`: Contains fully processed and ready-for-analysis data.
    
**Bronze Layer Setup**

   ***DBT models***:
   - Create  dbt models for 3 tables:
     - `bronze_orders.sql`
     - `bronze_agents.sql`
     - `bronze_fulfillments.sql`

   - In each dbt model, write the SQL code to extract data using the `source` function. Note that you should **not** directly reference the table names in dbt model; instead, reference the source defined in the `source.yml` file.

  ***YAML Files***:
   - Create a corresponding `.yml` file for each of the tables:
     - `bronze_orders.yml`
     - `bronze_agents.yml`
     - `bronze_fulfillments.yml`

  ***Source Definition***:
   - Create a `source.yml` file. This file contains the source definitions for all raw tables, pointing to where the raw data is located in your data warehouse. Centralizing your source configuration helps with data lineage and documentation.
   - It is good idea to add also freshness funciton here.Adding a freshness test to your data pipeline makes sure that the data is current and accurate, which is important for making good decisions. It helps catch stale data and problems early,
   - building trust in the  information.
   -  Freshness tests also act as checks that alert teams when data isn’t updated as expected, helping to meet any rules about how timely data should be. Overall, they improve the quality and reliability of your data.
 ```yaml
   sources:
  - name: ecommerce 
    description: ecommerce database
    loader: Fivetran
    database: fivetran_ingest
    schema: ecommerce
    freshness:
      warn_after: { count: 24, period: hour }
      error_after: { count: 48, period: hour }
    loaded_at_field: _fivetran_synced
    tables:
      - name: orders
        description: table of orders that were created
      - name: fulfillments
        description:  key events in the order fulfillment process. 
      - name: agents
        description: agents details
 ```
    
**Gold Layer Setup**
- Moved existing file with sql queries to gold folder
- Created daily.product.logistics.yml file with description
  
  
## 2. Maintainability
      **Original**: Uses `select *`, which can lead to issues if the source tables change.
      **Revised**: Selected only the necessary columns to improve clarity and protect against unexpected changes.
      **Explanation**: Using `select *` can introduce vulnerabilities if the underlying source tables change, potentially leading to unexpected results or performance issues.
        By selecting only the necessary columns, the code becomes cleaner and more intentional. This reduces the risk of breaking changes and simplifies future maintenance, as the impact of changes is more predictable.
      **Action**
        Use column names for each table in each dbt models in select statement

## 3. Performance
- 3.1 **Original**: It could be wrong strategy for perfomance
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

**Explanation**:  
  Implementing incremental logic enables the processing of only new or changed data, optimizing performance and reducing load times. This means that when new data is added, the model does not need to be rebuilt entirely; instead, it only updates the parts that have 
  changed.

- 3.2 **Original**: the code should be more optimized

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
    - The utils package provides reusable functions that simplify common tasks, saving time and promoting consistency in the codebase. The expectation package allows for automated data quality checks, ensuring that the data meets specific standards. 
-Example of tests:
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
```sql
  {% macro get_current_timestamp_utc() %}
    TO_TIMESTAMP_NTZ(CONVERT_TIMEZONE('UTC', CURRENT_TIMESTAMP()))
  {% endmacro %}
final as (
    select date_spine.date_day,
        products.product_id,
        products.product_name,
        products.product_category,
        products.product_subcategory,
        coalesce(avg(days_to_pack), 0) as avg_days_to_pack, --added coalesce to handle situation with no sales
        coalesce(avg(days_to_ship), 0) as avg_days_to_ship,  --added coalesce to handle situation with no sales
        coalesce(avg(days_to_deliver), 0) as avg_days_to_deliver  --added coalesce to handle situation with no sales
        coalesce(avg(case when is_us_customer then days_to_pack else null end), 0) as avg_us_days_to_pack, --added coalesce to handle situation with no sales
        coalesce(avg(case when is_us_customer then days_to_ship else null end), 0) as avg_us_days_to_ship, --added coalesce to handle situation with no sales
        coalesce(avg(case when is_us_customer then days_to_deliver else null end), 0) as avg_us_days_to_deliver,  --added coalesce to handle situation with no sales
        coalesce(avg(case when has_contractor_support then days_to_pack else null end), 0) as avg_contractor_days_to_pack,  --added coalesce to handle situation with no sales
        coalesce(avg(case when has_contractor_support then days_to_ship else null end), 0) as avg_contractor_days_to_ship,  --added coalesce to handle situation with no sales
        coalesce(avg(case when has_contractor_support then days_to_deliver else null end), 0) as avg_contractor_days_to_deliver,  --added coalesce to handle situation with no sales
         {{ get_current_timestamp() }} as current_timestamp_utc-- adding the current UTC timestamp from macros
    from date_spine
    cross join products --cross join is good here, as we need to see all records, even when there were no products sold
    left join order_metrics
        on date_spine.date_day = date(order_metrics.createdat)
        and products.product_id = order_metrics.productid
    group by 1,2,3,4,5
)

select 
    final.date_day,
    final.product_id,
    final.product_name,
    final.product_category,
    final.product_subcategory,
    final.avg_days_to_pack,
    final.avg_days_to_ship,
    final.avg_days_to_deliver,
    final.avg_us_days_to_pack,
    final.avg_us_days_to_ship,
    final.avg_us_days_to_deliver,
    final.avg_contractor_days_to_pack,
    final.avg_contractor_days_to_ship,
    final.avg_contractor_days_to_deliver,
    final.current_timestamp_utc --new column 
 from final

```

- **Pre-commit Hook**: Implemented a pre-commit hook to enforce code quality, ensuring each model has a description and passes linting before merging. This ensures models are well-documented and consistent.
```yaml
# Pre-commit that runs locally
fail_fast: false

repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.6.0
    hooks:
      - id: trailing-whitespace
      - id: check-yaml

  - repo: https://github.com/pre-commit/mirrors-prettier
    rev: v3.1.0
    hooks:
      - id: prettier
        files: '\.(yaml|yml)$'

  - repo: https://github.com/psf/black
    rev: 24.8.0
    hooks:
      - id: black
        language_version: python3.11

  - repo: https://github.com/pycqa/flake8
    rev: 7.1.1
    hooks:
      - id: flake8

  - repo: https://github.com/dbt-checkpoint/dbt-checkpoint
    rev: v2.0.4
    hooks:
      - id: check-model-has-description
      - id: check-model-has-tests-by-group
        args: ["--tests", "not_null", "--test-cnt", "1", "--"]
      - id: check-model-has-tests-by-group
        args:
          [
            "--tests",
            "unique",
            "unique_combination_of_columns",
            "--test-cnt",
            "1",
            "--",
          ]

      - id: check-macro-has-description
        files: ^(macros/).*$

  - repo: https://github.com/sqlfluff/sqlfluff
    rev: 3.1.1
    hooks:
      - id: sqlfluff-fix
        args: [--config, ".sqlfluff", --show-lint-violations]
        additional_dependencies:
          ["dbt-core==1.8.7", "dbt-bigquery==1.8.3", "sqlfluff-templater-dbt"]

```

- **GitHub**: Added .github folder with a pull request template for standartization
```
  Please include a summary of the changes and the related issue. Please also include relevant motivation and context. List any dependencies that are required for this change.

Fixes # (issue)

## Type of Change

Please delete options that are not relevant.

- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update

## How Has This Been Tested?


## Screenshots (if applicable):

If applicable, add screenshots to help explain your changes.

```

- **Workflow Creation**: Created a workflow for the pre-commit hook in Github to maintain consistency across team submission
```yaml
  on:
  push:
    branches:
      - main
# on:
#   schedule:
#     # * is a special character in YAML so you have to quote this string
#     - cron: "0 */12 * * *"
obs:
  permifrost:
    runs-on:
      labels: ubuntu-latest
    defaults:
      run:
        working-directory: permifrost
    steps:
      - name: Checkout code
        uses: actions/checkout@v4.1.4
        with:
          fetch-depth: 1

      - name: Build Permifrost
        run: make build-permifrost
        env:
          PERMISSION_BOT_USER: ${{ secrets.PERMISSION_BOT_USER }}
          PERMISSION_BOT_ACCOUNT: ${{ secrets.PERMISSION_BOT_ACCOUNT }}
          PERMISSION_BOT_WAREHOUSE: ${{ secrets.PERMISSION_BOT_WAREHOUSE }}
          PERMISSION_BOT_PASSWORD: ${{ secrets.PERMISSION_BOT_PASSWORD }}
          PERMISSION_BOT_DATABASE: ${{ secrets.PERMISSION_BOT_DATABASE }}
          PERMISSION_BOT_ROLE: ${{ secrets.PERMISSION_BOT_ROLE }}

      - name: Apply Permifrost Permissions
        run: make permifrost-run
  ```


---

## Looker Explorer File
- **Original**: No structure at all
- **Revised** Structure your project folder
- **Explanation* Organisation within Looker is key. An organised Looker instance will provide more value to your business. Therefore, we recommend you have individual folders for each LookML object. For example, keep all view files in a “views” folder, explore files in an “explores” folder, model files in a “models” folder.
- `looker`
  - `explores/`
  - `views/`
  - `models/`

- **Original**: No setting for cash policy.
- **Revised**: Applying caching policy on model level
- **Explanation**: Normally, whenever you query something from Looker, the query is run against your data warehouse and the result is brought back to Looker. In order for you to save costs and be more efficient, Looker caches your result for 1 hour by default. This feature can be manipulated and set to something like 24 hours — optimising performance with the benefit of saving you money.
- **Action**: Usually we can add persist_for:max_cache_age or there is a way to not repeate code by creating datagroup.lkml file:
***Create datagroup.lkml file
```sql
  datagroup: the24hourupdate {
  
  sql_trigger: SELECT CURDATE();;
  
  max_cache_age: “24 hour”
  
  }

```

***Add this file in explores***

```lkml
  include: "/_views/refined_view/daily_product_logistics.view.lkml"
  include: "/_datagroup/my_datagroup.lkml"
```

 ***Add in view parameter datagroup_trigger***
```lkml
 dimension: product_id {
    type: string
    sql: ${TABLE}.product_id ;;
    datagroup_trigger: the24hourupdate
    description: "Unique identifier for the product." #add description
  }
```

- **Original**: not a user-frinedly interface
- **Revised**: added hidden and primary_key parameter, added group_label because of repetion average type
- **Explanation**: u limit the number of views and dimensions within your explore. Keep useful information and hide unimportant dimensions for user_friendly interface. Missed primary_key parameter
- **Action**
  add hidden and primary key parameter for product id dimentsion
```lkml
   dimension: product_id {
    type: string
    sql: ${TABLE}.product_id ;;
    datagroup_trigger: the24hourupdate # added cash policy
    primary_key: yes # add primary key
    hidden: yes # not necessary dimiension for client
    description: "Unique identifier for the product." #add description
```
  add group_label parameter for each average measure
```lkml
     measure: average_days_to_pack {
    group_label: "Average"
    type: average
    sql: ${avg_days_to_pack} ;;
    description: "The average number of days it took to pack the product."
  }

  measure: average_days_to_ship {
    group_label: "Average"
    type: average
    sql: ${avg_days_to_ship} ;;
    description: "The average number of days it took to ship the product after it was packed."
  }
```


- **Original**: There was no differentiation between production and development environments in LookerML, and tables/columns lacked descriptions.

- **Revised**:
  - Implemented environment separation in LookerML to distinguish between production and development instances, ensuring safer data handling.
  - Added clear descriptions for all tables and columns in the Looker view and explore files.

- **Explanation**:
Separating production from development in Looker enables safer testing and experimentation without affecting live data, making the process more controlled and secure. Adding descriptions to tables and columns improves documentation and usability, helping end-users understand the data structure and purpose of each field, leading to better data exploration and analysis.
```sql
view: daily_product_logistics {
  # Dynamically use the schema based on the user's environment attribute
  sql_table_name: 
    {% if _user_attributes['environment'] == 'prod' %}
      `{{_user_attributes['dbt_schema']}}.daily_product_logistics`
    {% else %}
      `{{_user_attributes['sandbox_schema']}}.daily_product_logistics`
    {% endif %} ;;
```

- **Spectacles Tests**: Implemented Spectacles tests for LookerML to automate testing of Looker data models.

# spectacles.yml
```sql
tests:
  - name: daily_product_logistics
    description: "Tests for daily_product_logistics Explore"
    table: daily_product_logistics

    # Test for product_id
    checks:
      - name: product_id_not_null
        description: "Ensure product_id is not null"
        type: not_null
        field: product_id

      - name: product_id_unique
        description: "Ensure product_id is unique"
        type: unique
        field: product_id

    # Test for product_name
      - name: product_name_not_null
        description: "Ensure product_name is not null"
        type: not_null
        field: product_name

    # Test for date_day
    checks:
      - name: date_day_not_null
        description: "Ensure date_day is not null"
        type: not_null
        field: date_day
      
      - name: date_day_within_valid_range
        description: "Ensure date_day is within a valid range"
        type: expression_is_true
        expression: "date_day >= '2020-01-01'"

    # Tests for average_days_to_pack
    checks:
      - name: average_days_to_pack_not_null
        description: "Ensure average_days_to_pack is not null"
        type: not_null
        field: average_days_to_pack

      - name: average_days_to_pack_non_negative
        description: "Ensure average_days_to_pack is non-negative"
        type: expression_is_true
        expression: "average_days_to_pack >= 0"

 
    checks:
      - name: average_days_to_ship_not_null
        description: "Ensure average_days_to_ship is not null"
        type: not_null
        field: average_days_to_ship

      - name: average_days_to_ship_non_negative
        description: "Ensure average_days_to_ship is non-negative"
        type: expression_is_true
        expression: "average_days_to_ship >= 0"

      - name: average_days_to_deliver_not_null
        description: "Ensure average_days_to_deliver is not null"
        type: not_null
        field: average_days_to_deliver

      - name: average_days_to_deliver_non_negative
        description: "Ensure average_days_to_deliver is non-negative"
        type: expression_is_true
        expression: "average_days_to_deliver >= 0"
```



