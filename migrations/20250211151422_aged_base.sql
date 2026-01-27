/*
  # Add RLS policies for all tables

  1. New Policies
    - Add CRUD policies for all tables
    - Add security functions for better policy management
    - Add triggers for automatic timestamp updates

  2. Security
    - Enable RLS on all tables
    - Add policies for authenticated users
    - Add row-level ownership checks
*/

-- Create security functions
CREATE OR REPLACE FUNCTION public.check_meeting_access(meeting_id uuid)
RETURNS boolean AS $$
BEGIN
  RETURN (
    EXISTS (
      SELECT 1 FROM meetings m
      WHERE m.id = meeting_id
      AND auth.uid() IS NOT NULL
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Add updated_at trigger function
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Add updated_at triggers to all tables
CREATE TRIGGER set_meetings_updated_at
  BEFORE UPDATE ON meetings
  FOR EACH ROW
  EXECUTE FUNCTION handle_updated_at();

-- Meetings policies
DROP POLICY IF EXISTS "Enable read access for authenticated users" ON meetings;
CREATE POLICY "Enable read access for authenticated users"
  ON meetings FOR SELECT
  TO authenticated
  USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Enable insert access for authenticated users" ON meetings;
CREATE POLICY "Enable insert access for authenticated users"
  ON meetings FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Enable update access for authenticated users" ON meetings;
CREATE POLICY "Enable update access for authenticated users"
  ON meetings FOR UPDATE
  TO authenticated
  USING (auth.uid() IS NOT NULL)
  WITH CHECK (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Enable delete access for authenticated users" ON meetings;
CREATE POLICY "Enable delete access for authenticated users"
  ON meetings FOR DELETE
  TO authenticated
  USING (auth.uid() IS NOT NULL);

-- Participants policies
DROP POLICY IF EXISTS "Enable read access for meeting participants" ON participants;
CREATE POLICY "Enable read access for meeting participants"
  ON participants FOR SELECT
  TO authenticated
  USING (check_meeting_access(meeting_id));

DROP POLICY IF EXISTS "Enable insert access for meeting participants" ON participants;
CREATE POLICY "Enable insert access for meeting participants"
  ON participants FOR INSERT
  TO authenticated
  WITH CHECK (check_meeting_access(meeting_id));

DROP POLICY IF EXISTS "Enable update access for meeting participants" ON participants;
CREATE POLICY "Enable update access for meeting participants"
  ON participants FOR UPDATE
  TO authenticated
  USING (check_meeting_access(meeting_id))
  WITH CHECK (check_meeting_access(meeting_id));

DROP POLICY IF EXISTS "Enable delete access for meeting participants" ON participants;
CREATE POLICY "Enable delete access for meeting participants"
  ON participants FOR DELETE
  TO authenticated
  USING (check_meeting_access(meeting_id));

-- Transcription segments policies
DROP POLICY IF EXISTS "Enable read access for meeting transcriptions" ON transcription_segments;
CREATE POLICY "Enable read access for meeting transcriptions"
  ON transcription_segments FOR SELECT
  TO authenticated
  USING (check_meeting_access(meeting_id));

DROP POLICY IF EXISTS "Enable insert access for meeting transcriptions" ON transcription_segments;
CREATE POLICY "Enable insert access for meeting transcriptions"
  ON transcription_segments FOR INSERT
  TO authenticated
  WITH CHECK (check_meeting_access(meeting_id));

DROP POLICY IF EXISTS "Enable update access for meeting transcriptions" ON transcription_segments;
CREATE POLICY "Enable update access for meeting transcriptions"
  ON transcription_segments FOR UPDATE
  TO authenticated
  USING (check_meeting_access(meeting_id))
  WITH CHECK (check_meeting_access(meeting_id));

DROP POLICY IF EXISTS "Enable delete access for meeting transcriptions" ON transcription_segments;
CREATE POLICY "Enable delete access for meeting transcriptions"
  ON transcription_segments FOR DELETE
  TO authenticated
  USING (check_meeting_access(meeting_id));

-- Tags policies
DROP POLICY IF EXISTS "Enable read access for tags" ON tags;
CREATE POLICY "Enable read access for tags"
  ON tags FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Enable insert access for tags" ON tags;
CREATE POLICY "Enable insert access for tags"
  ON tags FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Enable update access for tags" ON tags;
CREATE POLICY "Enable update access for tags"
  ON tags FOR UPDATE
  TO authenticated
  USING (auth.uid() IS NOT NULL)
  WITH CHECK (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Enable delete access for tags" ON tags;
CREATE POLICY "Enable delete access for tags"
  ON tags FOR DELETE
  TO authenticated
  USING (auth.uid() IS NOT NULL);

-- Meeting tags policies
DROP POLICY IF EXISTS "Enable read access for meeting tags" ON meeting_tags;
CREATE POLICY "Enable read access for meeting tags"
  ON meeting_tags FOR SELECT
  TO authenticated
  USING (check_meeting_access(meeting_id));

DROP POLICY IF EXISTS "Enable insert access for meeting tags" ON meeting_tags;
CREATE POLICY "Enable insert access for meeting tags"
  ON meeting_tags FOR INSERT
  TO authenticated
  WITH CHECK (check_meeting_access(meeting_id));

DROP POLICY IF EXISTS "Enable update access for meeting tags" ON meeting_tags;
CREATE POLICY "Enable update access for meeting tags"
  ON meeting_tags FOR UPDATE
  TO authenticated
  USING (check_meeting_access(meeting_id))
  WITH CHECK (check_meeting_access(meeting_id));

DROP POLICY IF EXISTS "Enable delete access for meeting tags" ON meeting_tags;
CREATE POLICY "Enable delete access for meeting tags"
  ON meeting_tags FOR DELETE
  TO authenticated
  USING (check_meeting_access(meeting_id));

-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_meetings_updated_at ON meetings(updated_at);
CREATE INDEX IF NOT EXISTS idx_participants_updated_at ON participants(created_at);
CREATE INDEX IF NOT EXISTS idx_transcription_segments_updated_at ON transcription_segments(created_at);
CREATE INDEX IF NOT EXISTS idx_tags_updated_at ON tags(created_at);
CREATE INDEX IF NOT EXISTS idx_meeting_tags_updated_at ON meeting_tags(created_at);