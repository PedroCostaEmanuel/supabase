/*
  # Add vector support for embeddings

  1. Functions
    - Add subvector function for dimension reduction
    - Add cosine similarity function

  2. Tables and Columns
    - Add embedding and metadata to transcription_segments
    - Create transcription_chunks table
    - Add basic indexes and RLS policies
*/

-- Enable vector extension if not already enabled
CREATE EXTENSION IF NOT EXISTS vector;

-- Create function to extract subvector for indexing
CREATE OR REPLACE FUNCTION subvector(input vector(768), dims integer)
RETURNS vector AS $$
BEGIN
    RETURN input[1:dims];
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Create function for cosine similarity
CREATE OR REPLACE FUNCTION cosine_similarity(a vector(768), b vector(768))
RETURNS float AS $$
BEGIN
    RETURN 1 - (a <=> b);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Add new columns to transcription_segments
ALTER TABLE transcription_segments
  ADD COLUMN IF NOT EXISTS embedding vector(768),
  ADD COLUMN IF NOT EXISTS metadata jsonb NOT NULL DEFAULT '{}'::jsonb;

-- Create transcription_chunks table
CREATE TABLE transcription_chunks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  meeting_id UUID REFERENCES meetings(id) ON DELETE CASCADE,
  chunk_number INTEGER NOT NULL,
  title TEXT,
  summary TEXT,
  content TEXT NOT NULL,
  speakers_list TEXT[],
  embedding vector(768),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Add basic indexes
CREATE INDEX idx_transcription_chunks_meeting ON transcription_chunks(meeting_id);
CREATE INDEX idx_transcription_chunks_number ON transcription_chunks(chunk_number);

-- Add indexes for JSONB metadata
CREATE INDEX idx_transcription_segments_metadata ON transcription_segments USING gin (metadata);
CREATE INDEX idx_transcription_chunks_metadata ON transcription_chunks USING gin (metadata);

-- Enable RLS
ALTER TABLE transcription_chunks ENABLE ROW LEVEL SECURITY;

-- Add RLS policies
CREATE POLICY "Enable read access for meeting chunks"
  ON transcription_chunks FOR SELECT
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM meetings m
    WHERE m.id = meeting_id
  ));

CREATE POLICY "Enable insert access for meeting chunks"
  ON transcription_chunks FOR INSERT
  TO authenticated
  WITH CHECK (EXISTS (
    SELECT 1 FROM meetings m
    WHERE m.id = meeting_id
  ));

CREATE POLICY "Enable update access for meeting chunks"
  ON transcription_chunks FOR UPDATE
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM meetings m
    WHERE m.id = meeting_id
  ));

-- Add trigger for updated_at
CREATE TRIGGER set_transcription_chunks_updated_at
  BEFORE UPDATE ON transcription_chunks
  FOR EACH ROW
  EXECUTE FUNCTION handle_updated_at();