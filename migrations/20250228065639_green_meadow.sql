/*
  # Add vector similarity indexes
  
  This migration adds vector similarity indexes for the embedding columns
  after ensuring they have proper dimensions.
*/

-- Create vector similarity indexes for transcription_segments
DO $$ 
BEGIN
  -- Only create index if column has data
  IF EXISTS (
    SELECT 1 
    FROM transcription_segments 
    WHERE embedding IS NOT NULL 
    LIMIT 1
  ) THEN
    CREATE INDEX idx_transcription_segments_embedding 
    ON transcription_segments
    USING ivfflat (embedding vector_cosine_ops);
  END IF;
END $$;

-- Create vector similarity indexes for transcription_chunks
DO $$ 
BEGIN
  -- Only create index if column has data
  IF EXISTS (
    SELECT 1 
    FROM transcription_chunks 
    WHERE embedding IS NOT NULL 
    LIMIT 1
  ) THEN
    CREATE INDEX idx_transcription_chunks_embedding 
    ON transcription_chunks
    USING ivfflat (embedding vector_cosine_ops);
  END IF;
END $$;

-- Create function to update vector indexes
CREATE OR REPLACE FUNCTION refresh_vector_indexes()
RETURNS void AS $$
BEGIN
  -- Drop existing indexes if they exist
  DROP INDEX IF EXISTS idx_transcription_segments_embedding;
  DROP INDEX IF EXISTS idx_transcription_chunks_embedding;
  
  -- Recreate indexes
  IF EXISTS (
    SELECT 1 
    FROM transcription_segments 
    WHERE embedding IS NOT NULL 
    LIMIT 1
  ) THEN
    CREATE INDEX idx_transcription_segments_embedding 
    ON transcription_segments
    USING ivfflat (embedding vector_cosine_ops);
  END IF;

  IF EXISTS (
    SELECT 1 
    FROM transcription_chunks 
    WHERE embedding IS NOT NULL 
    LIMIT 1
  ) THEN
    CREATE INDEX idx_transcription_chunks_embedding 
    ON transcription_chunks
    USING ivfflat (embedding vector_cosine_ops);
  END IF;
END;
$$ LANGUAGE plpgsql;