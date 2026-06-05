# Netflix Analysis: Modern Data Stack (dbt & Snowflake)

An end-to-end Modern Data Stack (MDS) implementation featuring an ELT data transformation pipeline. This repository defines a **dbt (data build tool)** project configured to work with a **Snowflake** cloud data warehouse, transforming raw Netflix/MovieLens dataset tables into a structured dimensional schema and an analytical data mart.

---

## 🏗️ Architecture & Data Flow

The project leverages a medallion-style multi-layered modeling structure to systematically clean, transform, and model data.

```mermaid
graph TD
    %% Source Raw Data
    subgraph Snowflake Raw Schema [1. Raw Data Layer]
        RAW_MOVIES[(RAW_MOVIES)]
        RAW_RATINGS[(RAW_RATINGS)]
        RAW_TAGS[(RAW_TAGS/Seeds)]
    end

    %% dbt Staging Layer
    subgraph dbt Staging Layer [2. Staging Layer]
        src_movies[src_movies.sql]
        src_ratings[src_ratings.sql]
        src_tags[src_tags.sql]
        
        RAW_MOVIES --> src_movies
        RAW_RATINGS --> src_ratings
        RAW_TAGS --> src_tags
    end

    %% Dimensional Modeling Layer
    subgraph dbt Core Models [3. Dimensions & Facts]
        dim_movies[dim_movies.sql]
        dim_users[dim_users.sql]
        fct_rating[fct_rating.sql <br/>⚡ Incremental]
        
        src_movies --> dim_movies
        src_ratings --> dim_users
        src_tags --> dim_users
        
        src_ratings --> fct_rating
    end

    %% Marts Layer
    subgraph dbt Presentation Layer [4. Analytical Marts]
        seed_dates[seed_movie_release_dates.csv]
        mart_movie_releases[mart_movie_releases.sql]
        
        fct_rating --> mart_movie_releases
        seed_dates --> mart_movie_releases
    end

    %% Visual Styling
    classDef raw fill:#2C3E50,stroke:#34495E,stroke-width:2px,color:#ECF0F1;
    classDef stage fill:#2980B9,stroke:#3498DB,stroke-width:2px,color:#fff;
    classDef core fill:#8E44AD,stroke:#9B59B6,stroke-width:2px,color:#fff;
    classDef mart fill:#27AE60,stroke:#2ECC71,stroke-width:2px,color:#fff;
    
    class RAW_MOVIES,RAW_RATINGS,RAW_TAGS raw;
    class src_movies,src_ratings,src_tags stage;
    class dim_movies,dim_users,fct_rating core;
    class mart_movie_releases mart;
```

---

## 🗂️ Data Modeling & Directory Structure

The dbt project is organized into structured modules representing different modeling layers:

### 1. Sources & Staging (`models/staging/`)
Staging models perform initial cleansing, casting, and renaming of source fields directly from the Snowflake `raw` schema.
*   **`src_movies.sql`**: Projects movie records (`movieId` mapped to `movie_id`, `title`, and pipe-delimited raw `genres`).
*   **`src_ratings.sql`**: Renames rating entities and converts raw epochs or string timestamps into Snowflake timestamp format (`TO_TIMESTAMP_LTZ`).

### 2. Dimension Tables (`models/dim/`)
Dimensions describe business entities.
*   **`dim_movies.sql`**: Standardizes movie titles (applying `INITCAP` and `TRIM`) and splits the pipe-delimited `genres` string into structured arrays (`SPLIT(genres, '|')`) for native query performance.
*   **`dim_users.sql`**: Consolidates and deduplicates a master set of users compiled from user interactions across rating and tagging tables.

### 3. Fact Tables (`models/fct/`)
Fact tables contain quantitative/transactional measurements.
*   **`fct_rating.sql`**: Materialized **incrementally** (`materialized='incremental'`) to optimize processing costs, tracking historical reviews/ratings left by users on movies.

### 4. Marts & Analytics (`models/mart/`)
The reporting layer built for business intelligence consumption.
*   **`mart_movie_releases.sql`**: Combines user rating histories with movie release dates (imported via seed files) to classify ratings relative to release milestones or evaluate user engagement trends over time.

---

## 🛠️ Snowflake Integration & Setup

To replicate this environment in your own Snowflake warehouse, follow this setup guide:

### 1. Database Setup
Execute the following statements in your Snowflake worksheet to initialize databases, schemas, and schemas for dbt target runs:

```sql
-- Create the main project database
CREATE DATABASE IF NOT EXISTS NETFLIX;

-- Create schemas for raw data ingestion and dbt outputs
CREATE SCHEMA IF NOT EXISTS NETFLIX.RAW;
CREATE SCHEMA IF NOT EXISTS NETFLIX.DEV;
```

### 2. Load Raw Source Tables
Load your dataset files (such as MovieLens movie metadata and ratings CSVs) into the `NETFLIX.RAW` schema as `RAW_MOVIES` and `RAW_RATINGS`.

---

## 🚀 Setting Up the dbt Project

Ensure you have dbt installed locally or run it via a virtual environment.

### 1. dbt Profile configuration (`profiles.yml`)
Set up your connection profile in `~/.dbt/profiles.yml`:

```yaml
netflix:
  target: dev
  outputs:
    dev:
      type: snowflake
      account: <your_snowflake_account_identifier>
      user: <your_username>
      password: <your_password>
      role: <your_role> # e.g. ACCOUNTADMIN or SYSADMIN
      warehouse: <your_warehouse> # e.g. COMPUTE_WH
      database: NETFLIX
      schema: DEV
      threads: 4
```

### 2. Run dbt Commands
Navigate to the `netflix/` project directory and execute the following commands:

```bash
# Verify connection to Snowflake
dbt debug

# Install dependencies if any are declared
dbt deps

# Load seed data (e.g. seed_movie_release_dates.csv)
dbt seed

# Run the transformation pipeline
dbt run

# Perform schema-level assertions and data validation tests
dbt test
```

---

## 📐 Data Integrity & Tests
Data validation rules are declared in `models/schema.yml`. Key assertions include:
*   **`not_null`** checks on entity keys (e.g., `movie_id`, `movie_title`).
*   **`unique`** constraints mapping relationships between business keys and dimensions.
