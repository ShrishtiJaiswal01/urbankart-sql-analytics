CREATE SCHEMA urbankart;  SET search_path TO urbankart;

CREATE TABLE customers (  
customer_id SERIAL PRIMARY KEY,  
full_name   VARCHAR(80) NOT NULL,  
email       VARCHAR(100) UNIQUE,  city VARCHAR(40),  
segment     VARCHAR(20) CHECK (segment IN ('Regular','Premium','Corporate')),  
joined_on   DATE NOT NULL );

SET search_path TO urbankart;
CREATE TABLE categories (
    category_id SERIAL PRIMARY KEY,
    category_name VARCHAR(50) UNIQUE NOT NULL
);

CREATE TABLE products (  
product_id  SERIAL PRIMARY KEY,  
product_name VARCHAR(80) NOT NULL,  
category_id INT NOT NULL REFERENCES categories(category_id),  
unit_price  NUMERIC(10,2) NOT NULL CHECK (unit_price > 0),  
cost_price  NUMERIC(10,2) NOT NULL CHECK (cost_price > 0),  
stock_qty   INT NOT NULL DEFAULT 0 CHECK (stock_qty >= 0) );

CREATE TABLE orders (  
order_id    SERIAL PRIMARY KEY,  
customer_id INT NOT NULL REFERENCES customers(customer_id),  
order_date  DATE NOT NULL,  
status      VARCHAR(15) NOT NULL CHECK (status IN ('Delivered','Shipped','Cancelled','Returned')),  
payment_mode VARCHAR(15) );

CREATE TABLE order_items (  
item_id SERIAL PRIMARY KEY,  
order_id INT NOT NULL REFERENCES orders(order_id) ON DELETE CASCADE, 
product_id INT NOT NULL REFERENCES products(product_id),  
quantity   INT NOT NULL CHECK (quantity > 0),  
discount_pct NUMERIC(4,1) NOT NULL DEFAULT 0 CHECK (discount_pct BETWEEN 0 AND 50) );

CREATE INDEX idx_orders_cust ON orders(customer_id); 
CREATE INDEX idx_orders_date ON orders(order_date); 
CREATE INDEX idx_items_order ON order_items(order_id); 
CREATE INDEX idx_items_prod  ON order_items(product_id);

SET search_path TO urbankart;
SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM customers
UNION ALL SELECT 'categories', COUNT(*) FROM categories
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'orders', COUNT(*) FROM orders
UNION ALL SELECT 'order_items', COUNT(*) FROM order_items;

SET search_path TO urbankart;
SELECT setval('customers_customer_id_seq', COALESCE((SELECT MAX(customer_id) FROM customers), 1));
SELECT setval('categories_category_id_seq', COALESCE((SELECT MAX(category_id) FROM categories), 1));
SELECT setval('products_product_id_seq', COALESCE((SELECT MAX(product_id) FROM products), 1));
SELECT setval('orders_order_id_seq', COALESCE((SELECT MAX(order_id) FROM orders), 1));
SELECT setval('order_items_item_id_seq', COALESCE((SELECT MAX(item_id) FROM order_items), 1));

UPDATE customers SET city = INITCAP(TRIM(city)), full_name = INITCAP(TRIM(full_name));
UPDATE customers SET email = 'unknown_'||customer_id||'@noemail.com' WHERE email IS NULL;
UPDATE orders SET payment_mode = 'Unknown' WHERE payment_mode IS NULL;
DELETE FROM customers WHERE email NOT LIKE '%@%.com' AND customer_id NOT IN (SELECT customer_id FROM orders);

CREATE OR REPLACE VIEW v_sales AS
SELECT o.order_id, o.order_date, o.status, o.payment_mode,
       c.customer_id, c.full_name, c.city, c.segment,
       p.product_id, p.product_name, cat.category_name, 
       oi.quantity, oi.discount_pct,
       ROUND(oi.quantity * p.unit_price * (1 - oi.discount_pct / 100), 2) AS revenue,
       ROUND(oi.quantity * p.unit_price * (1 - oi.discount_pct / 100) - oi.quantity * p.cost_price, 2) AS profit
FROM order_items oi
JOIN orders o ON o.order_id = oi.order_id
JOIN customers c ON c.customer_id = o.customer_id
JOIN products p ON p.product_id = oi.product_id
JOIN categories cat ON cat.category_id = p.category_id;

SELECT 
    order_id,
    full_name,
    city,
    product_name,
    category_name,
    revenue,
    profit
FROM v_sales
LIMIT 6;

SELECT TO_CHAR(order_date,'YYYY-MM') AS month, 
COUNT(DISTINCT order_id) AS orders,       
SUM(revenue) AS revenue, 
SUM(profit) AS profit 
FROM v_sales WHERE status IN ('Delivered','Shipped') GROUP BY 1 ORDER BY 1;

SELECT category_name, 
SUM(quantity) AS units, 
SUM(revenue) AS revenue, 
SUM(profit) AS profit,       
ROUND(100*SUM(profit)/SUM(revenue),1) AS margin_pct 
FROM v_sales WHERE status IN ('Delivered','Shipped') GROUP BY 1 ORDER BY revenue DESC;

SELECT product_name, 
SUM(revenue) AS revenue FROM v_sales 
WHERE status IN ('Delivered','Shipped') GROUP BY product_name 
HAVING SUM(revenue) > (SELECT AVG(r) FROM (SELECT SUM(revenue) r FROM v_sales         
WHERE status IN ('Delivered','Shipped') GROUP BY product_id) x) 
ORDER BY revenue DESC;

SELECT status, COUNT(*) AS orders,       
ROUND(100.0*COUNT(*)/SUM(COUNT(*)) OVER (),1) AS pct 
FROM orders GROUP BY status ORDER BY orders DESC;

SELECT city, 
COUNT(DISTINCT customer_id) AS customers, 
SUM(revenue) AS revenue
FROM v_sales
WHERE status IN ('Delivered', 'Shipped')
GROUP BY city
ORDER BY revenue DESC;

SELECT payment_mode, 
COUNT(*) AS orders,
ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 1) AS pct
FROM orders
GROUP BY payment_mode
ORDER BY orders DESC;

SELECT * FROM (  
SELECT full_name, city, segment, SUM(revenue) AS revenue,         
RANK() OVER (ORDER BY SUM(revenue) DESC) AS rnk  
FROM v_sales WHERE status IN ('Delivered','Shipped')  
GROUP BY full_name, city, segment) t 
WHERE rnk <= 5;

WITH m AS (SELECT TO_CHAR(order_date,'YYYY-MM') mon, 
SUM(revenue) rev FROM v_sales WHERE status IN ('Delivered','Shipped') GROUP BY 1) 
SELECT mon, rev, SUM(rev) OVER (ORDER BY mon) AS running_total,       
ROUND(100*(rev-LAG(rev) OVER (ORDER BY mon)) /LAG(rev) OVER (ORDER BY mon),1) AS mom_growth_pct 
FROM m ORDER BY mon;

WITH p AS (  
SELECT category_name, product_name, SUM(revenue) rev,         
ROW_NUMBER() OVER (PARTITION BY category_name ORDER BY SUM(revenue) DESC) rn  
FROM v_sales WHERE status IN ('Delivered','Shipped') 
GROUP BY category_name, product_name) 
SELECT category_name, product_name, rev FROM p WHERE rn = 1 ORDER BY rev DESC;

WITH t AS (SELECT customer_id, full_name, SUM(revenue) spend FROM v_sales           
WHERE status IN ('Delivered','Shipped') GROUP BY 1,2) 
SELECT CASE WHEN spend>=40000 THEN 'High value'            
WHEN spend>=20000 THEN 'Mid value' ELSE 'Low value' END AS tier,       
COUNT(*) customers, ROUND(AVG(spend)) avg_spend 
FROM t GROUP BY 1 ORDER BY 3 DESC;

SELECT p.product_name, p.stock_qty, COALESCE(SUM(oi.quantity),0) AS units_sold 
FROM products p LEFT JOIN order_items oi USING(product_id) 
GROUP BY p.product_id ORDER BY p.stock_qty - COALESCE(SUM(oi.quantity),0) LIMIT 5;

SET search_path TO urbankart;
INSERT INTO products (product_name, category_id, unit_price, cost_price, stock_qty)
VALUES ('Test Item', 1, -10, 50, 10);

INSERT INTO orders (customer_id, order_date, status, payment_mode)
VALUES (9999, DATE '2026-03-01', 'Shipped', 'UPI');

BEGIN;
WITH new_order AS (
INSERT INTO orders (customer_id, order_date, status, payment_mode)
VALUES (1, DATE '2026-03-01', 'Shipped', 'UPI')
RETURNING order_id
)
INSERT INTO order_items (order_id, product_id, quantity, discount_pct)
SELECT order_id, 1, 2, 10 FROM new_order;
UPDATE products SET stock_qty = stock_qty - 2 WHERE product_id = 1;
COMMIT;

-- Verify stock dropped from 120 to 118
SELECT product_id, product_name, stock_qty FROM products WHERE product_id = 1;

BEGIN; 
UPDATE products SET stock_qty = stock_qty - 5 WHERE product_id = 2;                                                            
ROLLBACK; 

-- Verify stock reverted to 60
SELECT product_id, product_name, stock_qty FROM products WHERE product_id = 2;

CREATE OR REPLACE FUNCTION customer_ltv(cid INT) RETURNS NUMERIC AS $$
  SELECT COALESCE(SUM(revenue), 0)
  FROM v_sales
  WHERE customer_id = cid AND status IN ('Delivered', 'Shipped');
$$ LANGUAGE sql;
SELECT customer_ltv(1); 

