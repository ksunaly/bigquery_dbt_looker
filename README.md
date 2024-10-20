# bigquery_dbt_looker

# Code Review Summary

## 1. Model Structure
- **Original**: The model combined everything in one layer.
- **Revised**: Structured the model into distinct stages (medallion architecture), creating 2 layers (bronze and gold).
- **Explanation**:  
  By organizing the model into distinct stages, it becomes much easier to understand and manage.
  Each stage can have its own purpose, such as raw data processing, transformation, and final reporting.
  This structure not only clarifies the workflow but also makes it easier to troubleshoot and make changes, leading to a more efficient development process.

## 2. Maintainability
- **Original**: Uses `select *`, which can lead to issues if the source tables change.
- **Revised**: Selected only the necessary columns to improve clarity and protect against unexpected changes.
- **Explanation**:  
  Using `select *` can introduce vulnerabilities if the underlying source tables change, potentially leading to unexpected results or performance issues.
   By selecting only the necessary columns, the code becomes cleaner and more intentional. This reduces the risk of breaking changes and simplifies future maintenance, as the impact of changes is more predictable.

## 3. Performance
- **Original**: The cross join between `date_spine` and `products` can blow up the result set and slow down the query.
- **Revised**: Replaced it with a more efficient inner join to keep the result set manageable and improve performance. Also, added incremental logic.
- **Explanation**:  
  Cross joins can create excessively large result sets, significantly impacting query performance and resource consumption. Switching to an inner join narrows down the data being processed, enhancing efficiency. Additionally, implementing incremental logic allows for processing only the new or changed data, optimizing performance and reducing load times.

## 4. Data Integrity
- **Original**: Lacked data quality checks, which could lead to potential issues.
- **Revised**: Added data tests to ensure all relationships are valid, helping maintain data integrity. Also added `utils` and `expectation` packages.
- **Explanation**:  
  Ensuring data integrity is crucial for reliable reporting and analysis. By adding data quality checks, potential issues such as missing values or broken relationships can be caught early. The addition of `utils` and `expectation` packages enhances this process by providing standardized methods for testing and validation, maintaining trust in the data.

## 5. Best Practices
- **Improvements**:  
  - Added a macro to encapsulate complex logic, promoting code reuse and simplifying future updates.
  - Implemented a pre-commit hook to enforce code quality, ensuring each model has a description and passes linting before merging.
  - Added a `.github` folder with a pull request template to standardize contributions.
  - Created a workflow for the pre-commit hook in GitHub to maintain consistency across team submissions.
  - Implemented Spectacles tests for LookerML to automate testing of Looker data models.
- **Explanation**:  
  Macros promote code reuse and modularity, reducing duplication and simplifying future changes. Pre-commit hooks prevent low-quality code from being merged, ensuring models are well-documented and consistent. The GitHub PR template and workflow standardize code reviews, while Spectacles testing automates validation, improving overall reliability.

## 6. Looker Explorer File
- **Original**: There was no differentiation between production and development environments in LookerML, and tables/columns lacked descriptions.
- **Revised**:  
  - Implemented environment separation in LookerML to distinguish between production and development instances, ensuring safer data handling.
  - Added clear descriptions for all tables and columns in the Looker view and explore files.
- **Explanation**:  
  Separating production from development in Looker enables safer testing and experimentation without affecting live data, making the process more controlled and secure. Adding descriptions to tables and columns improves documentation and usability, helping end-users understand the data structure and purpose of each field, leading to better data exploration and analysis.
