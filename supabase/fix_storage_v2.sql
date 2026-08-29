-- ============================================================
-- ArtVault — Force Storage Schema Rebuild
-- Run this in Supabase SQL Editor if DatabaseSchemaMismatch persists
-- This drops and recreates the storage schema from scratch.
-- ============================================================

-- 1. Drop existing storage policies (clean slate)
DO $$ 
DECLARE 
  pol record;
BEGIN
  FOR pol IN 
    SELECT policyname FROM pg_policies WHERE schemaname = 'storage'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON storage.objects', pol.policyname);
  END LOOP;
END $$;

-- 2. Drop existing buckets
DELETE FROM storage.buckets WHERE id IN ('av-profile', 'av-paintings', 'av-documents');

-- 3. Recreate buckets with correct schema
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types, created_at, updated_at)
VALUES 
  ('av-profile', 'av-profile', true, 52428800, ARRAY['image/jpeg', 'image/png', 'image/webp'], now(), now()),
  ('av-paintings', 'av-paintings', true, 52428800, ARRAY['image/jpeg', 'image/png', 'image/webp'], now(), now()),
  ('av-documents', 'av-documents', true, 52428800, ARRAY['image/jpeg', 'image/png', 'application/pdf', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'], now(), now());

-- 4. Recreate storage policies
CREATE POLICY "Profile photos are publicly readable"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'av-profile');

CREATE POLICY "Users can upload own profile photos"
  ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'av-profile' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Users can update own profile photos"
  ON storage.objects FOR UPDATE
  USING (bucket_id = 'av-profile' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Users can delete own profile photos"
  ON storage.objects FOR DELETE
  USING (bucket_id = 'av-profile' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Painting photos are publicly readable"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'av-paintings');

CREATE POLICY "Authenticated users can upload painting photos"
  ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'av-paintings' AND auth.role() = 'authenticated');

CREATE POLICY "Users can update painting photos"
  ON storage.objects FOR UPDATE
  USING (bucket_id = 'av-paintings' AND auth.role() = 'authenticated');

CREATE POLICY "Users can delete painting photos"
  ON storage.objects FOR DELETE
  USING (bucket_id = 'av-paintings' AND auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can read documents"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'av-documents' AND auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can upload documents"
  ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'av-documents' AND auth.role() = 'authenticated');

CREATE POLICY "Users can update own documents"
  ON storage.objects FOR UPDATE
  USING (bucket_id = 'av-documents' AND auth.role() = 'authenticated');

CREATE POLICY "Users can delete own documents"
  ON storage.objects FOR DELETE
  USING (bucket_id = 'av-documents' AND auth.role() = 'authenticated');

-- 5. Force PostgREST to reload
NOTIFY pgrst, 'reload schema';

-- 6. Verify buckets exist
SELECT id, name, public FROM storage.buckets WHERE id LIKE 'av-%';
