/*
customers(customer_id PK, name, email, city, signup_date)

categories(category_id PK, category_name)

products(product_id PK, product_name, category_id FK -> categories, price, stock_qty)

orders(order_id PK, customer_id FK -> customers, order_date, status)  -- status: 'placed','shipped','delivered','cancelled'

order_items(order_item_id PK, order_id FK -> orders, product_id FK -> products, quantity, unit_price)

payments(payment_id PK, order_id FK -> orders, payment_date, amount, method)

reviews(review_id PK, product_id FK -> products, customer_id FK -> customers, rating, review_date)
*/


--  Find the top 3 customers by total amount spent (based on payments), including their name and total.

select c.customer_id, c.name, sum(p.amount) as total_spent
from customers c
join orders o on o.customer_id = c.customer_id
join payments p on p.order_id = o.order_id
group by c.customer_id, c.name
order by total_spent
limit 3

-- For each category, find the best-selling product (by total quantity sold via order_items).

with sales as (
    select p.product_id, p.category_id, p.product_name
        sum(oi.quantity) as qty_sold,
        rank() over (partition by p.category_id order by sum(oi.quantity) as rnk
    from products p
    join order_items oi over oi.product_id = p.product_id
    group by p.category_id, p.product_id, p.product_name
)
select category_id, product_name, qty_sold
from sales
where rnk=1;


-- List customers who have placed orders in every month of 2025 (no gaps).

select c.customer_id, c.customer_name
from customer c
join orders o on o.customer_id = c.customer_id
where o.order_data > '2025-01-01' and o.order_data < '2026-01-01'
group by customer_id
having count(distinct extract(month from o.order_date)) = 12;

-- Find products that have never been ordered.

select p.product_id, p.product_name
from product p
left join orders_items oi on oi.product_id = p.product_id
where oi.order_item_id IS NULL;

-- Calculate each customer's running total spend over time, ordered by order date (window function).

select c.customer_id, c.customer_name, o.order_id, o.order_date, p.amount,
SUM(p.amount) over (partition by c.customer_id order by o.order_date rows between unbounded preceding and current row) as running_total
from customers c
join orders o on o.customer_id = c.customer_id
join payments p on p.order_id = o.order_id
order by c.customer_id, o.order_date


-- Find the second-highest priced product in each category without using LIMIT/OFFSET (use RANK()/subquery).

with pricey as(
    select product_id, product_name, price,
    rank() over (partition by category_id order by price DESC) as rnk
    from products
)

select product_id, product_name, price
from pricey
where rnk = 2;


-- Identify customers whose average order value is above the overall average order value.
/*
first calc the total order values per order, gettting the cart value, then avg the customers cart value, then compare the customers avg with the general avg
*/

with order_values as(
    select o.order_id, o.customer_id, sum(oi.quantity * oi.unit_price) as order_values,
        from order o
    join order_items oi on oi.order_id = o.order_id
    group_by o.order_id, o.customer_id
),
customer_avg as(
    select customer_id, avg(order_value) as order_value
    from order_values
    group by customer_id
)
select customer_id, avg_order_value
from customer_avg
where avg_order_value > (select avg(order_value) from order_values);


-- Find the month-over-month percentage growth in total revenue.

with monthly as(
    select date_trunc('month', payment_date) as month, sum(p.amount) as revenue,
        from payments
    group by date_trunc('month', payment_date)
)

select month, revenue,
    lag(revenue) over (order by month) as prev_revenue_month,
    round(100.0 * (revenue - lag(revenue) over (order by month)) / nullif(lag(revenue) over (order by month), 0), 2) as growth_pct
from monthly
order by month;


-- List products with an average rating below 3 but more than 5 reviews.

select p.product_id, p.product_name, avg(r.rating) as overall_rating, count(*) as review_count
from products p
join reviews r on r.product_id = p.product_id
group by p.product_id, p.product_name
having avg(r.rating) < 3 and count(*) > 5;

-- Find pairs of products frequently bought together in the same order (self-join on order_items), ordered by frequency.

select a.product_id as product_a, b.product_id as product_b, count(*) as times_brought_together
from orders a
join orders b on b.order_id = a.order_id
and a.product_id < b.product_id
group by a.product_id, b.product_id
order by times_brought_together desc
