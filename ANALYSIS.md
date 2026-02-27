# Deep Research Analysis: goapps-shared-proto

> **Tanggal Analisis**: 27 Februari 2026  
> **Scope**: Seluruh repository dari layer terdalam hingga terluar  
> **Tujuan**: Temuan komprehensif untuk landasan improvement production-grade

---

## Daftar Isi

1. [Ringkasan Eksekutif](#1-ringkasan-eksekutif)
2. [Struktur Repository Lengkap](#2-struktur-repository-lengkap)
3. [Analisis Layer Terdalam: Proto Files](#3-analisis-layer-terdalam-proto-files)
   - 3.1 [common/v1/common.proto](#31-commonv1commonproto)
   - 3.2 [finance/v1/uom.proto](#32-financev1uomproto)
   - 3.3 [iam/v1/auth.proto](#33-iamv1authproto)
   - 3.4 [iam/v1/user.proto](#34-iamv1userproto)
   - 3.5 [iam/v1/role.proto](#35-iamv1roleproto)
   - 3.6 [iam/v1/organization.proto](#36-iamv1organizationproto)
   - 3.7 [iam/v1/menu.proto](#37-iamv1menuproto)
   - 3.8 [iam/v1/session.proto](#38-iamv1sessionproto)
   - 3.9 [iam/v1/audit.proto](#39-iamv1auditproto)
4. [Analisis Layer Tengah: Konfigurasi Buf](#4-analisis-layer-tengah-konfigurasi-buf)
5. [Analisis Layer Menengah: Scripts](#5-analisis-layer-menengah-scripts)
6. [Analisis Layer Luar: CI/CD Pipeline](#6-analisis-layer-luar-cicd-pipeline)
7. [Analisis Layer Terluar: Dokumentasi & Governance](#7-analisis-layer-terluar-dokumentasi--governance)
8. [Analisis Pola Arsitektur Lintas-File](#8-analisis-pola-arsitektur-lintas-file)
9. [Inventaris Lengkap: Services, RPCs, Messages](#9-inventaris-lengkap-services-rpcs-messages)
10. [Temuan Kritis: Bug & Inkonsistensi](#10-temuan-kritis-bug--inkonsistensi)
11. [Temuan Sedang: Design Gaps](#11-temuan-sedang-design-gaps)
12. [Temuan Ringan: Polish & Consistency](#12-temuan-ringan-polish--consistency)
13. [Analisis Kelengkapan Domain vs ERD](#13-analisis-kelengkapan-domain-vs-erd)
14. [Scorecard Kualitas Keseluruhan](#14-scorecard-kualitas-keseluruhan)

---

## 1. Ringkasan Eksekutif

Repository `goapps-shared-proto` adalah **schema repository** — *single source of truth* untuk definisi Protocol Buffer dari platform GoApps milik **PT Mutu Gading Tekstil**. Repository ini bukan service yang berjalan, melainkan fondasi kontrak API antara:

- **Backend**: Go microservices (di `goapps-backend`)
- **Frontend**: Next.js app (di `goapps-frontend`)
- **Dokumentasi**: OpenAPI/Swagger (di-generate otomatis)

**Status keseluruhan**: Repository ini menunjukkan fondasi yang **solid dan well-structured** dengan tooling modern (Buf v2, protovalidate, grpc-gateway, buf CI). Dokumentasi internal (README, RULES, CONTRIBUTING, issue templates) sangat lengkap. Namun, ditemukan **3 bug aktif**, **8 design gap signifikan**, dan **sejumlah inkonsistensi** yang perlu diselesaikan sebelum repository ini benar-benar production-grade.

Yang lebih penting: berdasarkan ERD di `.docs/erd-mermaid.md`, repository ini baru meng-cover **~15% dari total domain bisnis** yang direncanakan. Domain produksi, costing, dan kalkulasi sama sekali belum ada proto-nya.

---

## 2. Struktur Repository Lengkap

```
goapps-shared-proto/
│
├── .docs/
│   └── erd-mermaid.md                  # ERD database lengkap (Mermaid)
│
├── .github/
│   ├── ISSUE_TEMPLATE/
│   │   ├── bug_report.md               # Template issue: bug
│   │   ├── config.yml                  # blank_issues_enabled: false
│   │   ├── new_service.md              # Template issue: service baru
│   │   └── proto_change.md             # Template issue: perubahan proto
│   ├── workflows/
│   │   ├── .gitkeep
│   │   └── ci.yml                      # GitHub Actions pipeline
│   └── PULL_REQUEST_TEMPLATE.md        # Template PR
│
├── common/
│   └── v1/
│       └── common.proto                # Shared types (BaseResponse, Pagination, AuditInfo)
│
├── finance/
│   └── v1/
│       └── uom.proto                   # UOMService (8 RPCs)
│
├── iam/
│   └── v1/
│       ├── .gitkeep
│       ├── audit.proto                 # AuditService (4 RPCs)
│       ├── auth.proto                  # AuthService (11 RPCs)
│       ├── menu.proto                  # MenuService (14 RPCs)
│       ├── organization.proto          # 5 Services: Company/Division/Dept/Section/Org (33 RPCs)
│       ├── role.proto                  # RoleService (11 RPCs) + PermissionService (9 RPCs)
│       ├── session.proto               # SessionService (3 RPCs)
│       └── user.proto                  # UserService (15 RPCs)
│
├── scripts/
│   ├── .gitkeep
│   ├── gen-all.sh                      # Jalankan go + ts generation secara berurutan
│   ├── gen-go.sh                       # Generate Go + go mod tidy
│   └── gen-ts.sh                       # Generate TypeScript via ts-proto
│
├── buf.gen.ts.yaml                     # Buf config: TypeScript generation
├── buf.gen.yaml                        # Buf config: Go + gRPC + gateway + openapi
├── buf.lock                            # Pinned dependency digests
├── buf.yaml                            # Buf module: lint rules, breaking rules, deps
├── CONTRIBUTING.md                     # Panduan kontribusi
├── LICENSE                             # Proprietary: PT Mutu Gading Tekstil
├── README.md                           # Dokumentasi utama (~596 baris)
└── RULES.md                            # Aturan pengembangan proto (~614 baris)
```

**Statistik**:
- Total file non-git: **32 file**
- Total proto files: **9 file**
- Total services: **13 services**
- Total RPC methods: **108 methods**
- Total messages: **~180+ messages**

---

## 3. Analisis Layer Terdalam: Proto Files

### 3.1 `common/v1/common.proto`

**Package**: `common.v1`  
**Baris**: 58  
**Dependensi eksternal**: Tidak ada  

#### Messages yang Didefinisikan

| Message | Fields | Deskripsi |
|---------|--------|-----------|
| `BaseResponse` | `validation_errors[]`, `status_code` (string), `is_success` (bool), `message` (string) | Wrapper response standar semua API |
| `ValidationError` | `field` (string), `message` (string) | Error validasi per-field dari protovalidate |
| `PaginationRequest` | `page` (int32), `page_size` (int32) | Parameter paginasi — **tidak digunakan di mana pun** |
| `PaginationResponse` | `current_page`, `page_size`, `total_items` (int64), `total_pages` | Metadata response paginasi |
| `AuditInfo` | `created_at`, `created_by`, `updated_at`, `updated_by` (semua string) | Audit trail |

#### Temuan

**[TEMUAN C-1] `PaginationRequest` didefinisikan tapi tidak pernah digunakan**  
`PaginationRequest` ada di `common.proto` sebagai message reusable, namun seluruh `List*Request` di semua service menduplikasi field `page` dan `page_size` secara manual alih-alih menggunakan embedded message ini.

```protobuf
// Didefinisikan di common.proto:
message PaginationRequest {
  int32 page = 1;
  int32 page_size = 2;
}

// Tapi di setiap service, selalu seperti ini:
message ListUOMsRequest {
  int32 page = 1 [(buf.validate.field).int32.gte = 1];      // DUPLIKAT
  int32 page_size = 2 [(buf.validate.field).int32 = {...}]; // DUPLIKAT
  // ...
}
```

**[TEMUAN C-2] `AuditInfo` menggunakan `string` untuk semua timestamp**  
Semua field datetime (`created_at`, `updated_at`) menggunakan `string` daripada `google.protobuf.Timestamp`. Ini menyerahkan penuh tanggung jawab enforcement format kepada application layer. Tidak ada jaminan di level proto bahwa string berformat ISO 8601.

**[TEMUAN C-3] `AuditInfo` tidak punya `deleted_at`/`deleted_by`**  
Semua service menggunakan soft delete (`is_active = false`), namun `AuditInfo` tidak memiliki field untuk mencatat kapan dan siapa yang melakukan soft delete. Informasi ini berguna untuk audit compliance.

**[TEMUAN C-4] `status_code` adalah `string` bukan enum atau int**  
Nilai seperti `"200"`, `"400"`, `"404"`, `"500"` direpresentasikan sebagai string tanpa constraint nilai valid. Tidak ada enforcement di level proto. Consumer harus parse dan validasi sendiri.

**[TEMUAN C-5] Tidak ada `SortRequest` reusable message**  
Pattern `sort_by` + `sort_order` diduplikasi di setiap `List*Request`. Ini murni duplikasi yang bisa dikonsolidasi. Namun perlu dipertimbangkan: karena nilai `in` untuk `sort_by` berbeda per service, message reusable hanya bisa dipakai untuk `sort_order`, bukan `sort_by`.

---

### 3.2 `finance/v1/uom.proto`

**Package**: `finance.v1`  
**Baris**: 364  
**Imports**: `buf/validate/validate.proto`, `common/v1/common.proto`, `google/api/annotations.proto`  

#### Enums

```protobuf
enum UOMCategory {
  UOM_CATEGORY_UNSPECIFIED = 0;  // "no filter" dalam list/export
  UOM_CATEGORY_WEIGHT = 1;       // KG, GR, TON
  UOM_CATEGORY_LENGTH = 2;       // MTR, CM, YARD
  UOM_CATEGORY_VOLUME = 3;       // LTR, ML
  UOM_CATEGORY_QUANTITY = 4;     // PCS, BOX, SET
}

enum ActiveFilter {
  ACTIVE_FILTER_UNSPECIFIED = 0;
  ACTIVE_FILTER_ACTIVE = 1;
  ACTIVE_FILTER_INACTIVE = 2;
}
```

#### Service: UOMService

| RPC | HTTP | Endpoint | Request → Response |
|-----|------|----------|--------------------|
| `CreateUOM` | POST | `/api/v1/finance/uoms` | `CreateUOMRequest` → `CreateUOMResponse` |
| `GetUOM` | GET | `/api/v1/finance/uoms/{uom_id}` | `GetUOMRequest` → `GetUOMResponse` |
| `UpdateUOM` | PUT | `/api/v1/finance/uoms/{uom_id}` | `UpdateUOMRequest` → `UpdateUOMResponse` |
| `DeleteUOM` | DELETE | `/api/v1/finance/uoms/{uom_id}` | `DeleteUOMRequest` → `DeleteUOMResponse` |
| `ListUOMs` | GET | `/api/v1/finance/uoms` | `ListUOMsRequest` → `ListUOMsResponse` |
| `ExportUOMs` | GET | `/api/v1/finance/uoms/export` | `ExportUOMsRequest` → `ExportUOMsResponse` |
| `ImportUOMs` | POST | `/api/v1/finance/uoms/import` | `ImportUOMsRequest` → `ImportUOMsResponse` |
| `DownloadTemplate` | GET | `/api/v1/finance/uoms/template` | `DownloadTemplateRequest` → `DownloadTemplateResponse` |

#### Temuan

**[TEMUAN U-1] `ActiveFilter` enum duplikat dengan `iam/v1/user.proto`**  
`ActiveFilter` didefinisikan identik di dua package berbeda (`finance.v1` dan `iam.v1`). Ini melanggar prinsip DRY. Harus dipindahkan ke `common/v1/common.proto`.

**[TEMUAN U-2] `ImportError` message duplikat dengan `iam/v1/user.proto`**  
`ImportError` dengan tiga field yang sama (`row_number`, `field`, `message`) didefinisikan di `finance/v1/uom.proto` dan `iam/v1/user.proto`. Harus dipindahkan ke `common/v1/common.proto`.

**[TEMUAN U-3] `UOM.audit` di field number 7 melanggar RULES.md**  
`RULES.md` (baris 212) menyebutkan: "Audit/metadata: 16-20". Tapi di implementasi aktual:
- `UOM.audit = 7` → seharusnya `= 16`
- `User.audit = 8` → seharusnya `= 16`
- `Role.audit = 8` → seharusnya `= 16`
- `Division.audit = 8` → seharusnya `= 16`
- Semua entity lain pun sama

Ini inkonsistensi antara dokumentasi dan implementasi. RULES.md perlu diupdate atau semua entity perlu dimigrate (field number tidak bisa diubah tanpa breaking change, jadi hanya RULES.md yang bisa direvisi untuk merefleksikan realita).

**[TEMUAN U-4] `ExportUOMsRequest` tidak ada validasi**  
`ImportUOMsRequest` memiliki validasi lengkap (bytes min/max, filename pattern, duplicate_action enum). Tapi `ExportUOMsRequest` tidak ada validasi sama sekali meskipun memiliki filter fields.

**[TEMUAN U-5] File export menggunakan `bytes` — tidak streaming-friendly**  
`ExportUOMsResponse.file_content` adalah `bytes` (in-memory seluruh file). Untuk file besar (ribuan baris Excel), ini tidak scalable. Idealnya menggunakan streaming RPC atau pre-signed URL pattern.

**[TEMUAN U-6] `DownloadTemplateRequest` adalah empty message tanpa identifier**  
Empty message tanpa context apapun. Ini tidak masalah sekarang karena endpoint URI unik, tapi jika nantinya perlu parameter (e.g., bahasa template), field harus ditambah.

**Validasi yang sudah benar**:
- `uom_code`: `min_len=1`, `max_len=20`, `pattern="^[A-Z][A-Z0-9_]*$"` ✅
- `uom_name`: `min_len=1`, `max_len=100` ✅
- `uom_category`: `not_in=[0]` pada Create ✅
- `file_content` bytes: `min_len=1`, `max_len=10485760` (10MB) ✅
- `file_name` pattern: `^[^/\\]+\.(xlsx|xls)$` ✅
- `sort_by` / `sort_order` menggunakan `in` constraint ✅
- Semua ID fields menggunakan `uuid = true` ✅

---

### 3.3 `iam/v1/auth.proto`

**Package**: `iam.v1`  
**Baris**: 397  
**Imports**: `buf/validate/validate.proto`, `common/v1/common.proto`, `google/api/annotations.proto`  

#### Service: AuthService (11 RPCs)

| RPC | HTTP | Endpoint |
|-----|------|----------|
| `Login` | POST | `/api/v1/iam/auth/login` |
| `Logout` | POST | `/api/v1/iam/auth/logout` |
| `RefreshToken` | POST | `/api/v1/iam/auth/refresh` |
| `ForgotPassword` | POST | `/api/v1/iam/auth/forgot-password` |
| `VerifyResetOTP` | POST | `/api/v1/iam/auth/verify-otp` |
| `ResetPassword` | POST | `/api/v1/iam/auth/reset-password` |
| `UpdatePassword` | POST | `/api/v1/iam/auth/update-password` |
| `Enable2FA` | POST | `/api/v1/iam/auth/2fa/enable` |
| `Verify2FA` | POST | `/api/v1/iam/auth/2fa/verify` |
| `Disable2FA` | POST | `/api/v1/iam/auth/2fa/disable` |
| `GetCurrentUser` | GET | `/api/v1/iam/auth/me` |

#### Messages Kunci

```
LoginData:
  - access_token: string     (JWT, short-lived ~15 menit)
  - refresh_token: string    (long-lived ~7 hari)
  - expires_in: int64        (detik)
  - token_type: string       (selalu "Bearer")
  - user: AuthUser
  - requires_2fa: bool       (true jika 2FA enabled tapi totp_code kosong)

AuthUser:
  - user_id, username, email, full_name, profile_picture_url
  - roles: repeated string       (["ADMIN", "MANAGER"])
  - permissions: repeated string (["finance.master.uom.view"])
  - two_factor_enabled: bool
```

#### Temuan

**[TEMUAN A-1] `VerifyResetOTPRequest.email` tidak punya email format validation**  
`ForgotPasswordRequest.email` menggunakan `pattern: "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"`, tapi `VerifyResetOTPRequest.email` hanya `min_len=1, max_len=255`. Inkonsistensi ini memungkinkan string non-email lolos validasi di step kedua.

```protobuf
// ForgotPasswordRequest.email — ADA regex ✅
string email = 1 [(buf.validate.field).string = {
  min_len: 1, max_len: 255,
  pattern: "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"
}];

// VerifyResetOTPRequest.email — TIDAK ADA regex ❌
string email = 1 [(buf.validate.field).string = {
  min_len: 1, max_len: 255
  // pattern tidak ada
}];
```

**[TEMUAN A-2] Password tidak punya complexity constraint di proto level**  
`new_password` hanya divalidasi `min_len=8, max_len=100`. Comment pada baris 283 menyebut "must contain uppercase, lowercase, number" tapi tidak di-enforce. RULES.md baris 326 menyebut `string.email = true` tersedia, tapi tidak ada built-in password complexity di protovalidate. Ini bukan bug melainkan limitation proto — harus didokumentasikan eksplisit bahwa complexity dilakukan di application layer.

**[TEMUAN A-3] `LogoutRequest.refresh_token` adalah optional tanpa kejelasan semantik**  
```protobuf
message LogoutRequest {
  optional string refresh_token = 1;  // "if not provided uses current session"
}
```
Komentar menyebut "uses current session" jika tidak ada. Tapi "current session" itu ditentukan dari mana? Dari JWT access token di header? Ini design ambiguity yang harus didokumentasikan di comment, tidak bisa diasumsikan.

**[TEMUAN A-4] `LoginRequest` email regex tidak menggunakan `string.email = true`**  
RULES.md baris 324 menyebutkan `string.email = true` sebagai cara validasi email. Tapi actual code menggunakan custom regex. Protovalidate built-in `email = true` lebih reliable karena mengikuti RFC 5322.

**[TEMUAN A-5] `AuthUser.permissions` bisa sangat besar untuk user dengan banyak permission**  
Mengirim seluruh list permission dalam setiap response login bisa sangat besar jika permission count mencapai ratusan. Tidak ada mekanisme lazy-loading atau token-based permission check di sini.

**Hal yang sudah benar**:
- `IGNORE_IF_ZERO_VALUE` pada `totp_code` ✅ — validasi dilewati jika kosong
- TOTP `len=6, pattern="^[0-9]{6}$"` ✅
- `TwoFactorSetup.recovery_codes` sebagai `repeated string` ✅
- Password reset 3-step flow ✅
- `requires_2fa` flag dalam `LoginData` ✅

---

### 3.4 `iam/v1/user.proto`

**Package**: `iam.v1`  
**Baris**: 630  
**Imports**: `buf/validate`, `common/v1/common.proto`, `google/api/annotations.proto`  

#### Service: UserService (15 RPCs)

| RPC | HTTP | Endpoint |
|-----|------|----------|
| `CreateUser` | POST | `/api/v1/iam/users` |
| `GetUser` | GET | `/api/v1/iam/users/{user_id}` |
| `GetUserDetail` | GET | `/api/v1/iam/users/{user_id}/detail` |
| `UpdateUser` | PUT | `/api/v1/iam/users/{user_id}` |
| `UpdateUserDetail` | PUT | `/api/v1/iam/users/{user_id}/detail` |
| `DeleteUser` | DELETE | `/api/v1/iam/users/{user_id}` |
| `ListUsers` | GET | `/api/v1/iam/users` |
| `ExportUsers` | GET | `/api/v1/iam/users/export` |
| `ImportUsers` | POST | `/api/v1/iam/users/import` |
| `DownloadTemplate` | GET | `/api/v1/iam/users/template` |
| `AssignUserRoles` | POST | `/api/v1/iam/users/{user_id}/roles` |
| `RemoveUserRoles` | POST | `/api/v1/iam/users/{user_id}/roles/remove` |
| `AssignUserPermissions` | POST | `/api/v1/iam/users/{user_id}/permissions` |
| `RemoveUserPermissions` | POST | `/api/v1/iam/users/{user_id}/permissions/remove` |
| `GetUserRolesAndPermissions` | GET | `/api/v1/iam/users/{user_id}/access` |

#### Messages Kunci

```
User:
  user_id, username, email
  is_active, is_locked, two_factor_enabled
  last_login_at: optional string
  audit: AuditInfo (field 8)

UserDetail:
  detail_id, user_id
  section_id: optional string
  section: optional SectionInfo  ← denormalized hierarchy info
  employee_code, full_name, first_name, last_name
  phone, profile_picture_url, position (all optional)
  date_of_birth, address (all optional)
  audit: AuditInfo (field 14)

SectionInfo:
  section_id/code/name
  department_id/code/name  ← 3-level denormalized
  division_id/code/name
  company_id/code/name
```

#### Temuan

**[TEMUAN US-1] `ActiveFilter` didefinisikan di sini JUGA (duplikat dengan `finance/v1/uom.proto`)**  
Ini sudah disebutkan di temuan U-1. `user.proto` mendefinisikan:
```protobuf
enum ActiveFilter {
  ACTIVE_FILTER_UNSPECIFIED = 0;
  ACTIVE_FILTER_ACTIVE = 1;
  ACTIVE_FILTER_INACTIVE = 2;
}
```
Identik dengan yang di `uom.proto`. Keduanya harus dikonsolidasi ke `common.proto`.

**[TEMUAN US-2] `ImportError` didefinisikan di sini JUGA (duplikat)**  
Sama persis dengan yang di `uom.proto`. Ini harus dipindahkan ke `common.proto`.

**[TEMUAN US-3] `CreateUserRequest.role_ids` tidak divalidasi sebagai UUID**  
```protobuf
// Field ini tidak ada item-level UUID validation:
repeated string role_ids = 13;

// Seharusnya:
repeated string role_ids = 13 [(buf.validate.field).repeated.items.string.uuid = true];
```
Bandingkan dengan `AssignUserRolesRequest.role_ids` yang sudah ada `min_items = 1` tapi juga tidak ada UUID validation per item.

**[TEMUAN US-4] `GetUser` vs `GetUserDetail` — redundansi endpoint**  
- `GetUser` → returns `User` (data user saja, tanpa detail)
- `GetUserDetail` → returns `UserWithDetail` (user + detail + role_codes)

Dua endpoint untuk mendapatkan data user yang sama menambah kebingungan: kapan pakai mana? Di real application, frontend hampir selalu butuh `UserWithDetail`. `GetUser` yang hanya return `User` jarang berguna.

**[TEMUAN US-5] `ExportUsersRequest` filter IDs tidak ada UUID validation**  
```protobuf
message ExportUsersRequest {
  ActiveFilter active_filter = 1;
  optional string section_id = 2;    // Tidak ada uuid validation
  optional string department_id = 3; // Tidak ada uuid validation
  optional string division_id = 4;   // Tidak ada uuid validation
  optional string company_id = 5;    // Tidak ada uuid validation
}
```
Bandingkan dengan `ListUsersRequest` yang sudah ada `uuid = true` untuk semua filter ID.

**[TEMUAN US-6] `SectionInfo` adalah denormalized data — risk of stale data**  
`UserDetail.section` menyimpan embedded `SectionInfo` yang berisi full hierarchy (company, division, department, section). Jika nama salah satu dari mereka diubah, data di `UserDetail.section` menjadi stale kecuali backend secara aktif melakukan join saat setiap response.

**Hal yang sudah benar**:
- `username` pattern `^[a-zA-Z][a-zA-Z0-9_]*$` ✅
- `email` dengan regex di `CreateUserRequest` ✅
- Semua ID di `ListUsersRequest` ada `uuid = true` ✅
- `AssignUserRolesRequest.role_ids` ada `min_items = 1` ✅
- Pemisahan `User` dan `UserDetail` untuk credential vs employee data ✅

---

### 3.5 `iam/v1/role.proto`

**Package**: `iam.v1`  
**Baris**: 414  
**Imports**: `buf/validate`, `common/v1/common.proto`, `google/api/annotations.proto`, **`iam/v1/user.proto`**  

> **Perhatian**: `role.proto` mengimpor `iam/v1/user.proto` hanya untuk menggunakan `ImportError`, `ActiveFilter`, dan `Permission`. Ini adalah **import yang tidak bersih** — seharusnya `ImportError` dan `ActiveFilter` di `common.proto`.

#### Services

**RoleService** (11 RPCs): CRUD + Export/Import/Template + Permission assignment + GetRolePermissions  
**PermissionService** (9 RPCs): CRUD + Export/Import/Template + GetPermissionsByService  

#### Messages Kunci

```
Role:
  role_id, role_code, role_name, description
  is_system: bool    ← system roles tidak bisa dihapus
  is_active: bool
  user_count: int32  ← DENORMALIZED COUNT (bisa stale)
  audit: AuditInfo

PermissionDetail:
  permission_id, permission_code, permission_name, description
  service_name, module_name, action_type
  is_active: bool
  role_count: int32  ← DENORMALIZED COUNT (bisa stale)
  audit: AuditInfo

ServicePermissions → repeated ModulePermissions → repeated PermissionDetail
```

#### Temuan

**[TEMUAN R-1] BUG AKTIF: `permission_code` regex 4-segment tapi contoh di comment adalah 3-segment**  

Ini adalah bug nyata yang akan menyebabkan developer bingung dan error saat runtime:

```protobuf
// Comment di baris 281-282:
// Permission code format: {service}.{module}.{entity}.{action}
// e.g., finance.master.uom.view, iam.user.create
//                                 ↑↑↑ INI HANYA 3 SEGMENT! iam.user.create

// Tapi regex yang digunakan (baris 285):
pattern: "^[a-z][a-z0-9]*\\.[a-z][a-z0-9]*\\.[a-z][a-z0-9]*\\.[a-z]+$"
//         ^^^segment1^^^  ^^^segment2^^^   ^^^segment3^^^   ^^^seg4^^^
// = 4 segment WAJIB: {a}.{b}.{c}.{d}
```

Contoh `iam.user.create` hanya punya 3 segment → **regex akan REJECT contoh tersebut**. Developer yang mengikuti contoh di comment akan mendapatkan validation error.

Format yang benar berdasarkan permissions yang ada di `AuthUser.permissions`:
- `finance.master.uom.view` → **4 segment** ✅
- `iam.user.create` → **3 segment** ❌ (tidak cocok dengan regex)

**[TEMUAN R-2] `Role.user_count` dan `PermissionDetail.role_count` adalah denormalized computed fields**  
Nilai ini bisa stale kapan saja user di-assign atau di-remove rolenya. Tidak ada penanda `deprecated` atau catatan bahwa nilai ini eventual-consistent atau computed.

**[TEMUAN R-3] `role.proto` mengimpor `user.proto` hanya untuk type reuse — coupling yang salah**  
```protobuf
import "iam/v1/user.proto";  // Hanya untuk ImportError, ActiveFilter, Permission
```
`Permission` message didefinisikan di `user.proto` tapi digunakan di `role.proto`. Ini menciptakan dependency chain yang tidak perlu:
- `organization.proto` → imports `user.proto`
- `menu.proto` → imports `user.proto`
- `role.proto` → imports `user.proto`

Jika `user.proto` berubah (bahkan perubahan kecil), semua file yang mengimpor ikut perlu re-generate.

**[TEMUAN R-4] `ImportRolesRequest` tidak ada `file_name` pattern validation**  
```protobuf
// ImportUOMsRequest di uom.proto — ADA pattern ✅
string file_name = 2 [(buf.validate.field).string = {
  min_len: 1, max_len: 255,
  pattern: "^[^/\\\\]+\\.(xlsx|xls)$"
}];

// ImportRolesRequest di role.proto — TIDAK ADA pattern ❌
string file_name = 2 [(buf.validate.field).string = {
  min_len: 1, max_len: 255
  // pattern tidak ada
}];
```
Sama juga untuk `ImportPermissionsRequest`, `ImportCompaniesRequest`, `ImportDivisionsRequest`, dan seterusnya.

**[TEMUAN R-5] `CreateRoleRequest.permission_ids` tidak ada UUID validation per item**  
```protobuf
repeated string permission_ids = 4;  // Tidak ada item UUID validation
```

---

### 3.6 `iam/v1/organization.proto`

**Package**: `iam.v1`  
**Baris**: 655  
**Imports**: `buf/validate`, `common/v1/common.proto`, `google/api/annotations.proto`, **`iam/v1/user.proto`** (untuk `ImportError`, `ActiveFilter`)  

#### Services (5 services)

| Service | RPCs | Base URL |
|---------|------|----------|
| `CompanyService` | 8 (CRUD+Export+Import+Template) | `/api/v1/iam/companies` |
| `DivisionService` | 8 (CRUD+Export+Import+Template) | `/api/v1/iam/divisions` |
| `DepartmentService` | 8 (CRUD+Export+Import+Template) | `/api/v1/iam/departments` |
| `SectionService` | 8 (CRUD+Export+Import+Template) | `/api/v1/iam/sections` |
| `OrganizationService` | 1 (`GetOrganizationTree`) | `/api/v1/iam/organization/tree` |

#### Messages Kunci (Hierarki Nested)

```
Company:
  company_id, company_code, company_name, description, is_active
  audit: AuditInfo (field 6)

Division:
  division_id, company_id
  company: Company          ← EMBEDDED PARENT (full Company object)
  division_code, division_name, description, is_active
  audit: AuditInfo (field 8)

Department:
  department_id, division_id
  division: Division        ← EMBEDDED PARENT (full Division + Company)
  department_code, department_name, description, is_active
  audit: AuditInfo (field 8)

Section:
  section_id, department_id
  department: Department    ← EMBEDDED PARENT (full Dept + Division + Company)
  section_code, section_name, description, is_active
  audit: AuditInfo (field 8)

OrganizationNode:           ← RECURSIVE message untuk tree view
  id, code, name
  type: string              ← "company"/"division"/"department"/"section" (string, bukan enum!)
  is_active: bool
  children: repeated OrganizationNode
```

#### Temuan

**[TEMUAN O-1] Deep embedding → potential N+1 query dan payload bloat**  
`Section` menyertakan `Department` yang menyertakan `Division` yang menyertakan `Company`. Setiap `GetSection` response membawa data Company lengkap meskipun client mungkin hanya butuh `section_name`. Untuk list dengan 100 sections, ini 100x Company + Division + Department object.

**[TEMUAN O-2] `OrganizationNode.type` sebagai string bukan enum**  
```protobuf
string type = 4; // "company", "division", "department", "section"
```
Tidak ada compile-time atau proto-validation constraint. Seharusnya menggunakan enum:
```protobuf
// Yang seharusnya:
enum OrganizationType {
  ORGANIZATION_TYPE_UNSPECIFIED = 0;
  ORGANIZATION_TYPE_COMPANY = 1;
  ORGANIZATION_TYPE_DIVISION = 2;
  ORGANIZATION_TYPE_DEPARTMENT = 3;
  ORGANIZATION_TYPE_SECTION = 4;
}
OrganizationType type = 4;
```

**[TEMUAN O-3] Semua `Import*Request` di organization.proto tidak ada `file_name` pattern**  
Sama dengan temuan R-4. Inconsistency validasi antara `uom.proto` yang ada pattern dan semua file organization yang tidak ada pattern.

**[TEMUAN O-4] `UpdateDivisionRequest` dapat mengubah `company_id` (re-parenting)**  
```protobuf
optional string company_id = 2 [(buf.validate.field).string.uuid = true];
```
Re-parenting division dari satu company ke company lain adalah operasi sensitif. Tidak ada warning atau constraint di proto level tentang implikasi re-parenting (semua department dan section di bawahnya ikut pindah).

**[TEMUAN O-5] Pattern code validation sama untuk Company/Division/Department/Section**  
Semua menggunakan `pattern: "^[A-Z][A-Z0-9_]*$"`, tapi tidak ada uniqueness constraint di proto level. Dua company bisa punya code yang sama jika tidak divalidasi di application layer — tapi ini normal karena uniqueness tidak bisa divalidasi di proto.

---

### 3.7 `iam/v1/menu.proto`

**Package**: `iam.v1`  
**Baris**: 345  
**Imports**: `buf/validate`, `common/v1/common.proto`, `google/api/annotations.proto`, **`iam/v1/user.proto`** (untuk `ImportError`, `ActiveFilter`, `Permission`)  

#### Service: MenuService (14 RPCs)

| RPC | HTTP | Endpoint |
|-----|------|----------|
| `CreateMenu` | POST | `/api/v1/iam/menus` |
| `GetMenu` | GET | `/api/v1/iam/menus/{menu_id}` |
| `UpdateMenu` | PUT | `/api/v1/iam/menus/{menu_id}` |
| `DeleteMenu` | DELETE | `/api/v1/iam/menus/{menu_id}` |
| `ListMenus` | GET | `/api/v1/iam/menus` |
| `ExportMenus` | GET | `/api/v1/iam/menus/export` |
| `ImportMenus` | POST | `/api/v1/iam/menus/import` |
| `DownloadMenuTemplate` | GET | `/api/v1/iam/menus/template` |
| `GetMenuTree` | GET | `/api/v1/iam/menus/tree` |
| `GetFullMenuTree` | GET | `/api/v1/iam/menus/tree/full` |
| `AssignMenuPermissions` | POST | `/api/v1/iam/menus/{menu_id}/permissions` |
| `RemoveMenuPermissions` | POST | `/api/v1/iam/menus/{menu_id}/permissions/remove` |
| `GetMenuPermissions` | GET | `/api/v1/iam/menus/{menu_id}/permissions` |
| `ReorderMenus` | POST | `/api/v1/iam/menus/reorder` |

#### Messages Kunci

```
MenuLevel enum:
  MENU_LEVEL_UNSPECIFIED = 0
  MENU_LEVEL_ROOT = 1      (Level 1: Dashboard, Finance)
  MENU_LEVEL_PARENT = 2    (Level 2: Master, Transaction)
  MENU_LEVEL_CHILD = 3     (Level 3: UOM, Parameter)

Menu:
  menu_id, parent_id (optional), menu_code, menu_title
  menu_url (optional), icon_name, service_name
  menu_level: MenuLevel, sort_order: int32
  is_visible, is_active
  audit: AuditInfo (field 12)

MenuWithChildren:           ← RECURSIVE
  menu: Menu
  children: repeated MenuWithChildren
  required_permissions: repeated string
```

#### Temuan

**[TEMUAN M-1] `GetMenuTree` vs `GetFullMenuTree` — tidak perlu dua endpoint terpisah**  
`GetMenuTree` difilter berdasarkan permission user (dari JWT context), sedangkan `GetFullMenuTree` adalah untuk admin management (tidak difilter, dengan `include_inactive` dan `include_hidden` flags). Keduanya bisa disatukan dengan parameter `filtered: bool` atau `admin_view: bool`, tapi desain saat ini tidak salah — hanya bisa lebih clean.

**[TEMUAN M-2] `icon_name` tidak divalidasi terhadap whitelist Lucide icons**  
```protobuf
string icon_name = 5 [(buf.validate.field).string = {min_len: 1, max_len: 50}];
```
Tidak ada constraint bahwa `icon_name` harus valid Lucide icon name. Developer bisa memasukkan `"InvalidIcon"` dan proto tidak akan reject. Ini harus divalidasi di application layer.

**[TEMUAN M-3] `ImportMenusRequest` tidak ada `file_name` pattern — sama dengan pattern inkonsistensi**  
Tidak ada `pattern: "^[^/\\\\]+\\.(xlsx|xls)$"` pada field `file_name`.

**[TEMUAN M-4] `ReorderMenusRequest` tidak memvalidasi bahwa semua `menu_ids` adalah siblings**  
```protobuf
message ReorderMenusRequest {
  optional string parent_id = 1;
  repeated string menu_ids = 2 [(buf.validate.field).repeated.min_items = 1];
}
```
Proto tidak bisa memvalidasi bahwa semua menu dalam `menu_ids` adalah anak dari `parent_id` yang sama. Validasi ini harus di application layer.

**[TEMUAN M-5] `Menu` menggunakan `import "iam/v1/user.proto"` untuk `Permission` tapi tidak punya `Permission` fields sendiri**  
`GetMenuPermissionsResponse` mengembalikan `repeated Permission`, dan `Permission` didefinisikan di `user.proto`. Ini memperkuat coupling yang sudah disebutkan di temuan R-3.

**Hal yang sudah benar**:
- `MenuLevel` enum dengan `UNSPECIFIED = 0` ✅
- `defined_only: true, not_in: [0]` pada `menu_level` di CreateRequest ✅
- `cascade: bool` pada `DeleteMenuRequest` untuk cascading delete ✅
- `DeleteMenuResponse.deleted_count` untuk transparansi operasi cascade ✅
- Pemisahan `GetMenuTree` (user-facing) dan `GetFullMenuTree` (admin) ✅

---

### 3.8 `iam/v1/session.proto`

**Package**: `iam.v1`  
**Baris**: 97  
**Imports**: `buf/validate`, `common/v1/common.proto`, `google/api/annotations.proto`  

#### Service: SessionService (3 RPCs)

| RPC | HTTP | Endpoint |
|-----|------|----------|
| `GetCurrentSession` | GET | `/api/v1/iam/sessions/current` |
| `RevokeSession` | POST | `/api/v1/iam/sessions/{session_id}/revoke` |
| `ListActiveSessions` | GET | `/api/v1/iam/sessions` |

#### Temuan

**[TEMUAN S-1] Tidak ada `RevokeAllSessions` RPC**  
Untuk use case "logout from all devices" atau "force logout user" (security breach scenario), tidak ada endpoint yang bisa melakukan bulk revoke. Saat ini admin hanya bisa revoke satu session per request.

**[TEMUAN S-2] `Session.created_at` dan `expires_at` adalah string bukan timestamp**  
Sama dengan temuan C-2. Plain string tanpa type safety untuk format datetime.

**[TEMUAN S-3] `Session.service_name` — multi-service session tracking tidak terdokumentasi**  
Field `service_name` mengimplikasikan bahwa satu user bisa punya sessions di multiple services. Bagaimana cross-service session sharing bekerja tidak terdokumentasi di proto comment.

**[TEMUAN S-4] `ListActiveSessions` tidak bisa difilter by `ip_address`**  
Untuk security audit (e.g., "tampilkan semua session dari IP tertentu"), tidak ada filter ini. Berguna untuk mendeteksi session hijacking.

---

### 3.9 `iam/v1/audit.proto`

**Package**: `iam.v1`  
**Baris**: 210  
**Imports**: `buf/validate`, `common/v1/common.proto`, `google/api/annotations.proto`  

#### Service: AuditService (4 RPCs — read only)

| RPC | HTTP | Endpoint |
|-----|------|----------|
| `GetAuditLog` | GET | `/api/v1/iam/audit-logs/{log_id}` |
| `ListAuditLogs` | GET | `/api/v1/iam/audit-logs` |
| `ExportAuditLogs` | GET | `/api/v1/iam/audit-logs/export` |
| `GetAuditSummary` | GET | `/api/v1/iam/audit-logs/summary` |

#### Temuan

**[TEMUAN AU-1] `GetAuditSummaryRequest.time_range` sebagai string dengan `in` constraint — seharusnya enum**  
```protobuf
// Saat ini:
string time_range = 1 [(buf.validate.field).string = {
  in: ["today", "week", "month", "year"]
}];

// Lebih baik sebagai enum:
enum TimeRange {
  TIME_RANGE_UNSPECIFIED = 0;
  TIME_RANGE_TODAY = 1;
  TIME_RANGE_WEEK = 2;
  TIME_RANGE_MONTH = 3;
  TIME_RANGE_YEAR = 4;
}
```

**[TEMUAN AU-2] `AuditLog.old_data`, `new_data`, `changes` sebagai JSON string**  
Tiga field ini menyimpan JSON serialized data sebagai `optional string`. Tidak ada schema enforcement, bisa berisi JSON tidak valid, dan menyulitkan querying/parsing di client.

**[TEMUAN AU-3] `ListAuditLogsRequest.date_from` dan `date_to` tidak ada format validation**  
```protobuf
string date_from = 8;  // Tidak ada pattern validation
string date_to = 9;    // Tidak ada pattern validation
```
Bisa menerima nilai apapun. Setidaknya perlu pattern ISO 8601 atau menggunakan `google.protobuf.Timestamp`.

**[TEMUAN AU-4] Tidak ada `WriteAuditLog` RPC — bagaimana audit ditulis?**  
`AuditService` adalah read-only. Berarti audit logging dilakukan secara internal di setiap service (business logic masing-masing service yang menulis ke audit log). Ini adalah keputusan design yang valid (tidak perlu proto contract untuk internal writes), tapi perlu terdokumentasi bahwa ini bukan oversight.

**[TEMUAN AU-5] Tidak ada `DeleteAuditLogs` atau `PurgeAuditLogs`**  
Untuk compliance (data retention policy, GDPR), mungkin perlu kemampuan untuk menghapus audit logs berdasarkan umur. Saat ini tidak ada endpoint ini.

**Hal yang sudah benar**:
- `EventType` enum dengan 12 nilai termasuk auth events ✅
- `AuditSummary` dengan `top_users` dan `events_by_hour` untuk dashboard ✅
- `HourlyCount` message untuk chart visualization ✅
- Filter lengkap di `ListAuditLogsRequest` (event_type, user_id, date range, service) ✅

---

## 4. Analisis Layer Tengah: Konfigurasi Buf

### 4.1 `buf.yaml`

```yaml
version: v2
modules:
  - path: .
    name: buf.build/goapps/shared-proto
breaking:
  use: [FILE]
lint:
  use: [STANDARD]
  except:
    - PACKAGE_VERSION_SUFFIX
deps:
  - buf.build/googleapis/googleapis
  - buf.build/bufbuild/protovalidate
```

**Temuan**:

**[TEMUAN BUF-1] `PACKAGE_VERSION_SUFFIX` di-except — intentional tapi perlu dokumentasi**  
Buf STANDARD lint mewajibkan package name berakhir dengan version suffix (e.g., `finance.v1` harus jadi `financev1` atau package path harus match). Karena kita pakai `finance.v1` (dengan titik), lint rule ini di-except. Ini valid tapi perlu komentar di `buf.yaml` menjelaskan alasannya.

**[TEMUAN BUF-2] Tidak ada `lint.ignore` untuk file-file yang memang perlu exception**  
Jika ada file tertentu yang butuh exception specific rule, belum ada mekanisme per-file exception.

**[TEMUAN BUF-3] `breaking: use: [FILE]` adalah level paling kasar**  
`FILE` level berarti breaking change check di level perubahan file. Tersedia opsi yang lebih granular: `PACKAGE`, `WIRE_JSON`, `WIRE`. Untuk production, `WIRE_JSON` atau `WIRE` lebih appropriate.

### 4.2 `buf.gen.yaml`

```yaml
version: v2
managed:
  enabled: true
  override:
    - file_option: go_package_prefix
      value: github.com/mutugading/goapps-backend/gen
      path: .
plugins:
  - remote: buf.build/protocolbuffers/go
  - remote: buf.build/grpc/go
  - remote: buf.build/grpc-ecosystem/gateway
  - remote: buf.build/grpc-ecosystem/openapiv2
    out: ../goapps-backend/gen/openapi
```

**Temuan**:

**[TEMUAN BUF-4] Semua plugin menggunakan `remote` — memerlukan internet dan buf registry access**  
Jika buf.build registry down atau jaringan terbatas, generate akan gagal. Untuk CI yang stabil, lebih baik menggunakan versi yang di-pin atau menggunakan local plugin.

**[TEMUAN BUF-5] `go_package_prefix` masih berisi `github.com/mutugading/goapps-backend` tapi komentar lain menyebut `github.com/ilramdhan/goapps-backend`**  
Ada inkonsistensi nama organisasi GitHub. Di `buf.gen.yaml` baris 14: `github.com/mutugading/goapps-backend`, sedangkan di comment yang di-disable di `common.proto` baris 6: `github.com/ilramdhan/goapps-backend`. Perlu dikonfirmasi nama organisasi yang benar.

**[TEMUAN BUF-6] Tidak ada plugin versioning yang eksplisit di `buf.gen.yaml`**  
Remote plugins tanpa versi eksplisit akan menggunakan `latest`, yang bisa menyebabkan breaking generate jika plugin update.

### 4.3 `buf.gen.ts.yaml`

```yaml
plugins:
  - local: protoc-gen-ts_proto
    out: ../goapps-frontend/src/types/generated
    opt:
      - esModuleInterop=true
      - outputJsonMethods=true
      - useExactTypes=false
      - snakeToCamel=true
      - outputServices=generic-definitions
```

**Temuan**:

**[TEMUAN BUF-7] `useExactTypes=false` — TypeScript types menjadi lebih permissive**  
Dengan `useExactTypes=false`, generated types menggunakan `string | undefined` alih-alih exact literal types. Untuk production-grade TypeScript, `useExactTypes=true` lebih strict dan safer.

**[TEMUAN BUF-8] `outputServices=generic-definitions` — tidak compatible dengan grpc-web langsung**  
Opsi ini generate generic interface, bukan grpc-web specific client. Frontend harus implement sendiri client dari interface tersebut. Ini bukan bug tapi perlu terdokumentasi bahwa frontend menggunakan REST (via gateway) bukan gRPC-web.

**[TEMUAN BUF-9] `snakeToCamel=true` — field names di TypeScript berbeda dari proto**  
`uom_id` di proto → `uomId` di TypeScript. Ini adalah behavior yang diharapkan, tapi developer harus selalu ingat konversi ini saat bekerja di kedua sisi.

### 4.4 `buf.lock`

Dependency pinned ke commit dan digest spesifik — **ini sudah benar** untuk reproducible builds.

---

## 5. Analisis Layer Menengah: Scripts

### 5.1 `scripts/gen-go.sh`

```bash
set -e
buf dep update
buf format -w
buf lint
buf generate
cd ../goapps-backend/gen
go mod tidy
```

**Temuan**:

**[TEMUAN SCR-1] Asumsi `../goapps-backend/gen` sudah ada `go.mod`**  
Script tidak check apakah directory ini exists dan memiliki `go.mod`. Akan fail dengan error yang tidak jelas jika struktur direktori tidak sesuai.

**[TEMUAN SCR-2] `buf format -w` dapat membuat dirty working tree**  
Jika proto files diformat (indentation, spacing), working tree menjadi dirty. Script tidak memperingatkan tentang ini, yang bisa mengejutkan developer yang baru belajar workflow.

### 5.2 `scripts/gen-ts.sh`

**Temuan**:

**[TEMUAN SCR-3] Tidak ada versioning check untuk `protoc-gen-ts_proto`**  
Script hanya check existence, bukan versi. Jika versi ts-proto berbeda antara developer, generated code bisa berbeda.

**[TEMUAN SCR-4] `find "$OUTPUT_DIR" -name "*.ts" | head -20` — output truncated**  
`head -20` hanya menampilkan 20 file pertama. Untuk debugging, lebih berguna menampilkan total count.

### 5.3 `scripts/gen-all.sh`

Sequential: `gen-go.sh` → `gen-ts.sh`. Tidak ada mekanisme untuk run hanya salah satu yang berhasil jika satunya gagal.

---

## 6. Analisis Layer Luar: CI/CD Pipeline

### 6.1 `.github/workflows/ci.yml`

```yaml
jobs:
  lint-and-check:          # Trigger: push/PR ke main
    steps:
      - buf lint
      - buf breaking --against 'https://github.com/mutugading/goapps-shared-proto.git#branch=main'

  generate:                # Trigger: HANYA push ke main (bukan PR)
    needs: lint-and-check
    steps:
      - checkout goapps-backend (dengan PAT_TOKEN)
      - buf generate
      - git push ke goapps-backend/gen/
```

**Temuan**:

**[TEMUAN CI-1] TypeScript TIDAK di-generate di CI**  
`buf generate --template buf.gen.ts.yaml` tidak ada di CI. Frontend TypeScript types hanya bisa di-generate manual via `gen-ts.sh`. Ini berarti frontend developer bisa ketinggalan types terbaru jika tidak run manual.

**[TEMUAN CI-2] `buf breaking` menggunakan HTTPS URL publik — bisa fail untuk repo privat**  
```yaml
buf breaking --against 'https://github.com/mutugading/goapps-shared-proto.git#branch=main'
```
Jika repository ini privat dan tidak ada token, command ini akan fail. Untuk repo privat lebih aman menggunakan:
```yaml
buf breaking --against '.git#branch=main'  # Local git history
```

**[TEMUAN CI-3] `secrets.PAT_TOKEN` single point of failure**  
Jika PAT_TOKEN expired atau owner akun dihapus/revoked, seluruh generate job akan gagal. Tidak ada alerting mechanism untuk ini.

**[TEMUAN CI-4] Tidak ada caching untuk buf dependencies**  
Setiap CI run fresh install deps. Dengan buf caching (`actions/cache`), ini bisa lebih cepat.

**[TEMUAN CI-5] Tidak ada job untuk verify generated code compiles**  
Setelah generate, tidak ada step `go build` atau `tsc` untuk memverifikasi generated code bisa dikompilasi dengan benar.

**[TEMUAN CI-6] Tidak ada semantic versioning / git tagging**  
Tidak ada workflow untuk auto-tag version (e.g., `v1.2.3`) saat merge ke main. Consumer tidak bisa pin ke versi spesifik.

**[TEMUAN CI-7] `generate` job commit langsung ke `goapps-backend` tanpa PR**  
Generated code di-commit dan di-push langsung ke `goapps-backend` tanpa review process. Jika generate output ada bug, langsung masuk ke main branch backend.

---

## 7. Analisis Layer Terluar: Dokumentasi & Governance

### 7.1 `RULES.md` (614 baris)

Dokumentasi sangat komprehensif mencakup: Golden Rules, File Organization, Naming Conventions, Message Design, Field Numbering, Validation Rules, Service Design, REST API Mapping, Documentation, Breaking Changes, Git Workflow, Review Checklist.

**Temuan**:

**[TEMUAN DOC-1] RULES.md menyebutkan `audit` harus di field 16-20 tapi implementasi menggunakan 6-8**  
Baris 212-213:
```
// Audit/metadata: 16-20
common.v1.AuditInfo audit = 16;
```
Tapi semua entity menggunakan field number 6-8 untuk audit. RULES.md tidak sinkron dengan implementasi aktual.

**[TEMUAN DOC-2] RULES.md menyebutkan `string.email = true` tersedia tapi tidak digunakan di implementasi**  
Baris 324: `string email = 1 [(buf.validate.field).string.email = true];`  
Implementasi aktual menggunakan custom regex. Perlu pilih satu cara dan konsisten.

**[TEMUAN DOC-3] RULES.md menyebut `hr` domain tapi tidak ada proto untuk HR**  
Tabel file organization (baris 118-122) menyebut `hr/v1/employee.proto` sebagai contoh. Domain HR belum ada proto-nya.

### 7.2 `README.md` (~596 baris)

Sangat lengkap mencakup: quick start, module structure, code generation, proto conventions, contribution guide, service catalog, link ke semua resource.

**Temuan**:

**[TEMUAN DOC-4] Service catalog di README mungkin tidak up-to-date**  
Seiring penambahan service baru, README perlu diupdate manual. Tidak ada automation untuk ini.

### 7.3 `.github/PULL_REQUEST_TEMPLATE.md`

Sangat baik: 8-item pre-merge checklist, impact assessment, breaking change analysis section.

**Temuan**:

**[TEMUAN DOC-5] PR template masih menyebut hanya `finance/v1/uom.proto` di example list**  
Perlu diupdate untuk mencerminkan semua domain yang sudah ada (iam, common, finance).

### 7.4 Issue Templates

Sangat baik: `bug_report.md`, `new_service.md`, `proto_change.md` semuanya detail dan structured. `config.yml` memaksa penggunaan template (`blank_issues_enabled: false`).

---

## 8. Analisis Pola Arsitektur Lintas-File

### 8.1 Pola yang Digunakan (Konsisten)

**a. Request/Response Dedicated Message Pattern** ✅  
Setiap RPC memiliki dedicated request dan response message. Tidak ada message sharing antar RPC.

**b. BaseResponse Wrapper Pattern** ✅  
Semua response menggunakan `common.v1.BaseResponse base = 1` di field pertama.

**c. Optional Fields for Partial Update** ✅  
Semua `Update*Request` menggunakan `optional` keyword untuk field yang bisa diubah.

**d. Import/Export/Template Trio** ✅  
Semua service master data memiliki trio: `Export*`, `Import*`, `DownloadTemplate`.

**e. Soft Delete Pattern** ✅  
`Delete*` hanya mengubah status `is_active`, tidak menghapus data fisik.

**f. Enum Zero = UNSPECIFIED = No Filter** ✅  
Semua enum memiliki `*_UNSPECIFIED = 0` yang digunakan sebagai "no filter" dalam list requests.

### 8.2 Pola yang Belum Konsisten (Cross-File Issues)

**a. `ImportError` dan `ActiveFilter` — tidak di-centralize** ❌  
Duplikat di `finance/v1/uom.proto` dan `iam/v1/user.proto`. Harusnya di `common/v1/common.proto`.

**b. `file_name` pattern validation — tidak konsisten** ❌  
`uom.proto` punya pattern `^[^/\\]+\.(xlsx|xls)$`, semua file lain tidak punya.

**c. Import filter UUID validation — tidak konsisten** ❌  
`ExportUsersRequest` tidak ada UUID validation untuk filter IDs, tapi `ListUsersRequest` ada.

**d. `Permission` message — defined in wrong file** ❌  
`Permission` didefinisikan di `user.proto` tapi digunakan di `role.proto`, `menu.proto`, `organization.proto`.

---

## 9. Inventaris Lengkap: Services, RPCs, Messages

### 9.1 Semua Services dan RPCs

| Domain | File | Service | RPC Count |
|--------|------|---------|-----------|
| `common.v1` | common.proto | — | 0 |
| `finance.v1` | uom.proto | `UOMService` | 8 |
| `iam.v1` | auth.proto | `AuthService` | 11 |
| `iam.v1` | user.proto | `UserService` | 15 |
| `iam.v1` | role.proto | `RoleService` | 11 |
| `iam.v1` | role.proto | `PermissionService` | 9 |
| `iam.v1` | organization.proto | `CompanyService` | 8 |
| `iam.v1` | organization.proto | `DivisionService` | 8 |
| `iam.v1` | organization.proto | `DepartmentService` | 8 |
| `iam.v1` | organization.proto | `SectionService` | 8 |
| `iam.v1` | organization.proto | `OrganizationService` | 1 |
| `iam.v1` | menu.proto | `MenuService` | 14 |
| `iam.v1` | session.proto | `SessionService` | 3 |
| `iam.v1` | audit.proto | `AuditService` | 4 |
| **TOTAL** | **9 files** | **13 services** | **108 RPCs** |

### 9.2 Semua REST Endpoints (108 total)

**finance.v1 — UOMService (8 endpoints)**
```
POST   /api/v1/finance/uoms
GET    /api/v1/finance/uoms/{uom_id}
PUT    /api/v1/finance/uoms/{uom_id}
DELETE /api/v1/finance/uoms/{uom_id}
GET    /api/v1/finance/uoms
GET    /api/v1/finance/uoms/export
POST   /api/v1/finance/uoms/import
GET    /api/v1/finance/uoms/template
```

**iam.v1 — AuthService (11 endpoints)**
```
POST /api/v1/iam/auth/login
POST /api/v1/iam/auth/logout
POST /api/v1/iam/auth/refresh
POST /api/v1/iam/auth/forgot-password
POST /api/v1/iam/auth/verify-otp
POST /api/v1/iam/auth/reset-password
POST /api/v1/iam/auth/update-password
POST /api/v1/iam/auth/2fa/enable
POST /api/v1/iam/auth/2fa/verify
POST /api/v1/iam/auth/2fa/disable
GET  /api/v1/iam/auth/me
```

**iam.v1 — UserService (15 endpoints)**
```
POST   /api/v1/iam/users
GET    /api/v1/iam/users/{user_id}
GET    /api/v1/iam/users/{user_id}/detail
PUT    /api/v1/iam/users/{user_id}
PUT    /api/v1/iam/users/{user_id}/detail
DELETE /api/v1/iam/users/{user_id}
GET    /api/v1/iam/users
GET    /api/v1/iam/users/export
POST   /api/v1/iam/users/import
GET    /api/v1/iam/users/template
POST   /api/v1/iam/users/{user_id}/roles
POST   /api/v1/iam/users/{user_id}/roles/remove
POST   /api/v1/iam/users/{user_id}/permissions
POST   /api/v1/iam/users/{user_id}/permissions/remove
GET    /api/v1/iam/users/{user_id}/access
```

**iam.v1 — RoleService (11 endpoints)**
```
POST   /api/v1/iam/roles
GET    /api/v1/iam/roles/{role_id}
PUT    /api/v1/iam/roles/{role_id}
DELETE /api/v1/iam/roles/{role_id}
GET    /api/v1/iam/roles
GET    /api/v1/iam/roles/export
POST   /api/v1/iam/roles/import
GET    /api/v1/iam/roles/template
POST   /api/v1/iam/roles/{role_id}/permissions
POST   /api/v1/iam/roles/{role_id}/permissions/remove
GET    /api/v1/iam/roles/{role_id}/permissions
```

**iam.v1 — PermissionService (9 endpoints)**
```
POST   /api/v1/iam/permissions
GET    /api/v1/iam/permissions/{permission_id}
PUT    /api/v1/iam/permissions/{permission_id}
DELETE /api/v1/iam/permissions/{permission_id}
GET    /api/v1/iam/permissions
GET    /api/v1/iam/permissions/export
POST   /api/v1/iam/permissions/import
GET    /api/v1/iam/permissions/template
GET    /api/v1/iam/permissions/by-service
```

**iam.v1 — Organization Services (33 endpoints)**  
*(8 per CompanyService/DivisionService/DepartmentService/SectionService + 1 OrganizationService)*

**iam.v1 — MenuService (14 endpoints)**  
**iam.v1 — SessionService (3 endpoints)**  
**iam.v1 — AuditService (4 endpoints)**

---

## 10. Temuan Kritis: Bug & Inkonsistensi

### [BUG-1] Permission Code Regex Mismatch dengan Contoh di Comment

**File**: `iam/v1/role.proto` baris 279-295  
**Severity**: 🔴 Critical  

```protobuf
// Comment: "e.g., finance.master.uom.view, iam.user.create"
//           ↑ 4 segment ✅              ↑ 3 segment ❌

// Regex yang digunakan (4 segment mandatory):
pattern: "^[a-z][a-z0-9]*\\.[a-z][a-z0-9]*\\.[a-z][a-z0-9]*\\.[a-z]+$"
```

`iam.user.create` tidak cocok dengan regex karena hanya 3 segment. Developer yang mengikuti contoh di comment akan mendapatkan validation error di runtime.

**Solusi**: Update regex ke 3 segment minimum ATAU update semua contoh ke format 4-segment yang konsisten.

### [BUG-2] Duplikasi `ActiveFilter` di Dua Package Berbeda

**File**: `finance/v1/uom.proto` baris 31-38 DAN `iam/v1/user.proto` baris 15-23  
**Severity**: 🟠 High  

Dua definisi identik. Seiring waktu, jika satu diupdate dan lainnya tidak, akan ada divergence.

### [BUG-3] Duplikasi `ImportError` di Dua Package Berbeda

**File**: `finance/v1/uom.proto` baris 282-290 DAN `iam/v1/user.proto` baris 505-513  
**Severity**: 🟠 High  

Sama dengan BUG-2.

### [BUG-4] `file_name` Pattern Validation Inkonsisten

**File**: `uom.proto` ada pattern `^[^/\\\\]+\\.(xlsx|xls)$`, semua file lain tidak ada  
**Severity**: 🟠 High  

Terdampak: `ImportRolesRequest`, `ImportPermissionsRequest`, `ImportUsersRequest`, `ImportCompaniesRequest`, `ImportDivisionsRequest`, `ImportDepartmentsRequest`, `ImportSectionsRequest`, `ImportMenusRequest`.

### [BUG-5] `VerifyResetOTPRequest.email` Tidak Ada Format Validation

**File**: `iam/v1/auth.proto` baris 255-264  
**Severity**: 🟡 Medium  

Inkonsisten dengan `ForgotPasswordRequest.email` yang ada regex validation.

---

## 11. Temuan Sedang: Design Gaps

### [GAP-1] `PaginationRequest` Ada Tapi Tidak Digunakan
Definisi ada di `common.proto`, tapi tidak dipakai di mana pun. Ini menjadi dead code.

### [GAP-2] Tidak Ada `google.protobuf.Timestamp` untuk Datetime
Semua datetime menggunakan `string`. Risiko: tidak ada type safety, format inconsistency.

### [GAP-3] `Permission` Message Didefinisikan di File yang Salah
`Permission` (basic) ada di `user.proto`, `PermissionDetail` ada di `role.proto`. Kedua entity ini seharusnya di `role.proto` saja (karena Permission adalah domain Role, bukan User). User hanya menggunakan Permission melalui Role.

### [GAP-4] Tidak Ada `RevokeAllSessions` RPC
Security gap: tidak ada cara untuk revoke semua session user sekaligus.

### [GAP-5] `OrganizationNode.type` sebagai `string`
Seharusnya enum untuk type safety. Nilai "company"/"division"/"department"/"section" tidak enforce di proto level.

### [GAP-6] `CreateUserRequest.role_ids` Tidak Ada Per-Item UUID Validation
Field `repeated string role_ids = 13` tidak divalidasi sebagai UUID per item.

### [GAP-7] `Role.user_count` dan `PermissionDetail.role_count` Denormalized
Nilai computed yang bisa stale. Tidak ada dokumentasi tentang konsistensinya.

### [GAP-8] TypeScript Generation Tidak Ada di CI
Frontend developer harus generate manual. Berisiko ketinggalan types terbaru.

---

## 12. Temuan Ringan: Polish & Consistency

### [POLISH-1] `AuditInfo` Tidak Punya `deleted_at`/`deleted_by` untuk Soft Delete Tracking
Berguna untuk compliance audit — siapa yang melakukan soft delete dan kapan.

### [POLISH-2] `GetUser` vs `GetUserDetail` — Redundansi Endpoint
Dua endpoint untuk data yang sering dibutuhkan bersama. Frontend hampir selalu butuh `GetUserDetail`.

### [POLISH-3] `ExportUsersRequest` Filter IDs Tidak Ada UUID Validation
Tidak konsisten dengan `ListUsersRequest` yang sudah ada UUID validation untuk filter IDs.

### [POLISH-4] `GetAuditSummaryRequest.time_range` Seharusnya Enum
String dengan `in` constraint adalah anti-pattern. Enum lebih idiomatic dan type-safe.

### [POLISH-5] `ImportRolesRequest` dan `ImportPermissionsRequest` Tidak Ada File Name Pattern
Inkonsistensi dengan `ImportUOMsRequest`.

### [POLISH-6] RULES.md `audit` Field Range (16-20) Berbeda dari Implementasi (6-8)
Dokumentasi tidak sinkron dengan kode aktual.

### [POLISH-7] `buf.gen.yaml` `go_package_prefix` Ada Inkonsistensi Nama Org
`mutugading` vs `ilramdhan` di comment `common.proto`.

### [POLISH-8] `buf breaking: use: [FILE]` — Bisa Lebih Granular
`WIRE_JSON` atau `WIRE` level lebih appropriate untuk production.

### [POLISH-9] `LogoutRequest.refresh_token` Optional — Semantik Tidak Jelas
Comment tidak cukup jelas tentang bagaimana "current session" ditentukan jika tidak ada refresh_token.

### [POLISH-10] CI `buf breaking` Menggunakan HTTPS GitHub URL — Tidak Ideal untuk Private Repo
Lebih baik menggunakan local git history: `'.git#branch=main'`.

---

## 13. Analisis Kelengkapan Domain vs ERD

Berdasarkan `.docs/erd-mermaid.md`, berikut perbandingan antara yang sudah ada proto dan yang belum:

### Domain yang Sudah Di-proto-kan

| Domain | Tabel di ERD | Status Proto |
|--------|-------------|--------------|
| IAM Users | `USR_USER`, `USR_USER_DETAIL` | ✅ Lengkap |
| IAM Auth | — (business logic) | ✅ Lengkap |
| IAM Roles & Permissions | `USR_ROLE`, `USR_PERMISSION`, `USR_ROLE_PERMISSION`, `USR_USER_ROLE`, `USR_USER_PERMISSION` | ✅ Lengkap |
| IAM Organization | `ORG_COMPANY`, `ORG_DIVISION`, `ORG_DEPARTMENT`, `ORG_SECTION` | ✅ Lengkap |
| IAM Menu | `ORG_MENU`, `ORG_MENU_PERMISSION` | ✅ Lengkap |
| IAM Session | — (Redis/cache) | ✅ Lengkap |
| IAM Audit | `AUD_EVENT_LOG` | ✅ Lengkap |
| Finance UOM | `MST_UOM` | ✅ Lengkap |

### Domain yang Ada di ERD tapi BELUM Ada Proto

| Domain | Tabel ERD | Priority |
|--------|-----------|----------|
| Finance Currency | `MST_CURRENCY`, `MST_EXCHANGE_RATE` | 🟠 High |
| Production Process Master | `MST_PROCESS`, `MST_PARAMETER`, `MST_PROCESS_PARAM` | 🟠 High |
| Production Formula | `MST_FORMULA`, `MST_PROCESS_FORMULA` | 🟠 High |
| Production Raw Material | `MST_RM_CATEGORY`, `MST_RM_ITEM` | 🟠 High |
| Production Template | `PRD_TEMPLATE`, `PRD_TEMPLATE_ROUTING`, `PRD_TEMPLATE_PARAM`, `PRD_TEMPLATE_FORMULA` | 🔴 Critical (core business) |
| Production Product | `PRD_PRODUCT`, `PRD_PRODUCT_ROUTING`, `PRD_PRODUCT_PROCESS`, `PRD_PRODUCT_RM` | 🔴 Critical (core business) |
| Transaction | `TRX_PARAM_REQUEST`, `TRX_PARAM_REQUEST_DETAIL` | 🟠 High |
| Costing | `CST_PERIOD`, `CST_RM_PRICE`, `CST_PARAM_RATE` | 🟠 High |
| Calculation | `CAL_JOB`, `CAL_JOB_DETAIL`, `CAL_PRODUCT_COST`, `CAL_PROCESS_COST`, `CAL_RM_COST` | 🔴 Critical (core business) |
| Audit History | `AUD_COST_HISTORY`, `AUD_PRODUCT_HISTORY` | 🟡 Medium |

**Estimasi kelengkapan**: ~15% dari total domain bisnis yang direncanakan.

---

## 14. Scorecard Kualitas Keseluruhan

| Kategori | Score | Keterangan |
|----------|-------|------------|
| **Naming Conventions** | 9/10 | Sangat konsisten, snake_case, PascalCase |
| **Validation Coverage** | 7/10 | Hampir semua field, ada beberapa gap |
| **Documentation/Comments** | 8/10 | Field comments lengkap, service docs cukup |
| **REST Mapping** | 9/10 | Konsisten, ikuti Google API Design Guide |
| **Breaking Change Safety** | 8/10 | buf lint + CI check, field numbers stable |
| **Type Reusability** | 5/10 | `ActiveFilter`/`ImportError` duplikat, `PaginationRequest` tidak dipakai |
| **Cross-file Coupling** | 5/10 | `role.proto`, `menu.proto`, `org.proto` import `user.proto` tidak perlu |
| **Timestamp Type Safety** | 4/10 | Semua string, tidak ada `Timestamp` |
| **Security Design** | 8/10 | 2FA, session management, permission-based menu |
| **CI/CD Completeness** | 6/10 | Lint + generate Go, tapi tidak TypeScript |
| **Tooling (Buf)** | 9/10 | Modern Buf v2, managed mode, buf.lock |
| **Domain Completeness** | 2/10 | ~15% dari total domain bisnis |
| **RATA-RATA** | **6.7/10** | Fondasi solid, needs production hardening |

---

*Dokumen ini adalah hasil analisis statis terhadap source code repository. Semua temuan berdasarkan kode aktual yang dibaca, bukan asumsi. Untuk detail improvement plan, lihat `IMPROVEMENT_PLAN.md`.*
