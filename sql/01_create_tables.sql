-- ============================================================
-- 01_create_tables.sql
-- Project : Olist E-Commerce Executive BI Dashboard
-- Tujuan  : (1) Membuat tabel mentah (raw) sesuai struktur asli
--               dataset Olist Brazilian E-Commerce
--           (2) Import data CSV ke masing-masing tabel
--           (3) Verifikasi jumlah baris tiap tabel
-- Database: ecommerce_sales
-- ============================================================
-- PENTING: pastikan Query Tool ini terhubung ke database
-- "ecommerce_sales" (bukan "postgres"). Cek dengan:
--   SELECT current_database();
-- ============================================================


-- ============================================================
-- BAGIAN 1 -- CREATE TABLE
-- Urutan dibuat agar FOREIGN KEY tidak error:
-- tabel independen dibuat dulu, baru tabel yang mereferensikannya
-- ============================================================

-- 1. CUSTOMERS
DROP TABLE IF EXISTS olist_customers_dataset CASCADE;
CREATE TABLE olist_customers_dataset (
    customer_id               VARCHAR(50) PRIMARY KEY,
    customer_unique_id        VARCHAR(50),
    customer_zip_code_prefix  VARCHAR(10),
    customer_city             VARCHAR(100),
    customer_state            VARCHAR(5)
);

-- 2. SELLERS
DROP TABLE IF EXISTS olist_sellers_dataset CASCADE;
CREATE TABLE olist_sellers_dataset (
    seller_id                VARCHAR(50) PRIMARY KEY,
    seller_zip_code_prefix   VARCHAR(10),
    seller_city              VARCHAR(100),
    seller_state             VARCHAR(5)
);

-- 3. PRODUCTS
DROP TABLE IF EXISTS olist_products_dataset CASCADE;
CREATE TABLE olist_products_dataset (
    product_id                  VARCHAR(50) PRIMARY KEY,
    product_category_name       VARCHAR(100),
    product_name_lenght         INT,
    product_description_lenght  INT,
    product_photos_qty          INT,
    product_weight_g            NUMERIC,
    product_length_cm           NUMERIC,
    product_height_cm           NUMERIC,
    product_width_cm            NUMERIC
);

-- 4. PRODUCT CATEGORY NAME TRANSLATION
DROP TABLE IF EXISTS product_category_name_translation CASCADE;
CREATE TABLE product_category_name_translation (
    product_category_name          VARCHAR(100) PRIMARY KEY,
    product_category_name_english  VARCHAR(100)
);

-- 5. GEOLOCATION
DROP TABLE IF EXISTS olist_geolocation_dataset CASCADE;
CREATE TABLE olist_geolocation_dataset (
    geolocation_zip_code_prefix  VARCHAR(10),
    geolocation_lat              NUMERIC,
    geolocation_lng              NUMERIC,
    geolocation_city             VARCHAR(100),
    geolocation_state            VARCHAR(5)
);

-- 6. ORDERS (referensi ke customers)
DROP TABLE IF EXISTS olist_orders_dataset CASCADE;
CREATE TABLE olist_orders_dataset (
    order_id                        VARCHAR(50) PRIMARY KEY,
    customer_id                     VARCHAR(50) REFERENCES olist_customers_dataset(customer_id),
    order_status                    VARCHAR(20),
    order_purchase_timestamp        TIMESTAMP,
    order_approved_at               TIMESTAMP,
    order_delivered_carrier_date    TIMESTAMP,
    order_delivered_customer_date   TIMESTAMP,
    order_estimated_delivery_date   TIMESTAMP
);

-- 7. ORDER ITEMS (referensi ke orders, products, sellers)
DROP TABLE IF EXISTS olist_order_items_dataset CASCADE;
CREATE TABLE olist_order_items_dataset (
    order_id              VARCHAR(50) REFERENCES olist_orders_dataset(order_id),
    order_item_id         INT,
    product_id            VARCHAR(50) REFERENCES olist_products_dataset(product_id),
    seller_id             VARCHAR(50) REFERENCES olist_sellers_dataset(seller_id),
    shipping_limit_date   TIMESTAMP,
    price                 NUMERIC(10,2),
    freight_value         NUMERIC(10,2),
    PRIMARY KEY (order_id, order_item_id)
);

-- 8. ORDER PAYMENTS (referensi ke orders)
DROP TABLE IF EXISTS olist_order_payments_dataset CASCADE;
CREATE TABLE olist_order_payments_dataset (
    order_id               VARCHAR(50) REFERENCES olist_orders_dataset(order_id),
    payment_sequential     INT,
    payment_type           VARCHAR(30),
    payment_installments   INT,
    payment_value          NUMERIC(10,2),
    PRIMARY KEY (order_id, payment_sequential)
);

-- 9. ORDER REVIEWS (referensi ke orders)
DROP TABLE IF EXISTS olist_order_reviews_dataset CASCADE;
CREATE TABLE olist_order_reviews_dataset (
    review_id                 VARCHAR(50),
    order_id                  VARCHAR(50) REFERENCES olist_orders_dataset(order_id),
    review_score              INT,
    review_comment_title      TEXT,
    review_comment_message    TEXT,
    review_creation_date      TIMESTAMP,
    review_answer_timestamp   TIMESTAMP,
    PRIMARY KEY (review_id, order_id)
);


-- ============================================================
-- BAGIAN 2 -- IMPORT CSV
-- Urutan WAJIB mengikuti urutan CREATE TABLE di atas
-- (tabel yang direferensikan harus terisi lebih dulu)
-- Ganti path folder di bawah jika lokasi file CSV berubah.
-- ============================================================

COPY olist_customers_dataset
FROM 'D:/olist-bi-dashboard/data/raw/olist_customers_dataset.csv'
DELIMITER ',' CSV HEADER;

COPY olist_sellers_dataset
FROM 'D:/olist-bi-dashboard/data/raw/olist_sellers_dataset.csv'
DELIMITER ',' CSV HEADER;

COPY olist_products_dataset
FROM 'D:/olist-bi-dashboard/data/raw/olist_products_dataset.csv'
DELIMITER ',' CSV HEADER;

COPY product_category_name_translation
FROM 'D:/olist-bi-dashboard/data/raw/product_category_name_translation.csv'
DELIMITER ',' CSV HEADER;

COPY olist_geolocation_dataset
FROM 'D:/olist-bi-dashboard/data/raw/olist_geolocation_dataset.csv'
DELIMITER ',' CSV HEADER;

COPY olist_orders_dataset
FROM 'D:/olist-bi-dashboard/data/raw/olist_orders_dataset.csv'
DELIMITER ',' CSV HEADER;

COPY olist_order_items_dataset
FROM 'D:/olist-bi-dashboard/data/raw/olist_order_items_dataset.csv'
DELIMITER ',' CSV HEADER;

COPY olist_order_payments_dataset
FROM 'D:/olist-bi-dashboard/data/raw/olist_order_payments_dataset.csv'
DELIMITER ',' CSV HEADER;

COPY olist_order_reviews_dataset
FROM 'D:/olist-bi-dashboard/data/raw/olist_order_reviews_dataset.csv'
DELIMITER ',' CSV HEADER;


-- ============================================================
-- BAGIAN 3 -- VERIFIKASI
-- Pastikan semua tabel terisi (angka tidak boleh 0)
-- ============================================================

SELECT 'customers' AS tabel, COUNT(*) FROM olist_customers_dataset
UNION ALL SELECT 'sellers', COUNT(*) FROM olist_sellers_dataset
UNION ALL SELECT 'products', COUNT(*) FROM olist_products_dataset
UNION ALL SELECT 'category_translation', COUNT(*) FROM product_category_name_translation
UNION ALL SELECT 'geolocation', COUNT(*) FROM olist_geolocation_dataset
UNION ALL SELECT 'orders', COUNT(*) FROM olist_orders_dataset
UNION ALL SELECT 'order_items', COUNT(*) FROM olist_order_items_dataset
UNION ALL SELECT 'payments', COUNT(*) FROM olist_order_payments_dataset
UNION ALL SELECT 'reviews', COUNT(*) FROM olist_order_reviews_dataset;

-- ============================================================
-- Selesai. Lanjut ke sql/02_star_schema.sql
-- ============================================================
