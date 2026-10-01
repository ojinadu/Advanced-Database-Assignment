# Harmetage Private School: ER diagram

GitHub renders this diagram automatically. For the LMS document, paste the code block into https://mermaid.live and export it as PNG.

```mermaid
erDiagram
    ACADEMIC_SESSION ||--|{ TERM : "is divided into"
    ACADEMIC_SESSION ||--o{ CLASS_ARM : "runs"
    CLASS_LEVEL ||--o{ CLASS_ARM : "is split into"
    CLASS_ARM }o--o| STAFF : "has form teacher"

    CLASS_ARM ||--o{ SUBJECT_ALLOCATION : "offers"
    SUBJECT ||--o{ SUBJECT_ALLOCATION : "is taught as"
    STAFF ||--o{ SUBJECT_ALLOCATION : "teaches"

    STUDENT ||--o{ ENROLMENT : "is placed through"
    CLASS_ARM ||--o{ ENROLMENT : "contains"

    STUDENT ||--o{ STUDENT_GUARDIAN : "has"
    GUARDIAN ||--o{ STUDENT_GUARDIAN : "is responsible for"

    ENROLMENT ||--o{ SCORE : "earns"
    SUBJECT_ALLOCATION ||--o{ SCORE : "is assessed by"
    TERM ||--o{ SCORE : "is recorded in"

    ENROLMENT ||--o{ ATTENDANCE : "logs"

    CLASS_LEVEL ||--o{ FEE_SCHEDULE : "is billed"
    TERM ||--o{ FEE_SCHEDULE : "applies in"
    FEE_ITEM ||--o{ FEE_SCHEDULE : "is priced in"

    STUDENT ||--o{ PAYMENT : "makes"
    TERM ||--o{ PAYMENT : "is paid for"
    STAFF |o--o{ PAYMENT : "receives"

    ACADEMIC_SESSION {
        smallint session_id PK
        varchar name UK "e.g. 2025/2026"
        date start_date
        date end_date
    }
    TERM {
        smallint term_id PK
        smallint session_id FK
        smallint term_no "1 to 3, unique per session"
        date start_date
        date end_date
    }
    CLASS_LEVEL {
        smallint level_id PK
        varchar code UK "JSS1 to SS3"
        varchar name
        varchar stage "JUNIOR or SENIOR"
        smallint sort_order UK
    }
    CLASS_ARM {
        integer class_arm_id PK
        smallint level_id FK
        smallint session_id FK
        char arm "A to F"
        integer form_teacher_id FK
        smallint capacity
    }
    SUBJECT {
        smallint subject_id PK
        varchar code UK
        varchar name UK
        varchar stage "JUNIOR, SENIOR or BOTH"
    }
    SUBJECT_ALLOCATION {
        integer allocation_id PK
        integer class_arm_id FK
        smallint subject_id FK
        integer teacher_id FK
    }
    STAFF {
        integer staff_id PK
        varchar staff_no UK
        varchar first_name
        varchar last_name
        varchar role "TEACHER, ADMIN, BURSAR, PRINCIPAL"
        varchar email UK
        date hire_date
        boolean is_active
    }
    STUDENT {
        integer student_id PK
        varchar admission_no UK
        varchar first_name
        varchar last_name
        date date_of_birth
        char gender
        date admission_date
        varchar status
    }
    GUARDIAN {
        integer guardian_id PK
        varchar first_name
        varchar last_name
        varchar phone UK
        varchar email UK
        text address
    }
    STUDENT_GUARDIAN {
        integer student_id PK, FK
        integer guardian_id PK, FK
        varchar relationship
        boolean is_primary "one primary per student"
    }
    ENROLMENT {
        integer enrolment_id PK
        integer student_id FK
        integer class_arm_id FK
        smallint session_id FK "must match class arm"
        date enrolled_on
    }
    SCORE {
        integer enrolment_id PK, FK
        smallint term_id PK, FK
        integer allocation_id PK, FK
        numeric ca1 "0 to 20"
        numeric ca2 "0 to 20"
        numeric exam "0 to 60"
        numeric total "generated"
        integer recorded_by FK
    }
    ATTENDANCE {
        integer enrolment_id PK, FK
        date attendance_date PK "weekdays only"
        varchar status
        integer recorded_by FK
    }
    FEE_ITEM {
        smallint fee_item_id PK
        varchar name UK
    }
    FEE_SCHEDULE {
        smallint level_id PK, FK
        smallint term_id PK, FK
        smallint fee_item_id PK, FK
        numeric amount
    }
    PAYMENT {
        bigint payment_id PK
        integer student_id FK
        smallint term_id FK
        numeric amount
        varchar method
        varchar reference UK
        timestamptz paid_at
        integer received_by FK
    }
    GRADE_SCALE {
        varchar grade PK
        numrange band "non-overlapping"
        varchar remark
    }
```

`GRADE_SCALE` has no foreign key relationships. Scores are matched to grades by range lookup (`score.total <@ grade_scale.band`), not by a stored grade, so it appears on its own.
