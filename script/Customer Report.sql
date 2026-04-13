/*
============================================================================================
Customer Report
============================================================================================
Purpose:
This report consolidates key customer metrics and behaviors

Heighlights:
	1.	Gather essential fields such as names, ages, transactions details.
	2.	Segment customers into categories (VIP, Regular, New) and age groups.
	3. Aggregates customer-level metrics:
		- Total orders
		- TOtal sales
		- Total quantity purchased
		- total products.
	4. CAlculate valuable KPIs:
		- Recency (months since last order)
		- Average order value
		- Average monthly spend
===============================================================================
*/
/* ############################################################################

---------------------------------------------------------------------------- */
--drop view if exists gold.CustomerReport;

create or alter view gold.Report_Customer 
as

with base_query as (
/*
1) Base QUery: Retrive core column from tables
*/
	select 
		gf.order_number ,
		gf.product_key,
		gf.order_date,
		gf.sales_amount,
		gf.quantity,
		gc.customer_key,
		gc.customer_number,
		concat(gc.first_name,' ' ,gc.last_name) customer_Name,
		DATEDIFF(year, gc.birth_date, getdate()) age

	from gold.fact_sales gf
	Left Join gold.dim_customers gc
		ON gf.customer_key = gc.customer_key

	WHere gf.order_date is not null) ,

customer_aggregation as (
/*
2) Customer Aggregations: summarizes key metrics at the customer level
*/
select 
	customer_key,
	customer_number,
	customer_Name,
	age,
	count(distinct order_number) Total_Orders,
	sum(sales_amount) total_sales,
	sum(quantity) total_quantity,
	count(distinct product_key) total_products,
	max(order_date) last_order_date,
	DATEDIFF(MONTH, min(order_date),max(order_date)) lifespan
from base_query 
group by 
	customer_key,
	customer_number,
	customer_Name,
	age

)

select

	customer_key,
	customer_number,
	customer_Name,
	age,
	
	Total_Orders,
	total_sales,
	total_quantity,
	total_products,
	last_order_date,
	lifespan,

	-- Classify customers into segments based on their lifespan and total sales
	case 
		when lifespan >=12 and total_sales > 5000 then 'VIP'
		when lifespan >=12 and total_sales <= 5000 then 'Regular'
		else 'New'
	end as customer_segment	,

	-- Classify customers into age groups
	Case 
		When age < 20 then 'Under 20'
		when age  between 20 and 29 then '20-29'
		when age  between 30 and 39 then '30-39'
		when age  between 40 and 49 then '40-49'
		else '50 and Above'  
	end as age_group,

	-- Compute Recency in months
	DATEDIFF(MONTH, last_order_date, GETDATE()) as recency_months,

	-- Compute average Order VAlue (AOV)
	CASE 
		when Total_Orders > 0 then total_sales / Total_Orders  
		else 0
	End average_order_value,

	-- Compute Average Monthly Spend (AMS)
	case 
		when lifespan = 0 then total_sales 
		else total_sales / lifespan
	end as average_monthly_spend

FROM customer_aggregation ;

-- Execution Test:
-- select * from gold.Report_Customer


select rc.customer_segment,
count(rc.customer_number) total_customers,
sum(rc.total_sales) total_sales
from gold.Report_Customer rc
group by rc.customer_segment
order by 3 desc