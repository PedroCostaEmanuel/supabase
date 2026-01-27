/*
  # Add tags system

  1. New Tables
    - `tags`
      - `id` (uuid, primary key)
      - `name` (text, unique)
      - `created_at` (timestamp)
    - `meeting_tags` (junction table)
      - `meeting_id` (uuid, foreign key)
      - `tag_id` (uuid, foreign key)
      - `created_at` (timestamp)

  2. Security
    - Enable RLS on both tables
    - Add policies for authenticated users to read tags
    - Add policies for authenticated users to read meeting_tags
*/

-- Create tags table
CREATE TABLE IF NOT EXISTS tags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT UNIQUE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Create junction table for many-to-many relationship
CREATE TABLE IF NOT EXISTS meeting_tags (
  meeting_id UUID REFERENCES meetings(id) ON DELETE CASCADE,
  tag_id UUID REFERENCES tags(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (meeting_id, tag_id)
);

-- Enable RLS
ALTER TABLE tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE meeting_tags ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Allow all users to read tags"
  ON tags FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Allow all users to read meeting_tags"
  ON meeting_tags FOR SELECT
  TO authenticated
  USING (true);

-- Create indexes for better performance
CREATE INDEX idx_meeting_tags_meeting ON meeting_tags(meeting_id);
CREATE INDEX idx_meeting_tags_tag ON meeting_tags(tag_id);
CREATE INDEX idx_tags_name ON tags(name);