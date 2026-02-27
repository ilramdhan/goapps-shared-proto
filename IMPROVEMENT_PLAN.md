# Improvement Plan: goapps-shared-proto

> **Berdasarkan**: ANALYSIS.md (Deep Research Report)  
> **Tujuan**: Membawa repository ke standar production-grade, scalable, sustainable, secure, dan industrial-grade  
> **Filosofi**: Fix bugs first → Consolidate common types → Harden security → Add missing patterns → Improve CI/CD → Expand domain

---

## Daftar Isi

1. [Ringkasan Prioritas](#1-ringkasan-prioritas)
2. [FASE 1: Critical Fixes (Segera)](#2-fase-1-critical-fixes-segera)
3. [FASE 2: Structural Improvements (Sprint 1-2)](#3-fase-2-structural-improvements-sprint-1-2)
4. [FASE 3: Security & Validation Hardening (Sprint 2-3)](#4-fase-3-security--validation-hardening-sprint-2-3)
5. [FASE 4: Scalability & Best Practices (Sprint 3-4)](#5-fase-4-scalability--best-practices-sprint-3-4)
6. [FASE 5: CI/CD & Tooling Improvements (Sprint 4-5)](#6-fase-5-cicd--tooling-improvements-sprint-4-5)
7. [FASE 6: Documentation Sync (Ongoing)](#7-fase-6-documentation-sync-ongoing)
8. [FASE 7: Domain Expansion (Long Term)](#8-fase-7-domain-expansion-long-term)
9. [Breaking Change Considerations](#9-breaking-change-considerations)
10. [Recommended Code Changes](#10-recommended-code-changes)
11. [Architecture Recommendations](#11-architecture-recommendations)
12. [Production-Grade Checklist](#12-production-grade-checklist)

---

## 1. Ringkasan Prioritas

| Fase | Scope | Effort | Impact | Timeline |
|------|-------|--------|--------|----------|
| **FASE 1** | Critical Bugs Fix | Rendah | Sangat Tinggi | Hari ini |
| **FASE 2** | Structural (common.proto reorg) | Sedang | Tinggi | Sprint 1-2 |
| **FASE 3** | Security & Validation | Sedang | Tinggi | Sprint 2-3 |
| **FASE 4** | Scalability Patterns | Tinggi | Sedang | Sprint 3-4 |
| **FASE 5** | CI/CD Improvements | Sedang | Tinggi | Sprint 4-5 |
| **FASE 6** | Documentation Sync | Rendah | Sedang | Ongoing |
| **FASE 7** | Domain Expansion | Sangat Tinggi | Sangat Tinggi | Long term |

---

## 2. FASE 1: Critical Fixes (Segera)

Semua perbaikan di FASE 1 adalah **non-breaking** (tidak mengubah field numbers atau tipe). Harus diselesaikan sebelum repository digunakan secara luas.

---

### FIX-1.1: Perbaiki Permission Code Regex (BUG AKTIF)

**File**: `iam/v1/role.proto`  
**Masalah**: Regex memaksa 4 segment tapi contoh di comment adalah 3 segment  
**Impact**: Developer yang mengikuti contoh `iam.user.create` akan mendapat validation error  

**Pilihan solusi** (pilih salah satu dan konsistenkan):

**Opsi A: Buat regex flexibel 3-4 segment** (Direkomendasikan)
```protobuf
// Sebelum:
// Permission code format: {service}.{module}.{entity}.{action}
// e.g., finance.master.uom.view, iam.user.create
string permission_code = 1 [(buf.validate.field).string = {
  min_len: 3
  max_len: 100
  pattern: "^[a-z][a-z0-9]*\\.[a-z][a-z0-9]*\\.[a-z][a-z0-9]*\\.[a-z]+$"
}];

// Sesudah (Opsi A) — 3 atau 4 segment:
// Permission code format: {service}.{module}.{action} atau {service}.{module}.{entity}.{action}
// Examples:
//   3-segment: iam.user.create, iam.role.delete
//   4-segment: finance.master.uom.view, finance.master.uom.create
string permission_code = 1 [(buf.validate.field).string = {
  min_len: 3
  max_len: 100
  pattern: "^[a-z][a-z0-9]*(\\.[a-z][a-z0-9]*){2,3}$"
}];
```

**Opsi B: Enforce 4-segment dan update semua contoh**
```protobuf
// Sesudah (Opsi B) — strict 4 segment:
// Permission code format: {service}.{module}.{entity}.{action}
// Examples: finance.master.uom.view, iam.admin.user.create, iam.admin.role.delete
string permission_code = 1 [(buf.validate.field).string = {
  min_len: 3
  max_len: 100
  pattern: "^[a-z][a-z0-9]*\\.[a-z][a-z0-9]*\\.[a-z][a-z0-9]*\\.[a-z]+$"
}];
// NOTE: Jika pilih ini, semua permission data di database juga harus diupdate
```

> **Rekomendasi**: Pilih **Opsi A** untuk fleksibilitas. Format `{service}.{module}.{action}` lebih natural untuk action yang tidak perlu entity level (e.g., `iam.session.revoke`).

---

### FIX-1.2: Tambahkan Email Validation ke `VerifyResetOTPRequest`

**File**: `iam/v1/auth.proto`  
**Masalah**: `VerifyResetOTPRequest.email` tidak ada format validation, inkonsisten dengan `ForgotPasswordRequest.email`  

```protobuf
// Sebelum:
message VerifyResetOTPRequest {
  string email = 1 [(buf.validate.field).string = {
    min_len: 1
    max_len: 255
    // TIDAK ADA pattern validation
  }];
  string otp_code = 2 [(buf.validate.field).string = {
    len: 6
    pattern: "^[0-9]{6}$"
  }];
}

// Sesudah:
message VerifyResetOTPRequest {
  // Email address (must match format used in ForgotPassword).
  string email = 1 [(buf.validate.field).string = {
    min_len: 1
    max_len: 255
    pattern: "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"
  }];
  string otp_code = 2 [(buf.validate.field).string = {
    len: 6
    pattern: "^[0-9]{6}$"
  }];
}
```

> **Catatan**: Ini non-breaking change — menambah constraint pada field yang ada. Namun secara teknis, protovalidate constraint yang lebih ketat bisa menyebabkan existing client yang kirim invalid email tidak lolos. Karena ini security flow, ini **acceptable**.

---

### FIX-1.3: Tambahkan `file_name` Pattern Validation ke Semua `Import*Request`

**Files yang terdampak** (8 files):
- `iam/v1/user.proto` → `ImportUsersRequest`
- `iam/v1/role.proto` → `ImportRolesRequest`, `ImportPermissionsRequest`
- `iam/v1/organization.proto` → `ImportCompaniesRequest`, `ImportDivisionsRequest`, `ImportDepartmentsRequest`, `ImportSectionsRequest`
- `iam/v1/menu.proto` → `ImportMenusRequest`

**Perubahan yang sama untuk semua**:
```protobuf
// Sebelum (contoh di ImportRolesRequest):
string file_name = 2 [(buf.validate.field).string = {
  min_len: 1
  max_len: 255
  // TIDAK ADA pattern
}];

// Sesudah:
// Original filename (must be xlsx or xls without path separators).
string file_name = 2 [(buf.validate.field).string = {
  min_len: 1
  max_len: 255
  pattern: "^[^/\\\\]+\\.(xlsx|xls)$"
}];
```

---

### FIX-1.4: Tambahkan UUID Validation per-item pada `role_ids` di `CreateUserRequest`

**File**: `iam/v1/user.proto`  
**Masalah**: `repeated string role_ids = 13` tidak divalidasi sebagai UUID per item  

```protobuf
// Sebelum:
// Initial role IDs to assign.
repeated string role_ids = 13;

// Sesudah:
// Initial role IDs to assign (must be valid UUIDs).
repeated string role_ids = 13 [(buf.validate.field).repeated.items.string.uuid = true];
```

> **Perhatian**: Ini bisa menjadi breaking change untuk existing client yang mengirim non-UUID di `role_ids`. Namun karena ini security-critical field, pengetatan ini direkomendasikan.

---

## 3. FASE 2: Structural Improvements (Sprint 1-2)

Perubahan struktural yang memerlukan koordinasi antar file karena menyentuh definisi types yang digunakan banyak tempat.

---

### STRUCT-2.1: Konsolidasi `ActiveFilter` dan `ImportError` ke `common.proto`

**Masalah**: Duplikasi definisi di 2 package  
**Impact jika tidak diperbaiki**: Divergence overtime, coupling yang tidak perlu antar file  

**Langkah implementasi**:

**Step 1**: Tambahkan ke `common/v1/common.proto`:
```protobuf
// ActiveFilter represents filter options for is_active field.
// Used in all List and Export requests across all services.
enum ActiveFilter {
  // Show all records regardless of active status (default/no filter).
  ACTIVE_FILTER_UNSPECIFIED = 0;
  // Show only active records.
  ACTIVE_FILTER_ACTIVE = 1;
  // Show only inactive records.
  ACTIVE_FILTER_INACTIVE = 2;
}

// ImportError represents a single row error during Excel import operations.
// Used in all Import*Response messages across all services.
message ImportError {
  // Row number in the Excel file (1-indexed).
  int32 row_number = 1;
  // Field name that caused the error.
  string field = 2;
  // Human-readable error message.
  string message = 3;
}

// ImportResult contains the summary of an Excel import operation.
// Use as the body for all Import*Response messages.
message ImportResult {
  // Number of successfully imported records.
  int32 success_count = 1;
  // Number of skipped records (duplicates with skip action).
  int32 skipped_count = 2;
  // Number of updated records (duplicates with update action).
  int32 updated_count = 3;
  // Number of failed records.
  int32 failed_count = 4;
  // Details of failed records.
  repeated ImportError errors = 5;
}
```

**Step 2**: Update `finance/v1/uom.proto`:
```protobuf
// Hapus definisi lokal:
// enum ActiveFilter { ... }     ← HAPUS
// message ImportError { ... }   ← HAPUS

// Ganti penggunaan di Import response:
// Sebelum:
message ImportUOMsResponse {
  common.v1.BaseResponse base = 1;
  int32 success_count = 2;
  int32 skipped_count = 3;
  int32 updated_count = 4;
  int32 failed_count = 5;
  repeated ImportError errors = 6;
}

// Sesudah (menggunakan common.v1.ImportResult):
message ImportUOMsResponse {
  common.v1.BaseResponse base = 1;
  common.v1.ImportResult result = 2;
}
```

> **Catatan Breaking Change**: Mengubah `ImportUOMsResponse` adalah **BREAKING CHANGE** pada field structure. Jika sudah ada consumer yang menggunakan field `success_count`, `skipped_count`, dll di field number 2-6, ini akan break. Pendekatan safer adalah **tidak** menggunakan `ImportResult` wrapper dan tetap flat, tapi menghapus duplikasi `ImportError` saja.

**Pendekatan SAFER (non-breaking)**:
```protobuf
// Tetap flat structure, tapi gunakan common.v1.ImportError:
message ImportUOMsResponse {
  common.v1.BaseResponse base = 1;
  int32 success_count = 2;   // Field numbers tetap sama
  int32 skipped_count = 3;
  int32 updated_count = 4;
  int32 failed_count = 5;
  repeated common.v1.ImportError errors = 6;  // Hanya ganti type reference
}
```

**Step 3**: Update semua file yang menggunakan lokal `ActiveFilter` dan `ImportError`:
- `iam/v1/user.proto`: Hapus definisi, ganti semua usage dengan `common.v1.ActiveFilter` dan `common.v1.ImportError`
- `iam/v1/role.proto`: Hapus import `user.proto` (tidak perlu lagi untuk `ActiveFilter`/`ImportError`), tambah import `common/v1/common.proto`
- `iam/v1/organization.proto`: Sama
- `iam/v1/menu.proto`: Sama

> **Perhatian**: Karena `ActiveFilter` saat ini ada di package `iam.v1` dan `finance.v1`, memindahkannya ke `common.v1` akan mengubah fully-qualified name dari `iam.v1.ActiveFilter` → `common.v1.ActiveFilter`. Ini adalah **BREAKING CHANGE untuk generated code** (Go, TypeScript). Koordinasi dengan tim backend dan frontend diperlukan.

---

### STRUCT-2.2: Pindahkan `Permission` Message ke `role.proto`

**Masalah**: `Permission` (basic message) didefinisikan di `user.proto` tapi domain aslinya adalah permission management (bukan user management). Akibatnya `role.proto`, `menu.proto`, `organization.proto` semua mengimpor `user.proto` hanya untuk `Permission`.  

**Langkah implementasi**:

**Step 1**: Tambahkan `Permission` ke `iam/v1/role.proto` (sudah ada `PermissionDetail`, tinggal tambah `Permission` juga)

**Step 2**: Update `user.proto` untuk import dari `role.proto` alih-alih mendefinisikan sendiri:
```protobuf
// iam/v1/user.proto — ganti import:
// Hapus definisi Permission dari user.proto
// Tambahkan:
import "iam/v1/role.proto";

// Gunakan Permission dari role.proto
```

**Step 3**: Update `menu.proto` dan `organization.proto` untuk import `role.proto` bukan `user.proto`

> **Catatan**: Ini bisa menimbulkan circular import jika tidak hati-hati. Evaluasi dependency graph sebelum implementasi.

**Alternatif yang lebih clean**: Buat `iam/v1/permission.proto` dedicated:
```protobuf
// iam/v1/permission.proto — NEW FILE
syntax = "proto3";
package iam.v1;

import "common/v1/common.proto";
import "buf/validate/validate.proto";

// Permission represents a single permission entity (lightweight view).
// Used in role assignment, user access info, and menu permissions.
message Permission {
  string permission_id = 1;
  string permission_code = 2;
  string permission_name = 3;
  string service_name = 4;
  string module_name = 5;
  string action_type = 6;
}
```

Kemudian:
- `user.proto` → import `permission.proto`
- `role.proto` → import `permission.proto`
- `menu.proto` → import `permission.proto`
- `organization.proto` → TIDAK perlu import permission sama sekali

---

### STRUCT-2.3: Update `PaginationRequest` agar Digunakan atau Hapus

**Opsi A: Aktifkan `PaginationRequest` di semua List requests** (Ideal tapi breaking)  
Ini adalah breaking change karena field structure berubah.

**Opsi B: Hapus `PaginationRequest` dari `common.proto`** (Clean, tapi juga breaking jika ada yang menggunakannya)  
Karena tidak ada yang menggunakannya sekarang, ini aman.

**Opsi C: Tambahkan komentar bahwa ini deprecated/intentionally tidak digunakan** (Safest)
```protobuf
// PaginationRequest contains pagination parameters for list requests.
// NOTE: This message is defined for potential reuse but current convention
// uses flat page/page_size fields in each List*Request message for
// compatibility with gRPC-Gateway query parameter mapping.
// See: https://grpc-ecosystem.github.io/grpc-gateway/docs/mapping/
message PaginationRequest {
  int32 page = 1;
  int32 page_size = 2;
}
```

> **Rekomendasi**: Pilih Opsi C untuk saat ini. Aktifkan secara bertahap saat ada service baru yang ditambahkan.

---

## 4. FASE 3: Security & Validation Hardening (Sprint 2-3)

---

### SEC-3.1: Standardisasi Email Validation — Gunakan `string.email = true`

**Masalah**: Saat ini menggunakan custom regex di beberapa tempat. Protovalidate memiliki built-in `email = true` yang lebih reliable (RFC 5322 compliant).

**Files terdampak**: `iam/v1/auth.proto`, `iam/v1/user.proto`

```protobuf
// Sebelum (custom regex):
string email = 1 [(buf.validate.field).string = {
  min_len: 1
  max_len: 255
  pattern: "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"
}];

// Sesudah (built-in email validation):
string email = 1 [(buf.validate.field).string = {
  max_len: 255
  email: true  // RFC 5322 compliant, lebih reliable dari custom regex
}];
```

> **Catatan**: `string.email = true` menggunakan UTA46 normalization. Pastikan backend dan frontend juga normalisasi email sebelum comparison.

---

### SEC-3.2: Tambahkan Timestamp Validation untuk Date Fields

**Files terdampak**: `iam/v1/audit.proto` (`date_from`, `date_to`), `iam/v1/user.proto` (`date_of_birth`)

```protobuf
// Sebelum — tidak ada validation:
string date_from = 8;
string date_to = 9;

// Sesudah — dengan ISO 8601 date pattern:
// Filter start date (ISO 8601 format: YYYY-MM-DD or YYYY-MM-DDTHH:MM:SSZ).
string date_from = 8 [(buf.validate.field).string = {
  max_len: 30
  pattern: "^\\d{4}-\\d{2}-\\d{2}(T\\d{2}:\\d{2}:\\d{2}(\\.\\d+)?(Z|[+-]\\d{2}:\\d{2})?)?$"
}];
string date_to = 9 [(buf.validate.field).string = {
  max_len: 30
  pattern: "^\\d{4}-\\d{2}-\\d{2}(T\\d{2}:\\d{2}:\\d{2}(\\.\\d+)?(Z|[+-]\\d{2}:\\d{2})?)?$"
}];
```

**Alternatif lebih clean**: Gunakan `google.protobuf.Timestamp` (lihat SEC-3.3).

---

### SEC-3.3: Pertimbangkan `google.protobuf.Timestamp` untuk Datetime Fields

**Masalah**: Semua datetime menggunakan `string`. Tidak ada type safety di proto level.

**Opsi**: Migrasi bertahap ke `google.protobuf.Timestamp` untuk field baru.

```protobuf
// Tambahkan import di file yang perlu:
import "google/protobuf/timestamp.proto";

// Contoh untuk AuditInfo di common.proto (BREAKING CHANGE — hati-hati):
// HANYA tambahkan fields baru, jangan ubah yang lama
message AuditInfo {
  string created_at = 1;    // Existing — pertahankan untuk compatibility
  string created_by = 2;
  string updated_at = 3;
  string updated_by = 4;
  // Future fields bisa pakai Timestamp:
  // google.protobuf.Timestamp created_ts = 5;  // v2 field
}

// Untuk fields BARU di messages baru, langsung pakai Timestamp:
message Session {
  // ...
  // Gunakan Timestamp untuk field baru:
  google.protobuf.Timestamp created_at_ts = 11;   // New field, tidak break existing
  google.protobuf.Timestamp expires_at_ts = 12;
}
```

> **Rekomendasi pendekatan pragmatis**: Tidak perlu migrasi masif sekarang. Cukup:
> 1. Tambahkan pattern validation untuk string datetime fields yang belum ada
> 2. Untuk service/message BARU, gunakan `google.protobuf.Timestamp`
> 3. Dokumentasikan bahwa semua existing `string` datetime adalah RFC 3339/ISO 8601

---

### SEC-3.4: Tambahkan `RevokeAllSessions` ke `SessionService`

**File**: `iam/v1/session.proto`  
**Justifikasi**: Security incident response membutuhkan kemampuan force logout semua session

```protobuf
// Di SessionService, tambahkan RPC baru:
service SessionService {
  // ... existing RPCs ...

  // RevokeAllSessions revokes all active sessions for a user (admin only).
  // Used for security incident response or forced account lockdown.
  rpc RevokeAllSessions(RevokeAllSessionsRequest) returns (RevokeAllSessionsResponse) {
    option (google.api.http) = {
      post: "/api/v1/iam/sessions/revoke-all"
      body: "*"
    };
  }
}

// Tambahkan messages:
// RevokeAllSessionsRequest revokes all sessions for a specific user or current user.
message RevokeAllSessionsRequest {
  // User ID to revoke all sessions (admin only; if empty, revokes current user's sessions).
  optional string user_id = 1 [(buf.validate.field).string.uuid = true];
  // Reason for revocation (for audit log).
  string reason = 2 [(buf.validate.field).string.max_len = 500];
}

// RevokeAllSessionsResponse confirms bulk revocation.
message RevokeAllSessionsResponse {
  common.v1.BaseResponse base = 1;
  // Number of sessions revoked.
  int32 revoked_count = 2;
}
```

---

### SEC-3.5: Tambahkan `OrganizationType` Enum untuk `OrganizationNode.type`

**File**: `iam/v1/organization.proto`  
**Masalah**: `string type = 4` tidak type-safe

```protobuf
// Tambahkan enum baru di organization.proto:
// OrganizationType represents the type of an organization hierarchy node.
enum OrganizationType {
  ORGANIZATION_TYPE_UNSPECIFIED = 0;
  ORGANIZATION_TYPE_COMPANY = 1;
  ORGANIZATION_TYPE_DIVISION = 2;
  ORGANIZATION_TYPE_DEPARTMENT = 3;
  ORGANIZATION_TYPE_SECTION = 4;
}

// Update OrganizationNode:
message OrganizationNode {
  string id = 1;
  string code = 2;
  string name = 3;
  // JANGAN ubah field 4 (string type) — itu breaking change
  // Tambah field baru:
  OrganizationType node_type = 7;  // Type-safe version of the string type field
  bool is_active = 5;
  repeated OrganizationNode children = 6;
  // Deprecated:
  // string type = 4 [deprecated = true]; // Keep for backward compat
}
```

> **Catatan**: Field `type` (field 4) tidak bisa diubah tanpa breaking. Tambahkan field `node_type` (field 7) sebagai typed version. Tandai `type` sebagai deprecated.

---

## 5. FASE 4: Scalability & Best Practices (Sprint 3-4)

---

### SCALE-4.1: Tambahkan `BulkDelete` Pattern untuk Semua Master Services

**Masalah**: Semua service hanya punya single-item delete. Untuk admin operations, sering butuh bulk delete.

**Template untuk semua service**:
```protobuf
// Tambahkan ke UOMService, UserService, RoleService, dll:

// BatchDeleteUOMs deletes multiple UOMs in a single request.
rpc BatchDeleteUOMs(BatchDeleteUOMsRequest) returns (BatchDeleteUOMsResponse) {
  option (google.api.http) = {
    post: "/api/v1/finance/uoms/batch-delete"
    body: "*"
  };
}

// BatchDeleteUOMsRequest deletes multiple UOMs by ID.
message BatchDeleteUOMsRequest {
  // UOM IDs to delete (min 1, max 100 per batch).
  repeated string uom_ids = 1 [(buf.validate.field).repeated = {
    min_items: 1
    max_items: 100
    items: {string: {uuid: true}}
  }];
}

// BatchDeleteUOMsResponse confirms batch deletion.
message BatchDeleteUOMsResponse {
  common.v1.BaseResponse base = 1;
  // Number of records deleted.
  int32 deleted_count = 2;
}
```

---

### SCALE-4.2: Ganti File Transfer `bytes` dengan Streaming atau URL Pattern

**Masalah**: Export/Import menggunakan `bytes` (seluruh file in-memory). Tidak scalable untuk file besar.

**Opsi A: Server Streaming RPC** (untuk export besar):
```protobuf
// Streaming export untuk file besar:
rpc StreamExportUOMs(ExportUOMsRequest) returns (stream ExportChunk) {}

message ExportChunk {
  // Chunk of bytes (streaming).
  bytes data = 1;
  // Whether this is the last chunk.
  bool is_last = 2;
  // Total file size in bytes (only in first chunk).
  int64 total_size = 3;
  // Suggested filename (only in first chunk).
  string file_name = 4;
}
```

**Opsi B: Pre-signed URL Pattern** (lebih cloud-friendly):
```protobuf
// Export generates a pre-signed download URL:
rpc ExportUOMs(ExportUOMsRequest) returns (ExportUOMsResponse) {}

message ExportUOMsResponse {
  common.v1.BaseResponse base = 1;
  // Pre-signed URL to download the export file (valid for 15 minutes).
  string download_url = 2;
  // URL expiry timestamp.
  string expires_at = 3;
  // Suggested filename.
  string file_name = 4;
}
```

> **Rekomendasi**: Untuk production dengan file potensially besar, **Opsi B (Pre-signed URL)** lebih scalable dan tidak membutuhkan perubahan proto yang besar. Implementasi di backend cukup upload ke S3/GCS dan return signed URL.

---

### SCALE-4.3: Tambahkan Cursor-Based Pagination sebagai Opsi

**Masalah**: Offset-based pagination (`page`, `page_size`) tidak efisien untuk tabel besar (N+1 problem di database).

**Tambahkan ke `common.proto`**:
```protobuf
// CursorPaginationRequest supports efficient cursor-based pagination for large datasets.
// Use this instead of PaginationRequest for high-volume endpoints.
message CursorPaginationRequest {
  // Number of items per page (1-100, default 20).
  int32 limit = 1 [(buf.validate.field).int32 = {gte: 1, lte: 100}];
  // Cursor from previous response (empty for first page).
  string cursor = 2 [(buf.validate.field).string.max_len = 500];
  // Sort direction: "asc" or "desc".
  string direction = 3 [(buf.validate.field).string = {in: ["", "asc", "desc"]}];
}

// CursorPaginationResponse contains cursor for next/previous page.
message CursorPaginationResponse {
  // Cursor for next page (empty if no more pages).
  string next_cursor = 1;
  // Cursor for previous page (empty if on first page).
  string prev_cursor = 2;
  // Whether there are more items after current page.
  bool has_next = 3;
  // Whether there are items before current page.
  bool has_prev = 4;
  // Total items count (optional, may be expensive to compute).
  optional int64 total_items = 5;
}
```

> **Rekomendasi**: Tidak perlu implementasi sekarang. Tambahkan ke `common.proto` sebagai foundation, gunakan di service baru yang high-volume (e.g., Audit Logs, Transaction records).

---

### SCALE-4.4: Tambahkan `GetAuditSummaryRequest.time_range` sebagai Enum

**File**: `iam/v1/audit.proto`  
**Masalah**: String dengan `in` constraint adalah anti-pattern untuk nilai yang sudah diketahui  

```protobuf
// Tambahkan enum baru:
// TimeRange represents predefined time ranges for summary queries.
enum TimeRange {
  TIME_RANGE_UNSPECIFIED = 0;
  TIME_RANGE_TODAY = 1;
  TIME_RANGE_WEEK = 2;
  TIME_RANGE_MONTH = 3;
  TIME_RANGE_YEAR = 4;
}

// Update GetAuditSummaryRequest:
message GetAuditSummaryRequest {
  // Time range for the summary.
  // DEPRECATED: Use time_range_enum instead.
  // string time_range = 1;  ← Keep for backward compat, mark deprecated
  
  // Time range for the summary (preferred).
  TimeRange time_range_enum = 3;
  // Filter by service name (optional).
  string service_name = 2 [(buf.validate.field).string.max_len = 50];
}
```

> **Catatan**: Tidak hapus `time_range` string field (breaking). Tambahkan field enum baru `time_range_enum` dan biarkan consumer migrate secara bertahap.

---

### SCALE-4.5: Tambahkan `soft_deleted_info` ke `AuditInfo` untuk Soft Delete Tracking

**File**: `common/v1/common.proto`  
**Masalah**: Tidak ada tracking siapa yang melakukan soft delete dan kapan

```protobuf
// Update AuditInfo dengan fields baru (non-breaking — hanya tambah):
message AuditInfo {
  // Existing fields (unchanged):
  string created_at = 1;
  string created_by = 2;
  string updated_at = 3;
  string updated_by = 4;
  
  // New fields for soft delete tracking:
  // Timestamp when the record was soft-deleted (null if active).
  optional string deleted_at = 5;
  // User who soft-deleted the record.
  optional string deleted_by = 6;
}
```

---

## 6. FASE 5: CI/CD & Tooling Improvements (Sprint 4-5)

---

### CI-5.1: Tambahkan TypeScript Generation ke CI Pipeline

**File**: `.github/workflows/ci.yml`  
**Masalah**: Frontend types tidak di-generate otomatis di CI

```yaml
# Tambahkan job baru setelah generate:
generate-typescript:
  name: Generate TypeScript Types
  runs-on: ubuntu-latest
  needs: lint-and-check
  if: github.ref == 'refs/heads/main' && github.event_name == 'push'
  permissions:
    contents: write
  steps:
    - uses: actions/checkout@v4
    
    - name: Setup Buf
      uses: bufbuild/buf-setup-action@v1
      with:
        github_token: ${{ secrets.GITHUB_TOKEN }}
    
    - name: Checkout frontend repo
      uses: actions/checkout@v4
      with:
        repository: mutugading/goapps-frontend
        path: goapps-frontend
        token: ${{ secrets.PAT_TOKEN }}
    
    - name: Setup Node.js
      uses: actions/setup-node@v4
      with:
        node-version: '20'
    
    - name: Install frontend deps (for ts-proto)
      working-directory: goapps-frontend
      run: npm ci --ignore-scripts
    
    - name: Generate TypeScript types
      run: |
        export PATH="$PWD/goapps-frontend/node_modules/.bin:$PATH"
        buf generate --template buf.gen.ts.yaml
    
    - name: Commit generated TypeScript types
      working-directory: goapps-frontend
      run: |
        git config user.name "github-actions[bot]"
        git config user.email "github-actions[bot]@users.noreply.github.com"
        git add src/types/generated/
        if git diff --staged --quiet; then
          echo "No TypeScript changes to commit"
        else
          git commit -m "chore(proto): regenerate TypeScript types from shared-proto"
          git push
        fi
```

---

### CI-5.2: Perbaiki `buf breaking` Command untuk Private Repo

**File**: `.github/workflows/ci.yml`

```yaml
# Sebelum (bisa fail untuk private repo):
- name: Check breaking changes
  run: buf breaking --against 'https://github.com/mutugading/goapps-shared-proto.git#branch=main'

# Sesudah (gunakan local git history — lebih reliable):
- name: Check breaking changes
  run: buf breaking --against '.git#branch=main'
```

---

### CI-5.3: Tambahkan Caching untuk Buf Dependencies

**File**: `.github/workflows/ci.yml`

```yaml
# Tambahkan step caching setelah checkout:
- name: Cache Buf dependencies
  uses: actions/cache@v4
  with:
    path: ~/.cache/buf
    key: buf-${{ hashFiles('buf.lock') }}
    restore-keys: |
      buf-
```

---

### CI-5.4: Tambahkan Build Verification Step

**File**: `.github/workflows/ci.yml`

```yaml
# Di job generate, tambahkan verification:
- name: Verify Go code compiles
  working-directory: goapps-backend
  run: |
    cd gen
    go build ./...

# Pertimbangkan juga untuk TypeScript:
- name: Verify TypeScript types
  working-directory: goapps-frontend
  run: npx tsc --noEmit
```

---

### CI-5.5: Tambahkan Semantic Versioning dan Git Tagging

**Buat file baru**: `.github/workflows/release.yml`

```yaml
name: Release

on:
  push:
    branches: [main]

permissions:
  contents: write

jobs:
  tag:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      
      - name: Get next version
        id: version
        run: |
          # Get latest tag
          LATEST=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")
          # Parse and increment patch version
          MAJOR=$(echo $LATEST | cut -d. -f1 | tr -d 'v')
          MINOR=$(echo $LATEST | cut -d. -f2)
          PATCH=$(echo $LATEST | cut -d. -f3)
          NEW_TAG="v${MAJOR}.${MINOR}.$((PATCH + 1))"
          echo "tag=$NEW_TAG" >> $GITHUB_OUTPUT
      
      - name: Create tag
        run: |
          git tag ${{ steps.version.outputs.tag }}
          git push origin ${{ steps.version.outputs.tag }}
```

---

### CI-5.6: Pin Plugin Versions di `buf.gen.yaml`

```yaml
# Sebelum (latest, tidak reproducible):
plugins:
  - remote: buf.build/protocolbuffers/go
    out: ../goapps-backend/gen

# Sesudah (pinned versions):
plugins:
  - remote: buf.build/protocolbuffers/go:v1.34.2
    out: ../goapps-backend/gen
    opt:
      - paths=source_relative
  
  - remote: buf.build/grpc/go:v1.4.0
    out: ../goapps-backend/gen
    opt:
      - paths=source_relative
  
  - remote: buf.build/grpc-ecosystem/gateway:v2.22.0
    out: ../goapps-backend/gen
    opt:
      - paths=source_relative
  
  - remote: buf.build/grpc-ecosystem/openapiv2:v2.22.0
    out: ../goapps-backend/gen/openapi
```

---

### CI-5.7: Perbaiki Breaking Change Detection Level

**File**: `buf.yaml`

```yaml
# Sebelum:
breaking:
  use:
    - FILE

# Sesudah (lebih ketat — deteksi breaking change di wire format):
breaking:
  use:
    - WIRE_JSON   # Deteksi perubahan yang break wire format AND JSON encoding
  except:
    - FIELD_SAME_JSON_NAME_AND_NUMBER  # Jika perlu exception tertentu
```

---

## 7. FASE 6: Documentation Sync (Ongoing)

---

### DOC-6.1: Update RULES.md — Sinkronkan `audit` Field Range

**File**: `RULES.md` baris 212-213  
**Masalah**: RULES.md menyebut `audit = 16` tapi implementasi menggunakan 6-8

```markdown
<!-- Sebelum di RULES.md: -->
```protobuf
message UOM {
  // Core fields: 1-15
  string uom_id = 1;
  ...
  bool is_active = 6;
  
  // Audit/metadata: 16-20
  common.v1.AuditInfo audit = 16;
}
```

<!-- Sesudah (sinkronkan dengan implementasi aktual): -->
```protobuf
// NOTE: Karena existing entities menggunakan field 6-8 untuk audit
// (dan tidak bisa diubah tanpa breaking change), convention yang 
// diterapkan adalah:
// - Entity sederhana (≤5 core fields): audit di field 6
// - Entity sedang (≤7 core fields): audit di field 7-8
// - Entity kompleks (≤14 core fields): audit di field 14-15
// Untuk entity BARU dengan fields yang akan berkembang, gunakan field 16+ untuk audit.
```
```

---

### DOC-6.2: Update RULES.md — Email Validation Consistency

**File**: `RULES.md` baris 324  
Klarifikasi kapan menggunakan `string.email = true` vs custom regex:

```markdown
<!-- Tambahkan section di RULES.md: -->
### Email Validation

Gunakan `string.email = true` (built-in protovalidate) untuk validasi email:

```protobuf
// ✅ CORRECT — Built-in, RFC 5322 compliant
string email = 1 [(buf.validate.field).string = {
  max_len: 255
  email: true
}];

// ⚠️ ACCEPTABLE tapi kurang preferred — Custom regex
string email = 1 [(buf.validate.field).string = {
  min_len: 1
  max_len: 255
  pattern: "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"
}];
```

NOTE: `string.email = true` menggunakan UTA46 normalization. Ensure backend normalizes
email before comparison (lowercase, remove unicode normalization artifacts).
```

---

### DOC-6.3: Update PR Template

**File**: `.github/PULL_REQUEST_TEMPLATE.md`  
Hapus specific file names dari example (sudah tidak up-to-date), ganti dengan generic:

```markdown
<!-- Sebelum: -->
### Proto Files Changed
- [ ] `finance/v1/uom.proto`

<!-- Sesudah: -->
### Proto Files Changed
<!-- List all proto files modified in this PR -->
- [ ] `common/v1/common.proto`
- [ ] `finance/v1/...`
- [ ] `iam/v1/...`
- [ ] `hr/v1/...` (future)
- [ ] `production/v1/...` (future)
```

---

### DOC-6.4: Tambahkan Komentar ke `buf.yaml` tentang `PACKAGE_VERSION_SUFFIX` Exception

```yaml
# buf.yaml
version: v2
modules:
  - path: .
    name: buf.build/goapps/shared-proto
breaking:
  use:
    - WIRE_JSON
lint:
  use:
    - STANDARD
  except:
    # PACKAGE_VERSION_SUFFIX is excepted because our package convention uses
    # dot notation (e.g., "finance.v1") which technically satisfies the version
    # suffix requirement but triggers this lint rule. This is intentional.
    - PACKAGE_VERSION_SUFFIX
deps:
  - buf.build/googleapis/googleapis
  - buf.build/bufbuild/protovalidate
```

---

### DOC-6.5: Tambahkan Dokumentasi Cross-Service Session Sharing

**File**: `iam/v1/session.proto`  
Tambahkan komentar yang menjelaskan `service_name` dalam `Session`:

```protobuf
// Session represents an active user session.
// Sessions are service-scoped: a user may have separate sessions per service,
// but authentication tokens (JWT) are shared across all services.
// The service_name field indicates which service originated the session.
message Session {
  string session_id = 1;
  // ...
  // Service that originated this session (e.g., "iam", "finance", "hr").
  // A user may have at most one active session per service.
  string service_name = 7;
  // ...
}
```

---

## 8. FASE 7: Domain Expansion (Long Term)

Berdasarkan ERD di `.docs/erd-mermaid.md`, berikut roadmap domain expansion yang diperlukan:

---

### DOMAIN-7.1: Finance Module — Currency & Exchange Rate

**Target file**: `finance/v1/currency.proto`

```protobuf
// Contoh skeleton:
service CurrencyService {
  rpc CreateCurrency(CreateCurrencyRequest) returns (CreateCurrencyResponse) {
    option (google.api.http) = {post: "/api/v1/finance/currencies" body: "*"};
  }
  rpc GetExchangeRate(GetExchangeRateRequest) returns (GetExchangeRateResponse) {
    option (google.api.http) = {get: "/api/v1/finance/exchange-rates"};
  }
  // ... CRUD + Import/Export
}

message Currency {
  string currency_id = 1;
  string currency_code = 2;  // IDR, USD, EUR
  string currency_name = 3;
  string symbol = 4;
  bool is_active = 5;
  common.v1.AuditInfo audit = 6;
}

message ExchangeRate {
  string rate_id = 1;
  string from_currency_id = 2;
  string to_currency_id = 3;
  double rate = 4;             // Pertimbangkan string untuk precision
  string effective_date = 5;   // ISO 8601
  bool is_active = 6;
  common.v1.AuditInfo audit = 7;
}
```

---

### DOMAIN-7.2: Production Module — Process & Parameter Master

**Target file**: `production/v1/process.proto`

```
production/
└── v1/
    ├── process.proto       # MST_PROCESS, MST_PARAMETER, MST_PROCESS_PARAM
    ├── formula.proto       # MST_FORMULA, MST_PROCESS_FORMULA
    ├── raw_material.proto  # MST_RM_CATEGORY, MST_RM_ITEM
    ├── template.proto      # PRD_TEMPLATE dan semua routing/param/formula
    └── product.proto       # PRD_PRODUCT, routing tree, process params, RM
```

**Catatan khusus untuk routing tree** (dari ERD):
```
PRD_PRODUCT_ROUTING menggunakan:
  - path: string          // "/" delimited path untuk tree traversal
  - split_ratio: decimal  // Untuk multi-output process (sum harus = 1 per parent)
  - output_type: string   // "FDY", "DTY", "ACY", dll
```
Ini adalah structure data yang kompleks. Proto design perlu careful planning.

---

### DOMAIN-7.3: Transaction Module

**Target file**: `transaction/v1/param_request.proto`

```
transaction/
└── v1/
    └── param_request.proto   # TRX_PARAM_REQUEST, TRX_PARAM_REQUEST_DETAIL
```

Ini adalah workflow approval — perlu enum untuk status:
```protobuf
enum ParamRequestStatus {
  PARAM_REQUEST_STATUS_UNSPECIFIED = 0;
  PARAM_REQUEST_STATUS_PENDING = 1;
  PARAM_REQUEST_STATUS_APPROVED = 2;
  PARAM_REQUEST_STATUS_REJECTED = 3;
  PARAM_REQUEST_STATUS_REVISED = 4;
}
```

---

### DOMAIN-7.4: Costing & Calculation Module

**Target file**: `costing/v1/` dan `calculation/v1/`

```
costing/
└── v1/
    ├── period.proto       # CST_PERIOD
    ├── rm_price.proto     # CST_RM_PRICE
    └── param_rate.proto   # CST_PARAM_RATE

calculation/
└── v1/
    ├── job.proto          # CAL_JOB, CAL_JOB_DETAIL
    └── cost.proto         # CAL_PRODUCT_COST, CAL_PROCESS_COST, CAL_RM_COST
```

**Catatan penting**: Calculation module adalah **core business logic** — perhitungan biaya produksi tekstil multi-proses. Diperlukan careful analysis sebelum proto design:
- Apakah calculation RPC adalah synchronous atau async (long-running job)?
- Jika async: perlu job status polling atau streaming?
- Precision untuk cost fields: `double` vs `string` vs `bytes` (fixed-point)?

---

## 9. Breaking Change Considerations

### Apa yang Aman (Non-Breaking)
- ✅ Tambah field baru dengan field number baru
- ✅ Tambah RPC method baru
- ✅ Tambah enum value baru
- ✅ Tambah service baru
- ✅ Tambah message baru
- ✅ Membuat field yang sebelumnya required menjadi optional
- ✅ Menambah validation constraint yang lebih ketat JIKA tidak ada existing data yang invalid

### Apa yang Breaking
- ❌ Hapus/rename field
- ❌ Ubah field number
- ❌ Ubah field type
- ❌ Hapus RPC/service
- ❌ Ubah package name
- ❌ Pindahkan message ke package lain (fully-qualified name berubah)

### Perubahan yang "Technically Breaking tapi Practically Safe"
Beberapa perubahan di atas seperti memindahkan `ActiveFilter` ke `common.proto` adalah breaking secara teknis (FQN berubah dari `iam.v1.ActiveFilter` ke `common.v1.ActiveFilter`) tapi dapat ditangani dengan:

1. **Coordination window**: Berikan notifikasi ke semua consumer (backend, frontend)
2. **Proto alias**: Tidak tersedia di proto3 secara native, tapi bisa via comment dan migration guide
3. **Version bump**: Buat `common/v2/common.proto` jika perubahan terlalu besar

---

## 10. Recommended Code Changes

Berikut adalah daftar perubahan kode yang direkomendasikan, diurutkan dari yang paling mudah/aman ke yang paling complex:

### Urutan Implementasi yang Direkomendasikan

```
Minggu 1 (Fixes):
  1. FIX-1.1: Perbaiki permission_code regex               [30 menit]
  2. FIX-1.2: Tambah email validation di VerifyResetOTP   [10 menit]
  3. FIX-1.3: Tambah file_name pattern ke 8 Import msgs   [30 menit]
  4. FIX-1.4: UUID validation pada role_ids               [10 menit]

Minggu 2 (CI/CD):
  5. CI-5.1: Tambah TS generation ke CI                   [1-2 jam]
  6. CI-5.2: Fix buf breaking command                     [10 menit]
  7. CI-5.3: Tambah buf caching                           [30 menit]
  8. CI-5.6: Pin plugin versions                          [30 menit]

Minggu 3 (Documentation):
  9. DOC-6.1: Update RULES.md field ranges                [30 menit]
  10. DOC-6.3: Update PR template                         [15 menit]
  11. DOC-6.4: Komentar buf.yaml exception                [10 menit]

Sprint 1-2 (Structural):
  12. STRUCT-2.1: Konsolidasi ke common.proto             [2-4 jam koordinasi]
  13. STRUCT-2.2: Pindahkan Permission                    [1-2 jam]
  14. STRUCT-2.3: Klarifikasi PaginationRequest           [30 menit]

Sprint 2-3 (Security):
  15. SEC-3.1: Standardisasi email validation             [30 menit]
  16. SEC-3.2: Timestamp validation                       [1 jam]
  17. SEC-3.4: Tambah RevokeAllSessions                   [1 jam]
  18. SEC-3.5: OrganizationType enum                      [30 menit]
  19. SCALE-4.4: time_range enum                          [30 menit]
  20. SCALE-4.5: deleted_at/deleted_by di AuditInfo       [30 menit]
```

---

## 11. Architecture Recommendations

### 11.1 Restrukturisasi `common.proto` — Target State

```protobuf
syntax = "proto3";
package common.v1;

// === RESPONSE PATTERNS ===

message BaseResponse { ... }          // Existing — no change
message ValidationError { ... }       // Existing — no change

// === PAGINATION ===

message PaginationRequest { ... }     // Existing — add note about usage
message PaginationResponse { ... }    // Existing — no change
message CursorPaginationRequest { ... }   // NEW — for large datasets
message CursorPaginationResponse { ... }  // NEW

// === AUDIT ===

message AuditInfo { ... }             // Existing + add deleted_at/deleted_by (fields 5-6)

// === SHARED ENUMS ===

enum ActiveFilter { ... }             // NEW — moved from finance.v1 and iam.v1
enum SortOrder { ... }                // NEW — reusable enum for sort direction

// === IMPORT/EXPORT ===

message ImportError { ... }           // NEW — moved from finance.v1 and iam.v1
message ImportRequest { ... }         // NEW — shared import fields (file_content, file_name, duplicate_action)
```

### 11.2 Restrukturisasi `iam/v1/` — Target State

```
iam/v1/
├── permission.proto      # NEW — Permission, PermissionDetail (extracted from user.proto/role.proto)
├── auth.proto            # Existing — AuthService (no structural change)
├── user.proto            # Modified — import permission.proto, remove ActiveFilter/ImportError def
├── role.proto            # Modified — import permission.proto, remove redundant import user.proto
├── organization.proto    # Modified — import permission.proto, remove import user.proto
├── menu.proto            # Modified — import permission.proto, remove import user.proto
├── session.proto         # Modified — add RevokeAllSessions
└── audit.proto           # Modified — add TimeRange enum, timestamp validation
```

### 11.3 Dependency Graph (Target State)

```
common.proto
    ↑ (imported by semua file)

permission.proto (NEW)
    ↑ imports: common.proto
    ↑ imported by: user.proto, role.proto, menu.proto

auth.proto
    ↑ imports: common.proto

user.proto
    ↑ imports: common.proto, permission.proto

role.proto
    ↑ imports: common.proto, permission.proto

organization.proto
    ↑ imports: common.proto
    (TIDAK lagi import user.proto atau permission.proto)

menu.proto
    ↑ imports: common.proto, permission.proto

session.proto
    ↑ imports: common.proto

audit.proto
    ↑ imports: common.proto
```

Clean dependency graph: tidak ada circular imports, setiap file hanya import yang benar-benar dibutuhkan.

### 11.4 File Export/Import — Best Practice untuk Production

**Current approach (in-memory bytes)** — OK untuk file kecil (<5MB):
```
Client → [POST bytes] → gRPC server → process → [return bytes] → Client
```

**Recommended approach untuk production** — Pre-signed URL:
```
Client → [POST: import request metadata] → gRPC server
       ← [return: upload_url (S3/GCS signed URL)]
Client → [PUT file bytes] → S3/GCS directly
Client → [POST: confirm import job_id] → gRPC server
       ← [return: job_id]
Client → [GET: job status] → gRPC server
       ← [return: pending/processing/done + result]
```

Ini memerlukan tambahan message types:
```protobuf
// Async Import Pattern (untuk file besar):
message InitiateImportRequest { ... }   // Client request presigned URL
message InitiateImportResponse {
  string upload_url = 1;    // Pre-signed S3/GCS URL
  string job_id = 2;        // Import job ID untuk polling
  string expires_at = 3;    // URL expiry
}

message GetImportStatusRequest {
  string job_id = 1;
}

message GetImportStatusResponse {
  string status = 1;        // "pending", "processing", "done", "failed"
  ImportResult result = 2;  // Hanya terisi jika done
}
```

---

## 12. Production-Grade Checklist

Berikut checklist untuk memverifikasi bahwa repository sudah production-grade:

### Proto Design ✅/❌

- [x] Semua messages punya komentar
- [x] Semua fields punya komentar
- [x] Field numbers tidak akan diubah
- [x] Semua enum punya `*_UNSPECIFIED = 0`
- [ ] ❌ `ActiveFilter` dan `ImportError` tidak duplikat (→ STRUCT-2.1)
- [ ] ❌ Permission code regex cocok dengan contoh di comment (→ FIX-1.1)
- [ ] ❌ Semua email fields punya format validation (→ FIX-1.2)
- [ ] ❌ Semua Import file_name punya pattern validation (→ FIX-1.3)
- [ ] ❌ Semua datetime fields punya format validation atau menggunakan Timestamp (→ SEC-3.2)

### Validation Coverage ✅/❌

- [x] Semua ID fields menggunakan `uuid = true`
- [x] Semua text fields punya max_len
- [x] Semua required fields punya min_len atau not_in=[0]
- [x] Sort fields menggunakan `in` constraint
- [ ] ❌ Per-item UUID validation pada repeated ID fields (→ FIX-1.4)
- [ ] ❌ Export filter IDs punya UUID validation (→ POLISH-3)

### Security ✅/❌

- [x] 2FA implemented (TOTP)
- [x] Session management (create, revoke, list)
- [x] Permission-based menu system
- [x] Audit logging
- [ ] ❌ `RevokeAllSessions` tidak ada (→ SEC-3.4)
- [ ] ❌ `OrganizationNode.type` tidak type-safe (→ SEC-3.5)

### CI/CD ✅/❌

- [x] Auto lint check pada PR
- [x] Breaking change detection
- [x] Auto generate Go code ke backend
- [ ] ❌ Auto generate TypeScript ke frontend (→ CI-5.1)
- [ ] ❌ Plugin versions tidak di-pin (→ CI-5.6)
- [ ] ❌ No build verification step (→ CI-5.4)
- [ ] ❌ No semantic versioning (→ CI-5.5)
- [ ] ❌ `buf breaking` command tidak ideal untuk private repo (→ CI-5.2)

### Scalability ✅/❌

- [x] Pagination pada semua List endpoints
- [x] Sort/filter pada semua List endpoints
- [ ] ❌ File export tidak streaming (→ SCALE-4.2)
- [ ] ❌ Tidak ada cursor-based pagination untuk high-volume data (→ SCALE-4.3)
- [ ] ❌ Tidak ada batch delete (→ SCALE-4.1)

### Documentation ✅/❌

- [x] README lengkap
- [x] RULES.md komprehensif
- [x] Issue templates tersedia
- [x] PR template tersedia
- [ ] ❌ RULES.md tidak sinkron dengan implementasi (field ranges) (→ DOC-6.1)
- [ ] ❌ PR template berisi outdated file references (→ DOC-6.3)

### Domain Completeness ✅/❌

- [x] IAM domain lengkap
- [x] Finance UOM lengkap
- [ ] ❌ Finance Currency/Exchange Rate belum ada (→ DOMAIN-7.1)
- [ ] ❌ Production domain belum ada (→ DOMAIN-7.2)
- [ ] ❌ Transaction domain belum ada (→ DOMAIN-7.3)
- [ ] ❌ Costing & Calculation domain belum ada (→ DOMAIN-7.4)

---

## Penutup

Repository ini sudah memiliki fondasi yang sangat baik — tooling modern, dokumentasi solid, dan pola yang konsisten. Dari 12 kategori production-grade checklist, **8 kategori sudah hijau** dalam aspek fundamental.

Yang perlu dilakukan sekarang (prioritas tertinggi):
1. **Fix BUG-1 (permission regex)** — developer akan blocked jika ini tidak diperbaiki
2. **Fix BUG-2/3 (duplikasi)** — structural debt yang akan semakin berat seiring waktu
3. **Tambah TypeScript ke CI** — frontend developer tidak boleh manually generate
4. **Pin plugin versions** — reproducible build adalah syarat production

Setelah FASE 1-3 selesai, repository ini akan berada pada kualitas **industrial-grade** yang sustainable untuk jangka panjang.

---

*Dokumen ini adalah living document — perlu di-update seiring perubahan yang diimplementasikan.*
