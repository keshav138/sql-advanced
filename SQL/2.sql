/*
users(user_id PK, name, email, city, signup_date)

restaurants(restaurant_id PK, name, city, cuisine_type, rating)

menu_items(item_id PK, restaurant_id FK -> restaurants, item_name, price, is_veg)

delivery_agents(agent_id PK, name, city, joining_date)

orders(order_id PK, user_id FK -> users, restaurant_id FK -> restaurants, agent_id FK -> delivery_agents,
       order_date, status, delivery_time_minutes)  -- status: 'placed','delivered','cancelled'

order_items(order_item_id PK, order_id FK -> orders, item_id FK -> menu_items, quantity, unit_price)

ratings(rating_id PK, order_id FK -> orders, user_id FK -> users, restaurant_id FK -> restaurants,
        food_rating, delivery_rating, rating_date)
*/

-- 1. Find the top 3 restaurants by total revenue (based on `order_items`).

select r.restaurant_id, r.name, sum(oi.quantity * oi.unit_price) as revenue
from restaurant r
join orders o on o.restaurant_id = r.restaurant_id
join order_items oi on oi.order_id = o.order_id
group by r.restaurant_id, r.name
order by renvenue
limit 3;

-- 2. For each cuisine type, find the restaurant with the highest average food rating.

with restaurant_ratings as(
    select r.restaurant_id, r.name, r.cuisine_type, avg(rt.food_rating) as avg_rating
    from restaurants r
    join ratings rt on rt.restaurent_id = r.restaurant_id
    group by r.restaurant_id, r.name, r.cuisine_type
),
ranked as(
    select *, rank() over (partition by cuisine_type order by avg_rating desc) as rnk
    from restaurant_ratings
)

select cuisine_type, restaurant_id, name, avg_rating
from restaurant_ratings
where rnk=1;

-- 3. Find delivery agents who delivered orders in every month since they joined (no gaps, up to current date).

with agent_active_months as
(
    select agent_id,
        (extract year from age(current_date, joining_date) * 12) + 
        (extract month from age(current_date, joining_date) + 1) as active_months
    from delivery_agents
),
agent_months_delivered as(
    select agent_id , count(distinct date_trunc('month', order_date)) as actual_months
    from orders
    where status = 'delivered'
    group by agent_id
)
select a.agent_id
from agent_month_active a
join agent_months_delivered on ad.agent_id = a.agent_id
where a.active_months = a.actual_months

-- 4. Find restaurants that have never received a rating.

select r.restaurent_id, r.name
from restaurant_id r
left join ratings rt on rt.restuarant_id = r.restaurant_id
where rt.rating_id IS NULL;

-- 5. Calculate each user's running total spend over time, ordered by order date.

with order_totals as(
    select o.order_id, o.user_id, o.order_date,
        sum(oi.quantity * oi.unit_price) as order_value
    from orders o
    join order_items oi on oi.order_id = o.order_id
    group by o.order_id, o.user_id, o.order_date
)
select user_id, order_id, order_value,
    sum(order_value) over (partition over user_id order by order_date
    rows between unbounded preceding and current row) as running_total
from order_totals
order by user_id, order_date;

-- 6. Find the second-fastest average delivery time restaurant in each city, without using LIMIT/OFFSET.

with restaurant_rankings as (
    select r.restaurant_id, r.name, r.city, avg(o.delivery_time_minutes) as avg_delivery_time
    from restaurants r
    join orders o on o.restuarant_id = r.restaurant_id
    where o.status = "delivered"
    group by r.restuarant_id, r.name, r.city
)
ranked as(
    select *, dense_rank() over (parition by city order by avg_delivery_time asc)
) as rnk
select city, restaurant_id, name, avg_delivery_time
    from restaurant_rankings
    where rnk = 2;

-- or

with restaurant_rankings as(
    select r.restaurant_id, r.name, r.city, avg(o.delivery_time_minutes) as avg_delivery_time,
        dense_rank() over (parition by r.city order by avg(avg_delivery_time) asc) as rnk
    from restaurant r
    join orders o on o.restaurant_id = r.restaurant_id
    where o.status = "delivered"
    group by r.restaurant_id, r.name, r.city
)
select city, restuarant_id, name, avg_delivery_time
from restaurant_rankings
where rnk = 2;

-- 7. Identify users whose average order value is more than double the platform-wide average order value.

with order_totals as(
    select o.order_id, o.user_id, sum(oi.quantity * oi.unit_price) as order_total
    from orders o
    join order_items oi on oi.order_id = o.order_id
    group by o.order_id, o.user_id
    order by order_total
)
select user_id, avg(order_total) as user_average
from order_totals
group by user_id
having avg(order_total) > (select avg(order_total) * 2 from order_totals)

-- 8. Find the month-over-month percentage change in number of delivered orders.

with month_count as(
    select extract(month from order_date) as month_number,
        count(order_id) as  total_orders
    from orders
    where status = "delivered"
    group by extract(month from order_date)
    order by month_number
)
select *, lag(total_orders) over(order by month_number) as prev_month_orders,
100.0 * (total_orders - lag(total_orders) over (order by month_number)) / 
nullif(lag(total_orders) over (order by month), 0) as month_over_month_increase
from month_count
order by month_number

-- 9. Find restaurants with an average food_rating below 3 but more than 10 ratings.

with average_ratings as(
    select r.restaurant_id, r.name, avg(rt.food_rating) as average_food_rating, count(*) as ratings_count
    from restaurants r
    join ratings rt on rt.restaurant_id = r.restaurant_id
    group by r.restaurant_id, r.name
)
select *
from average_ratings
where average_food_rating < 3 and ratings_count > 10
order by average_food_rating desc;

-- or

select r.restaurant_id, r.name, avg(rt.food_rating) as average_food_rating, count(*) as ratings
from restaurants r
join ratings rt on rt.restaurant_id = r.restaurant_id
group by r.restaurant_id, r.name
having avg(rt.food_rating) < 3 and count(*) > 10;


-- 10. Find pairs of menu items frequently ordered together in the same order, ordered by frequency (limit to same-restaurant pairs).

select oi.order_item_id as product_a, oii.order_item_id as product_b, count(*) as times_brought_together
from order_items oi
join order_items oii on oii.order_item_id = oi.order_item_id
where oi.order_id > oii.order_id
group by oi.order_item_id, oii.order_item_id
order by times_brought_together desc

