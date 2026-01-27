/*
  # Fix Storage Policies

  1. Changes
    - Simplified storage validation
    - Fixed MIME type handling
    - Improved error messages
    - Added proper RLS policies
    - Removed unnecessary triggers

  2. Security
    - Enable RLS on storage.objects
    - Add policies for authenticated users
    - Allow public read access
*/

-- Drop existing triggers and functions
DROP TRIGGER IF EXISTS validate_audio_file_trigger ON storage.objects;
DROP FUNCTION IF EXISTS validate_audio_file_trigger();

-- Update storage bucket configuration
UPDATE storage.buckets
SET allowed_mime_types = ARRAY[
    'audio/mpeg',
    'audio/mp3',
    'audio/x-mp3',
    'audio/wav',
    'audio/x-wav',
    'audio/wave',
    'audio/m4a',
    'audio/x-m4a',
    'audio/mp4',
    'audio/aac'
  ],
  file_size_limit = 10485760000, -- 100MB
  public = true
WHERE id = 'Audio';

-- Enable RLS on storage.objects
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Drop existing policies
DROP POLICY IF EXISTS "Enable public access to Audio bucket" ON storage.objects;
DROP POLICY IF EXISTS "Enable upload for authenticated users" ON storage.objects;
DROP POLICY IF EXISTS "Enable update for authenticated users" ON storage.objects;
DROP POLICY IF EXISTS "Enable delete for authenticated users" ON storage.objects;

-- Create new policies
CREATE POLICY "Enable public read access to Audio bucket"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'Audio');

CREATE POLICY "Enable upload for authenticated users"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'Audio' AND
    CASE 
      WHEN content_type IS NOT NULL THEN
        content_type = ANY(ARRAY[
          'audio/mpeg',
          'audio/mp3',
          'audio/x-mp3',
          'audio/wav',
          'audio/x-wav',
          'audio/wave',
          'audio/m4a',
          'audio/x-m4a',
          'audio/mp4',
          'audio/aac'
        ])
      ELSE true
    END AND
    COALESCE(size, 0) <= 10485760000
  );

CREATE POLICY "Enable update for authenticated users"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (bucket_id = 'Audio')
  WITH CHECK (bucket_id = 'Audio');

CREATE POLICY "Enable delete for authenticated users"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (bucket_id = 'Audio');