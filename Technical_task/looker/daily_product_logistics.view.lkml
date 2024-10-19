## Looker View File

view: daily_product_logistics {
  sql_table_name: `dbt.daily_product_logistics` ;;

  dimension: product_id {
    type: string
    sql: ${TABLE}.product_id ;;
  }

  dimension: product_name {
    type: string
    sql: ${TABLE}.product_name ;;
  }

  dimension: product_category {
    sql: ${TABLE}.product_category ;;
  }

  dimension: product_subcategory {
    sql: ${TABLE}.product_subcategory ;;
  }

  dimension_group: date_day {
    type: time
    timeframes: [raw, date]
    convert_tz: no
    datatype: date
    sql: ${TABLE}.date_day ;;
  }

  measure: average_days_to_pack {
    type: average
    sql: ${avg_days_to_pack} ;;
  }

  measure: average_days_to_ship {
    type: average
    sql: ${avg_days_to_ship} ;;
  }

  measure: average_days_to_deliver {
    type: average
    sql: ${avg_days_to_deliver} ;;
  }

  measure: average_days_to_pack_us_customers {
    type: average
    sql: ${avg_us_days_to_pack} ;;
  }

  measure: average_days_to_ship_us_customers {
    type: average
    sql: ${avg_us_days_to_ship} ;;
  }

  measure: average_days_to_deliver_us_customers {
    type: average
    sql: ${avg_us_days_to_deliver} ;;
  }

  measure: average_days_to_pack_contractor_customers {
    type: average
    sql: ${avg_contractor_days_to_pack} ;;
  }

  measure: average_days_to_ship_contractor_customers {
    type: average
    sql: ${avg_contractor_days_to_ship} ;;
  }

  measure: average_days_to_deliver_contractor_customers {
    type: average
    sql: ${avg_contractor_days_to_deliver} ;;
  }
}