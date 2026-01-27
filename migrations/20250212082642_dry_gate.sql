/*
  # Ajout de la table audio_files

  1. Nouvelle Table
    - `audio_files`
      - `id` (uuid, primary key)
      - `meeting_id` (uuid, foreign key)
      - `filename` (text)
      - `status` (text)
      - `created_at` (timestamp)
      - `updated_at` (timestamp)

  2. Sécurité
    - Enable RLS
    - Policies pour les utilisateurs authentifiés
*/

-- Create audio_files table
CREATE TABLE audio_files (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  meeting_id UUID REFERENCES meetings(id) ON DELETE CASCADE,
  filename TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Enable RLS
ALTER TABLE audio_files ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Enable read access for authenticated users"
  ON audio_files FOR SELECT
  TO authenticated
  USING (auth.uid() IS NOT NULL);

CREATE POLICY "Enable insert access for authenticated users"
  ON audio_files FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "Enable update access for authenticated users"
  ON audio_files FOR UPDATE
  TO authenticated
  USING (auth.uid() IS NOT NULL)
  WITH CHECK (auth.uid() IS NOT NULL);

-- Add trigger for updated_at
CREATE TRIGGER set_audio_files_updated_at
  BEFORE UPDATE ON audio_files
  FOR EACH ROW
  EXECUTE FUNCTION handle_updated_at();

-- Create indexes
CREATE INDEX idx_audio_files_meeting ON audio_files(meeting_id);
CREATE INDEX idx_audio_files_status ON audio_files(status);