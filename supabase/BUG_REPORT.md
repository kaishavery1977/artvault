# Supabase Storage Bug Report

## Project
- **Project Ref:** mtwinlbgvuxezadbsrrl
- **Plan:** Free (Nano compute)
- **Region:** ap-northeast-1 (Tokyo)

## Issue
Storage uploads fail with `DatabaseSchemaMismatch` (HTTP 503) on ALL uploads, regardless of auth method.

## Error Response
```json
{
  "statusCode": 503,
  "error": "DatabaseSchemaMismatch",
  "message": "The database schema is out of sync. Please run migrations or contact support.",
  "code": "DatabaseSchemaMismatch"
}
```

## Reproduction Steps
1. Any upload to any bucket fails with the above error
2. Tested with: anon key, service_role key, authenticated session
3. Tested buckets: av-paintings, av-profile, av-documents

## Bucket Status (List succeeds)
All 3 buckets exist and are listable via GET /storage/v1/bucket:
- av-profile (public, 50MB limit)
- av-paintings (public, 50MB limit)  
- av-documents (public, 50MB limit)

## What Works
- Bucket listing ✅
- DB queries (PostgREST) ✅
- Auth ✅

## What's Broken
- Storage uploads ❌ (DatabaseSchemaMismatch 503)
- Storage downloads ❌ (likely same issue)

## Request
Please run the storage schema migration for this project. The storage extension in the database appears to be out of sync with the Storage API service.
