/*
  # Create meetings and related tables

  1. New Tables
    - `meetings`: Stores meeting metadata and status
    - `participants`: Stores participant information
    - `transcription_segments`: Stores transcription segments with timestamps
    
  2. Security
    - Enable RLS on all tables
    - Add policies for authenticated users
*/

-- Create meetings table
CREATE TABLE meetings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  date DATE NOT NULL,
  audio_file TEXT,
  status TEXT NOT NULL DEFAULT 'pending',
  model TEXT,
  language TEXT,
  processing_time TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Create participants table
CREATE TABLE participants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  meeting_id UUID REFERENCES meetings(id) ON DELETE CASCADE,
  speaker_id TEXT NOT NULL,
  name TEXT NOT NULL,
  role TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Create transcription segments table
CREATE TABLE transcription_segments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  meeting_id UUID REFERENCES meetings(id) ON DELETE CASCADE,
  start_time FLOAT NOT NULL,
  end_time FLOAT NOT NULL,
  speaker_id TEXT NOT NULL,
  text TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Enable RLS
ALTER TABLE meetings ENABLE ROW LEVEL SECURITY;
ALTER TABLE participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE transcription_segments ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Allow all users to read meetings"
  ON meetings FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Allow all users to read participants"
  ON participants FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Allow all users to read transcription segments"
  ON transcription_segments FOR SELECT
  TO authenticated
  USING (true);

-- Create indexes for better performance
CREATE INDEX idx_meeting_date ON meetings(date);
CREATE INDEX idx_participants_meeting ON participants(meeting_id);
CREATE INDEX idx_transcription_meeting ON transcription_segments(meeting_id);
CREATE INDEX idx_transcription_time ON transcription_segments(start_time, end_time);