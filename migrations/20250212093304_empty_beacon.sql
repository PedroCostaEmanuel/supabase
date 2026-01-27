/*
  # Configure storage policies for audio files

  1. Security
    - Create Audio bucket if it doesn't exist
    - Enable storage access for authenticated users
    - Configure policies for:
      - Reading audio files
      - Uploading audio files
      - Deleting audio files
*/

-- Create Audio bucket if it doesn't exist
DO $$
BEGIN
  INSERT INTO storage.buckets (id, name, public)
  VALUES ('Audio', 'Audio', true)
  ON CONFLICT (id) DO NOTHING;
END $$;

-- Enable authenticated access to storage
CREATE POLICY "Enable read access for authenticated users"
  ON storage.objects FOR SELECT
  TO authenticated
  USING (bucket_id = 'Audio');

CREATE POLICY "Enable insert access for authenticated users"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'Audio');

CREATE POLICY "Enable update access for authenticated users"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (bucket_id = 'Audio');

CREATE POLICY "Enable delete access for authenticated users"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (bucket_id = 'Audio');