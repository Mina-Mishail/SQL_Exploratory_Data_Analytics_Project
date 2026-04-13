 /*
 ===================================================================
 Build Product Report
 ===================================================================
 Purpose:
	- This report consolidates key product metrics and behaviors.

	Heighlights:
	1.	Gather essential fields such as product names, categories, subcategory, and sales details.
	2.	Segment products by revenue to identify High-Performers, Mid-Range, or Low-Performers.
	3. Aggregates product-level metrics:
		- Total orders
		- Total sales
		- Total quantity sold
		- Total customers purchased (unique)
		- Lifespan (months between first and last sale)
	4. CAlculate valuable KPIs:
		- Recency (months since last sale)
		- Average order revenue (AOR)
		- Average monthly revenue (AMR)
	==============================================================================
 
 */

 create or alter view gold.Report_Product 
 as

 with base_query as (
/*
1) Base QUery: Retrive core column from tables
*/
 select
 gf.order_number ,
 gf.order_date,
 gf.customer_key,
 gf.sales_amount,
 gf.quantity,
 gp.product_name,
 gp.product_key,
 gp.category,
 gp.subcategory,
 gp.cost
 from gold.fact_sales gf
 Left join gold.dim_products gp
	ON gf.product_key = gp.product_key
	) ,

	product_aggregation as (
/*
2) Product Aggregations: summarizes key metrics at the Product level
*/

	select 
	p.product_key,
	p.product_name,
	p.category,
	p.subcategory,
	p.cost,
	DATEDIFF(MONTH, MIN(p.order_date),max(order_date)) as lifespan,
	max(p.order_date) last_sales_Date,
	count(distinct p.order_number) Total_Orders,
	count(distinct p.customer_key) Total_customers,
	sum(p.sales_amount) total_sales,
	sum(p.quantity) total_quantity,
	round(AVG(cast(p.sales_amount  as float)/ nullif(p.quantity,0)), 1)  as AVG_Selling_Price
	from base_query p
	group by p.product_key,
	p.product_name,
	p.category,
	p.subcategory,
	p.cost
)

/*
3) Final Selection: Combine all product metrics results into one output
	In addition to applying segmentation logic
*/
select 
pa.product_key,
pa.product_name,
pa.category,
pa.subcategory,
pa.cost,
pa.last_sales_Date,
DATEDIFF(month,last_sales_Date, GETDATE()) as recency_in_months,

-- Segment products based on total sales
CASE
	WHEN total_sales>50000 then 'High-Performer'
	WHEN total_sales between 10000 and 50000 then 'Mid-Range'
	ELSE 'Low-Performer'
END as Product_Segment,

pa.lifespan,
pa.Total_Orders,
pa.total_sales,
pa.total_quantity,	
pa.Total_customers,
pa.AVG_Selling_Price,

-- Average Order Revenue (AOR)
CASE 
	WHEN Total_Orders > 0 THEN round(total_sales / Total_Orders, 2)
	ELSE 0
END as Average_Order_Revenue,

-- Average Monthly Revenue (AMR)
CASE 
	WHEN lifespan = 0 THEN -- only 1 month
			total_sales 
	ELSE Round(total_sales / lifespan, 2)
END as Average_Monthly_Revenue

from product_aggregation pa;


-- Test view output
select * from gold.Report_Product