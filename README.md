# Clinical Trials Data Platform

ClinicalTrials.gov 공개 registry 데이터를 대상으로 구축한 Cloud Data Engineering 프로젝트입니다.

ClinicalTrials.gov API의 nested JSON 데이터를 수집하여 Databricks / Apache Spark / Delta Lake 기반으로 변환·품질관리하고, 분석용 Gold dataset은 BigQuery로 적재하며, 애플리케이션용 Study Search / Detail dataset을 별도의 Serving Layer로 제공합니다.

---

## Architecture

```text
ClinicalTrials.gov API
        │
        ▼
Raw JSON Archive (.json.gz)
        │
        ▼
Bronze - Delta Lake
        │
        ▼
Silver
├── Studies
├── Conditions
├── Interventions
├── Outcomes
└── Locations
        │
        ├───────────────┐
        ▼               ▼
 Data Quality          Gold
                        │
                  ┌─────┴─────┐
                  ▼           ▼
              BigQuery     Serving
                  │           │
                  ▼           ▼
             Analytics     CRA-RBM
             Dashboard     Assistant
```

---

## Data Scale

Full load 기준 데이터 규모입니다.

| Dataset | Rows |
| --- | ---: |
| Bronze Studies | 604,566 |
| Silver Studies | 604,566 |
| Silver Conditions | 1,087,211 |
| Silver Interventions | 1,022,647 |
| Silver Outcomes | 3,567,302 |
| Silver Locations | 3,532,550 |
| Gold Yearly Summary | 2,306 |
| Gold Country Summary | 4,712 |
| Gold Condition Trends | 378,261 |
| Serving Study Search | 604,566 |
| Serving Study Detail | 604,566 |

ClinicalTrials.gov 전체 공개 registry 약 60.5만 건을 수집하고, nested entities를 분리하여 약 981만 건 규모의 Silver dataset으로 변환했습니다.

---

## Pipeline

### 1. Full Ingestion

ClinicalTrials.gov API를 pagination 방식으로 수집합니다.

- Page size: 1,000
- Full registry: 604,566 studies
- Approximately 605 API pages
- Raw JSON estimate: ~10.6 GB
- gzip archive estimate: ~2 GB
- Page-level checkpoint for resumable ingestion

Raw API responses are archived before transformation.

### 2. Bronze

Raw study JSON을 최대한 원본 구조 그대로 보존하는 Delta table입니다.

```text
clinical_trials.bronze_studies
```

Source structure를 유지하여 향후 schema 변경이나 재처리가 필요한 경우 raw data에서 다시 변환할 수 있도록 구성했습니다.

### 3. Silver

Nested ClinicalTrials.gov JSON을 분석 및 재사용 가능한 entity 단위로 정규화합니다.

```text
silver_studies
silver_conditions
silver_interventions
silver_outcomes
silver_locations
```

Study 기준 grain은 `1 NCT ID = 1 row`로 유지하며, 1:N 관계의 nested arrays는 별도 dataset으로 분리합니다.

### 4. Data Quality

Pipeline run마다 데이터 품질 검사를 수행하고 결과를 Delta table에 누적합니다.

Current rules include:

- NCT ID not null
- NCT ID uniqueness
- Enrollment non-negative
- Completion date >= Start date
- Condition → Study referential integrity
- Intervention → Study referential integrity
- Outcome → Study referential integrity
- Location → Study referential integrity
- Latitude valid range
- Longitude valid range

Latest full-load run:

```text
10 rules
failed rows: 0
```

`0 violations`는 현재 정의된 규칙에서 위반이 발견되지 않았다는 의미이며, source data 전체의 완전성을 의미하지는 않습니다.

### 5. Incremental Ingestion

Full baseline 이후에는 `LastUpdatePostDate`를 기준으로 incremental ingestion을 수행합니다.

```text
Watermark
   ↓
ClinicalTrials.gov incremental API query
   ↓
Schema alignment
   ↓
NCT ID validation
   ↓
Delta MERGE
```

Implemented features:

- Watermark-based incremental ingestion
- NCT ID based UPSERT
- Hash-based change detection
- Idempotent batch processing
- Source duplicate validation
- Raw incremental archive
- Run-level lineage

동일한 batch를 다시 실행했을 때 신규 row가 추가되지 않고, 내용이 동일한 matched record의 update 또한 수행되지 않도록 구성했습니다.

### 6. Gold Analytics

분석 및 Dashboard 사용을 위한 aggregate datasets입니다.

```text
gold_yearly_summary
gold_country_summary
gold_condition_trends
```

Gold datasets are exported to Google BigQuery.

Databricks source row count와 BigQuery target row count를 비교하여 export 결과를 검증합니다.

### 7. Serving Layer

Analytics용 Gold와 Application용 Serving dataset을 분리했습니다.

```text
serving_study_search
serving_study_detail
```

`serving_study_search`는 Study 검색에 필요한 필드를 제공하고, `serving_study_detail`은 Condition, Intervention, Outcome, Location 등을 Study 단위 nested structure로 제공합니다.

---

## Workflow

Recurring Databricks workflow:

```text
incremental-ingestion
        ↓
silver-core
        ↓
silver-nested
        ↓
data-quality
        ↓
gold-analytics
       /       \
      ▼         ▼
serving-layer  bigquery-export
```

Full load는 recurring workflow와 별도로 수행하며, 초기 baseline 구축 또는 전체 재구축 시 사용합니다.

---

## Analytics Application

BigQuery Gold datasets are consumed through a FastAPI backend.

```text
BigQuery
   ↓
FastAPI
   ↓
Next.js
```

Current analytics APIs:

```text
GET /api/analytics/overview
GET /api/analytics/yearly
GET /api/analytics/countries
GET /api/analytics/conditions
```

Dashboard currently provides:

- Trial overview
- Trials by start year
- Trials by country
- Condition trend analysis

---

## Tech Stack

### Data Engineering

- Apache Spark
- PySpark
- Databricks
- Delta Lake
- Lakeflow Jobs
- Google BigQuery

### Application

- FastAPI
- Next.js
- TypeScript
- React Query
- Recharts

---

## Repository Structure

```text
.
├── notebooks/
│   ├── 01_bronze_ingestion
│   ├── 02_silver_transformation
│   ├── 03_silver_nested_entities
│   ├── 04_data_quality
│   ├── 05_gold_analytics
│   ├── 06_paginated_ingestion
│   ├── 07_incremental_merge
│   ├── 08_watermark_control
│   ├── 09_bigquery_export
│   ├── 10_serving_layer
│   └── 11_full_load
│
├── dbt/        # planned
├── docs/
└── README.md
```

---

## Next Steps

- [ ] Add dbt models and tests on BigQuery
- [ ] Connect CRA-RBM Study Search to Serving Layer
- [ ] Connect CRA-RBM Study Detail to Serving Layer
- [ ] Add `searchStudies` tool to CRA Assistant Agent
- [ ] Add `getStudyDetail` tool to CRA Assistant Agent
- [ ] Add architecture documentation and screenshots

---

## Notes

This project is a portfolio and learning project built with public ClinicalTrials.gov data.

Credentials, service-account keys, raw datasets, and environment files are not included in this repository.
