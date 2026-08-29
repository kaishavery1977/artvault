-- ============================================================
-- ArtVault — Fix Storage Uploads (Run in Supabase SQL Editor)
-- This fixes the DatabaseSchemaMismatch 503 error by ensuring
-- storage buckets and RLS policies exist.
-- ============================================================

-- 1. Create storage buckets (if not already created)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES
  ('av-profile', 'av-profile', true, 52428800, ARRAY['image/jpeg', 'image/png', 'image/webp']),
  ('av-paintings', 'av-paintings', true, 52428800, ARRAY['image/jpeg', 'image/png', 'image/webp']),
  ('av-documents', 'av-documents', true, 52428800, ARRAY['image/jpeg', 'image/png', 'application/pdf', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'])
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

-- 2. Drop existing storage policies (idempotent)
DROP POLICY IF EXISTS "Profile photos are publicly readable" ON storage.objects;
DROP POLICY IF EXISTS "Users can upload own profile photos" ON storage.objects;
DROP POLICY IF EXISTS "Users can update own profile photos" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete own profile photos" ON storage.objects;
DROP POLICY IF EXISTS "Painting photos are publicly readable" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can upload painting photos" ON storage.objects;
DROP POLICY IF EXISTS "Users can update painting photos" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete painting photos" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can read documents" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can upload documents" ON storage.objects;
DROP POLICY IF EXISTS "Users can update own documents" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete own documents" ON storage.objects;

-- 3. Storage policies — av-profile
CREATE POLICY "Profile photos are publicly readable"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'av-profile');

CREATE POLICY "Users can upload own profile photos"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'av-profile'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "Users can update own profile photos"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'av-profile'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "Users can delete own profile photos"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'av-profile'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

-- 4. Storage policies — av-paintings
CREATE POLICY "Painting photos are publicly readable"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'av-paintings');

CREATE POLICY "Authenticated users can upload painting photos"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'av-paintings'
    AND auth.role() = 'authenticated'
  );

CREATE POLICY "Users can update painting photos"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'av-paintings'
    AND auth.role() = 'authenticated'
  );

CREATE POLICY "Users can delete painting photos"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'av-paintings'
    AND auth.role() = 'authenticated'
  );

-- 5. Storage policies — av-documents
CREATE POLICY "Authenticated users can read documents"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'av-documents'
    AND auth.role() = 'authenticated'
  );

CREATE POLICY "Authenticated users can upload documents"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'av-documents'
    AND auth.role() = 'authenticated'
  );

CREATE POLICY "Users can update own documents"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'av-documents'
    AND auth.role() = 'authenticated'
  );

CREATE POLICY "Users can delete own documents"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'av-documents'
    AND auth.role() = 'authenticated'
  );

-- 6. Reload schema
NOTIFY pgrst, 'reload schema';
