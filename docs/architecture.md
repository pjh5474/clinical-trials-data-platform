# Architecture

## 1. System Overview

전체 시스템 구조

ClinicalTrials.gov
→ Databricks
→ Delta Lake
→ Silver / Quality / Gold
→ BigQuery / Serving
→ CRA-RBM
→ CRA Assistant Agent

## 2. Design Goals

- 전체 ClinicalTrials.gov registry 수집
- 재처리 가능한 Raw 보존
- nested JSON의 분석 가능한 구조화
- full load + incremental ingestion 분리
- idempotent pipeline
- Analytics와 Application Serving 분리
- downstream application / agent에서 재사용 가능한 데이터 제공

## 3. Data Flow

### Full Load

API Pagination
→ gzip Raw Archive
→ Bronze
→ Silver
→ Quality
→ Gold / Serving

### Incremental Load

Watermark
→ LastUpdatePostDate API Query
→ Schema Alignment
→ Duplicate Validation
→ Hash Comparison
→ Delta MERGE
→ Watermark Update

## 4. Data Layers

### Raw
왜 JSON.gz로 보존하는지

### Bronze
source 구조를 최대한 유지하는 이유

### Silver
Study / Condition / Intervention / Outcome / Location으로 나눈 이유

### Gold
analytics용 집계 데이터

### Serving
application query에 맞는 구조

## 5. Data Grain

예:

silver_studies
- 1 row = 1 NCT ID

silver_conditions
- 1 row = 1 Study-Condition relation

silver_interventions
- 1 row = 1 Study-Intervention

...

왜 grain을 명시했는지 설명

## 6. Incremental & Idempotency

- NCT ID UPSERT
- Watermark
- same-day overlap
- hash-based change detection
- duplicate source validation
- 동일 batch 재실행 시 결과가 변하지 않는 구조

## 7. Data Quality

10개 QC rule
run_id
quality_results history
referential integrity

## 8. Analytics Architecture

Gold
→ BigQuery
→ FastAPI
→ Next.js Dashboard

왜 BigQuery를 Analytics consumption layer로 사용했는지

## 9. Application Serving Architecture

Serving
→ FastAPI
→ CRA-RBM Study Search / Detail

왜 Gold와 Serving을 분리했는지

## 10. Agent Integration

CRA Assistant Agent
→ searchStudies()
→ getStudyDetail()
→ analytics tools

Structured data는 SQL/API tool,
규정/문서 같은 unstructured data는 별도 RAG

## 11. Security / Secrets

- Databricks Secret Scope
- GCP Service Account
- Render environment variables
- credentials Git 제외

## 12. Trade-offs & Limitations

예:
- batch 기반이며 real-time streaming 아님
- BigQuery Gold는 current snapshot 방식
- ClinicalTrials.gov schema 변경 가능성
- Free/portfolio environment 기반
- production HA/DR까지 구현하지 않음

## 13. Future Improvements

- dbt modeling/tests
- CI/CD
- observability
- cost monitoring
- richer serving API
