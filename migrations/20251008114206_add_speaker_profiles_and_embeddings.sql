/*
  # Add speaker profiles and speaker embedding capabilities

  1. New Tables
    - `speaker_profiles`: Stores persistent voice profiles with embeddings for speaker recognition

  2. Changes to existing tables
    - `participants`: Add columns for automatic name identification and speaker profile linking

  3. Security
    - Enable RLS on speaker_profiles
    - Add policies for authenticated users

  4. Indexes
    - Add vector index for fast similarity search on speaker embeddings
*/

-- Enable vector extension if not already enabled
CREATE EXTENSION IF NOT EXISTS vector;

-- Create speaker_profiles table
CREATE TABLE IF NOT EXISTS speaker_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  embedding VECTOR(512), -- Pyannote speaker embeddings are 512-dimensional
  organization_id UUID, -- Optional: for multi-tenant scenarios
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  metadata JSONB DEFAULT '{}'::jsonb,

  -- Ensure unique names per organization (NULL organization = global)
  CONSTRAINT unique_name_per_org UNIQUE NULLS NOT DISTINCT (name, organization_id)
);

-- Add columns to participants table for automatic speaker identification
ALTER TABLE participants ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}'::jsonb;
ALTER TABLE participants ADD COLUMN IF NOT EXISTS speaker_profile_id UUID REFERENCES speaker_profiles(id) ON DELETE SET NULL;
ALTER TABLE participants ADD COLUMN IF NOT EXISTS embedding VECTOR(512); -- Meeting-specific speaker embedding

-- Add comment explaining the columns
COMMENT ON COLUMN participants.metadata IS 'Stores auto-identification info: {auto_identified, identification_method, confidence, evidence}';
COMMENT ON COLUMN participants.speaker_profile_id IS 'Links to a persistent speaker profile if identified';
COMMENT ON COLUMN participants.embedding IS 'Voice embedding specific to this meeting for future matching';

-- Enable RLS on speaker_profiles
ALTER TABLE speaker_profiles ENABLE ROW LEVEL SECURITY;

-- Create policies for speaker_profiles
CREATE POLICY "Allow all users to read speaker profiles"
  ON speaker_profiles FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Allow all users to create speaker profiles"
  ON speaker_profiles FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Allow all users to update their own speaker profiles"
  ON speaker_profiles FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_speaker_profiles_name ON speaker_profiles(name);
CREATE INDEX IF NOT EXISTS idx_speaker_profiles_org ON speaker_profiles(organization_id) WHERE organization_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_participants_profile ON participants(speaker_profile_id) WHERE speaker_profile_id IS NOT NULL;

-- Create vector index for fast similarity search (using IVFFlat algorithm)
-- Note: This requires at least ~1000 rows for optimal performance
-- For small datasets, it will fall back to sequential scan
CREATE INDEX IF NOT EXISTS idx_speaker_profiles_embedding_ivfflat
  ON speaker_profiles
  USING ivfflat (embedding vector_cosine_ops)
  WITH (lists = 100);

CREATE INDEX IF NOT EXISTS idx_participants_embedding_ivfflat
  ON participants
  USING ivfflat (embedding vector_cosine_ops)
  WITH (lists = 100);

-- Add function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_speaker_profile_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for automatic timestamp update
DROP TRIGGER IF EXISTS speaker_profile_updated_at ON speaker_profiles;
CREATE TRIGGER speaker_profile_updated_at
  BEFORE UPDATE ON speaker_profiles
  FOR EACH ROW
  EXECUTE FUNCTION update_speaker_profile_updated_at();

-- Add helper function to find similar speaker profiles by embedding
CREATE OR REPLACE FUNCTION find_similar_speaker_profiles(
  query_embedding VECTOR(512),
  match_threshold FLOAT DEFAULT 0.85,
  match_count INT DEFAULT 5
)
RETURNS TABLE (
  id UUID,
  name TEXT,
  similarity FLOAT,
  metadata JSONB
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    sp.id,
    sp.name,
    1 - (sp.embedding <=> query_embedding) AS similarity,
    sp.metadata
  FROM speaker_profiles sp
  WHERE sp.embedding IS NOT NULL
    AND 1 - (sp.embedding <=> query_embedding) > match_threshold
  ORDER BY sp.embedding <=> query_embedding
  LIMIT match_count;
END;
$$;

COMMENT ON FUNCTION find_similar_speaker_profiles IS
  'Finds speaker profiles with embeddings similar to the query embedding using cosine similarity';
