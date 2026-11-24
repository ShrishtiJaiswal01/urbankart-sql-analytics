# UrbanKart: Online Retail Sales Analytics & Order Management Using PostgreSQL

**Course:** SQL and Data Management (`PMDE30605`)  
**Institution:** School of Management, IILM University, Greater Noida (MBA Batch 2025–27)  
**Faculty Mentor:** Dr. Lalit Jindal  

## Group Members
- **Shrishti Jaiswal** (25SOM2039000050)
- **Kishan Raj** (25SOM2039000146)
- **Ishika Rawat** (25SOM2039000398)
- **Mritunjay Singh** (25SOM2039000376)

## Project Overview
This repository contains the end-to-end PostgreSQL database implementation and analytical report for **UrbanKart**, a mid-sized Indian online retailer. Raw operational records are structured into a Third Normal Form (3NF) schema (`urbankart`) across five tables (`customers`, `categories`, `products`, `orders`, and `order_items`), cleaned with SQL transformations, and queried using views (`v_sales`), subqueries, CTEs, window functions (`RANK`, `LAG`, `ROW_NUMBER`), ACID transactions (`COMMIT`/`ROLLBACK`), and a stored LTV function (`customer_ltv`).

## Repository Files
- `urbankart_queries.sql`: Complete PostgreSQL script covering schema creation (DDL), data loading (DML), data cleaning, `v_sales` analytical view, 11 business intelligence queries, constraint tests, transactions, and stored functions.
- `SQL Assignment.docx` / Final PDF Report: Full project report with ER diagram, pgAdmin 4 query outputs, visualizations, and managerial recommendations.
