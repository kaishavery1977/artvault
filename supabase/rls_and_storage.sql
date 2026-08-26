-- ============================================================
-- ArtVault — RLS Policies + Storage Bucket Policies
-- Run this in Supabase SQL Editor after schema.sql
-- ============================================================

-- -----------------------------------------------------------
-- STORAGE BUCKETS
-- -----------------------------------------------------------
INSERT INTO storage.buckets (id, name, public) VALUES
  ('av-profile', 'av-profile', true),
  ('av-paintings', 'av-paintings', true),
  ('av-documents', 'av-documents', true)
ON CONFLICT (id) DO NOTHING;

-- -----------------------------------------------------------
-- STORAGE POLICIES — av-profile bucket
-- -----------------------------------------------------------
-- Anyone can read profile photos (public bucket)
CREATE POLICY "Profile photos are publicly readable"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'av-profile');

-- Authenticated users can upload their own profile photos
CREATE POLICY "Users can upload own profile photos"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'av-profile'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

-- Users can update their own profile photos
CREATE POLICY "Users can update own profile photos"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'av-profile'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

-- Users can delete their own profile photos
CREATE POLICY "Users can delete own profile photos"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'av-profile'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

-- -----------------------------------------------------------
-- STORAGE POLICIES — av-paintings bucket
-- -----------------------------------------------------------
-- Anyone can read painting photos (public bucket)
CREATE POLICY "Painting photos are publicly readable"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'av-paintings');

-- Authenticated users can upload painting photos
CREATE POLICY "Authenticated users can upload painting photos"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'av-paintings'
    AND auth.role() = 'authenticated'
  );

-- Users can update painting photos
CREATE POLICY "Users can update painting photos"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'av-paintings'
    AND auth.role() = 'authenticated'
  );

-- Users can delete painting photos
CREATE POLICY "Users can delete painting photos"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'av-paintings'
    AND auth.role() = 'authenticated'
  );

-- -----------------------------------------------------------
-- STORAGE POLICIES — av-documents bucket
-- -----------------------------------------------------------
-- Authenticated users can read documents
CREATE POLICY "Authenticated users can read documents"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'av-documents'
    AND auth.role() = 'authenticated'
  );

-- Authenticated users can upload documents
CREATE POLICY "Authenticated users can upload documents"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'av-documents'
    AND auth.role() = 'authenticated'
  );

-- Users can update their own documents
CREATE POLICY "Users can update own documents"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'av-documents'
    AND auth.role() = 'authenticated'
  );

-- Users can delete their own documents
CREATE POLICY "Users can delete own documents"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'av-documents'
    AND auth.role() = 'authenticated'
  );

-- -----------------------------------------------------------
-- DONE! Run NOTIFY to reload PostgREST schema
-- -----------------------------------------------------------
NOTIFY pgrst, 'reload schema';
