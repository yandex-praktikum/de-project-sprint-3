delete from mart.f_customer_retention
where period_id = (
	select week_of_year 
	from mart.d_calendar dc
	where date_actual = '{{ds}}'
	);

INSERT INTO mart.f_customer_retention
(new_customers_count, returning_customers_count, refunded_customer_count, period_name, period_id, item_id, new_customers_revenue, returning_customers_revenue, customers_refunded)
with customers as ( 
	select * 
	from mart.f_sales fs 
		inner join mart.d_calendar dc on 
			fs.date_id = dc.date_id 
	where dc.week_of_year = date_part('week', '{{ds}}'::DATE)
),
new_customers as ( 
	select  
		customer_id, 
		week_of_year 
	from customers 
	where status = 'shipped' 
	group by week_of_year, customer_id 
	having count(*) = 1 
), 
returning_customers as ( 
	select  
		customer_id, 
		week_of_year 
	from customers 
	where status = 'shipped' 
	group by week_of_year, customer_id 
	having count(*) > 1 
), 
refunded_customers as ( 
	select  
		customer_id, 
		week_of_year 
	from customers 
	where status = 'refunded' 
	group by week_of_year, customer_id 
) 
select 
	count(distinct nc.customer_id) as new_customers_count, 
	count(distinct rc.customer_id) as returning_customers_count, 
	count(distinct rfc.customer_id) as refunded_customer_count, 
	'weekly' as period_name, 
	cs.week_of_year as period_id, 
	cs.item_id, 
	sum(case  
		when nc.customer_id is not null then cs.payment_amount 
	end) as new_customers_revenue, 
	sum(case  
		when rc.customer_id is not null then cs.payment_amount 
	end) as returning_customers_revenue, 
	count(case  
		when rfc.customer_id is not null then cs.payment_amount 
	end) as customers_refunded 
FROM customers cs
    left join new_customers nc on nc.customer_id = cs.customer_id and nc.week_of_year = cs.week_of_year and cs.status='shipped' 
    left join returning_customers rc on rc.customer_id = cs.customer_id and rc.week_of_year = cs.week_of_year and cs.status='shipped' 
    left join refunded_customers rfc on rfc.customer_id = cs.customer_id and rfc.week_of_year = cs.week_of_year and cs.status='refunded'  
group by cs.week_of_year, cs.item_id
;