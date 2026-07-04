-- ============================================================
-- 02_star_schema.sql
-- Project: Olist E-Commerce Executive BI Dashboard
-- Tujuan : Membangun Star Schema (fact + dimension views)
--          di atas tabel mentah, siap diimport ke Power BI
-- Database: ecommerce_sales
-- ============================================================
-- Catatan: kita hanya fokus ke order yang berstatus 'delivered'
-- karena itu satu-satunya status dengan data tanggal pengiriman
-- lengkap, dan paling relevan untuk analisis revenue/performa.
-- ============================================================


-- ------------------------------------------------------------
-- 1. DIM_DATE
-- Kalender PENUH (tanpa celah tanggal), dari hari pertama
-- sampai hari terakhir order. WAJIB tanpa celah supaya bisa
-- di-set sebagai "Date Table" resmi di Power BI (dibutuhkan
-- oleh fungsi time intelligence seperti DATEADD).
-- ------------------------------------------------------------
DROP VIEW IF EXISTS dim_date CASCADE;
CREATE VIEW dim_date AS
SELECT
    d::DATE                                AS full_date,
    EXTRACT(YEAR FROM d)::INT               AS year,
    EXTRACT(QUARTER FROM d)::INT            AS quarter,
    EXTRACT(MONTH FROM d)::INT              AS month,
    TO_CHAR(d, 'Month')                     AS month_name,
    TO_CHAR(d, 'Day')                       AS day_of_week
FROM generate_series(
    (SELECT MIN(DATE(order_purchase_timestamp)) FROM olist_orders_dataset),
    (SELECT MAX(DATE(order_purchase_timestamp)) FROM olist_orders_dataset),
    INTERVAL '1 day'
) AS d;


-- ------------------------------------------------------------
-- 2. DIM_CUSTOMER
-- ------------------------------------------------------------
DROP VIEW IF EXISTS dim_customer CASCADE;
CREATE VIEW dim_customer AS
WITH customer_revenue AS (
    -- Total revenue per customer, dari order yang delivered saja
    SELECT o.customer_id, SUM(oi.price) AS total_revenue
    FROM olist_order_items_dataset oi
    JOIN olist_orders_dataset o ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY o.customer_id
),
threshold AS (
    -- Cari nilai revenue di titik persentil 80 (batas top 20%)
    SELECT PERCENTILE_CONT(0.8) WITHIN GROUP (ORDER BY total_revenue) AS revenue_threshold
    FROM customer_revenue
)
SELECT
    c.customer_id,
    c.customer_unique_id,
    c.customer_city,
    c.customer_state,
    COALESCE(cr.total_revenue, 0)                          AS customer_total_revenue,
    CASE
        WHEN COALESCE(cr.total_revenue, 0) >= t.revenue_threshold THEN 'Top 20%'
        ELSE 'Others'
    END AS customer_segment
FROM olist_customers_dataset c
LEFT JOIN customer_revenue cr ON c.customer_id = cr.customer_id
CROSS JOIN threshold t;


-- ------------------------------------------------------------
-- 3. DIM_PRODUCT
-- Digabung dengan tabel translation supaya nama kategori
-- dalam Bahasa Inggris (lebih mudah dibaca di dashboard)
-- ------------------------------------------------------------
DROP VIEW IF EXISTS dim_product CASCADE;
CREATE VIEW dim_product AS
SELECT
    p.product_id,
    p.product_category_name,
    COALESCE(t.product_category_name_english, p.product_category_name, 'unknown') AS product_category_name_english,
    p.product_weight_g,
    p.product_length_cm,
    p.product_height_cm,
    p.product_width_cm
FROM olist_products_dataset p
LEFT JOIN product_category_name_translation t
    ON p.product_category_name = t.product_category_name;


-- ------------------------------------------------------------
-- 4. DIM_SELLER
-- ------------------------------------------------------------
DROP VIEW IF EXISTS dim_seller CASCADE;
CREATE VIEW dim_seller AS
SELECT
    seller_id,
    seller_city,
    seller_state
FROM olist_sellers_dataset;


-- ------------------------------------------------------------
-- 5. DIM_DELIVERY
-- Info pengiriman per order: telat berapa hari, status telat/tidak
-- ------------------------------------------------------------
DROP VIEW IF EXISTS dim_delivery CASCADE;
CREATE VIEW dim_delivery AS
SELECT
    order_id,
    order_purchase_timestamp                          AS purchase_date,
    order_delivered_customer_date                      AS delivered_date,
    order_estimated_delivery_date                       AS estimated_date,
    CASE
        WHEN order_delivered_customer_date IS NOT NULL THEN
            EXTRACT(DAY FROM (order_delivered_customer_date - order_estimated_delivery_date))::INT
        ELSE NULL
    END AS delay_days,
    CASE
        WHEN order_delivered_customer_date IS NOT NULL
             AND order_delivered_customer_date > order_estimated_delivery_date
        THEN TRUE
        ELSE FALSE
    END AS is_late
FROM olist_orders_dataset
WHERE order_status = 'delivered';


-- ------------------------------------------------------------
-- 6. FACT_ORDER_ITEMS
-- Tabel fakta utama: 1 baris = 1 item dalam order
-- Hanya order berstatus 'delivered'
--
-- REVISI: tambah kolom primary_payment_type -- diambil dari
-- baris payment dengan payment_sequential = 1 (metode
-- pembayaran pertama/utama yang dipakai order tsb). Karena
-- (order_id, payment_sequential) adalah kombinasi UNIK di
-- tabel payments, join ini tidak menyebabkan fan-out --
-- setiap order_id tetap kembali hanya 1 baris.
-- ------------------------------------------------------------
DROP VIEW IF EXISTS fact_order_items CASCADE;
CREATE VIEW fact_order_items AS
SELECT
    oi.order_id,
    oi.order_item_id,
    oi.product_id,
    o.customer_id,
    oi.seller_id,
    DATE(o.order_purchase_timestamp)   AS full_date,
    oi.price,
    oi.freight_value,
    op.total_payment_value,
    pt.payment_type                    AS primary_payment_type,
    r.avg_review_score
FROM olist_order_items_dataset oi
JOIN olist_orders_dataset o
    ON oi.order_id = o.order_id
-- Agregasi payment dulu per order_id, supaya 1 order = 1 baris
-- (order asli bisa punya beberapa baris payment kalau dicicil)
LEFT JOIN (
    SELECT order_id, SUM(payment_value) AS total_payment_value
    FROM olist_order_payments_dataset
    GROUP BY order_id
) op ON oi.order_id = op.order_id
-- Ambil metode pembayaran PERTAMA (payment_sequential = 1) saja,
-- supaya tidak perlu agregasi kolom teks kategori
LEFT JOIN olist_order_payments_dataset pt
    ON oi.order_id = pt.order_id
    AND pt.payment_sequential = 1
-- Agregasi review dulu per order_id, supaya 1 order = 1 baris
-- (order asli kadang punya lebih dari 1 review)
LEFT JOIN (
    SELECT order_id, AVG(review_score) AS avg_review_score
    FROM olist_order_reviews_dataset
    GROUP BY order_id
) r ON oi.order_id = r.order_id
WHERE o.order_status = 'delivered';


-- ============================================================
-- Verifikasi cepat: jalankan query ini setelah semua view dibuat
-- ============================================================
SELECT 'dim_date' AS view_name, COUNT(*) FROM dim_date
UNION ALL SELECT 'dim_customer', COUNT(*) FROM dim_customer
UNION ALL SELECT 'dim_product', COUNT(*) FROM dim_product
UNION ALL SELECT 'dim_seller', COUNT(*) FROM dim_seller
UNION ALL SELECT 'dim_delivery', COUNT(*) FROM dim_delivery
UNION ALL SELECT 'fact_order_items', COUNT(*) FROM fact_order_items;
-- fact_order_items harus tetap 110.197 baris seperti sebelumnya --
-- kalau jumlahnya berubah/naik, berarti ada fan-out baru dari
-- join primary_payment_type, cek ulang logika payment_sequential = 1

-- Cek rentang tanggal dim_date (harus dari order pertama s/d terakhir, tanpa celah)
SELECT MIN(full_date) AS tanggal_awal, MAX(full_date) AS tanggal_akhir, COUNT(*) AS total_hari
FROM dim_date;

-- Cek isi kolom baru primary_payment_type (harus muncul beberapa
-- kategori seperti credit_card, boleto, voucher, debit_card)
SELECT primary_payment_type, COUNT(*) AS jumlah_item
FROM fact_order_items
GROUP BY primary_payment_type
ORDER BY jumlah_item DESC;

-- ============================================================
-- Selesai. Lanjut: refresh di Power BI, kolom primary_payment_type
-- akan muncul di tabel fact_order_items.
-- ============================================================