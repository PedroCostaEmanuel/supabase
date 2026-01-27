create index on transcription_segments using ivfflat (embedding vector_cosine_ops);

DROP INDEX IF EXISTS idx_transcription_segments_metadata;

CREATE INDEX idx_transcription_segments_metadata ON transcription_segments USING gin (metadata);

create index on transcription_chunks using ivfflat (embedding vector_cosine_ops);

DROP INDEX IF EXISTS idx_transcription_chunks_metadata;

CREATE INDEX idx_transcription_chunks_metadata ON transcription_chunks USING gin (metadata);


-- Create a function to search for documentation chunks
create function match_transcription_segments (
  query_embedding vector(768),
  match_count int default 10,
  filter jsonb DEFAULT '{}'::jsonb
) returns table (
  id uuid,
  start_time float8,
  end_time float8,
  speaker_id text,
  text text,
  metadata jsonb,
  similarity float
)
language plpgsql
as $$
#variable_conflict use_column
begin
  return query
  select
    id,
    start_time,
    end_time,
    speaker_id,
    text,
    metadata,
    1 - (transcription_segments.embedding <=> query_embedding) as similarity
  from transcription_segments
  where metadata @> filter
  order by transcription_segments.embedding <=> query_embedding
  limit match_count;
end;
$$;


-- Create a function to search for documentation chunks
create function match_transcription_chunks (
  query_embedding vector(768),
  match_count int default 10,
  filter jsonb DEFAULT '{}'::jsonb
) returns table (
  id uuid,
  chunk_number int4,
  title text,
  summary text,
  content text,
  speakers_list text[],
  metadata jsonb,
  similarity float
)
language plpgsql
as $$
#variable_conflict use_column
begin
  return query
  select
    id,
    chunk_number,
    title,
    summary,
    content,
    speakers_list,
    metadata,
    1 - (transcription_chunks.embedding <=> query_embedding) as similarity
  from transcription_chunks
  where metadata @> filter
  order by transcription_chunks.embedding <=> query_embedding
  limit match_count;
end;
$$;

