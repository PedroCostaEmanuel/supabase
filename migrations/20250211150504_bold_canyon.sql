/*
  # Add RLS policies for editing and deleting

  1. Security Updates
    - Add INSERT policies for all tables
    - Add UPDATE policies for all tables
    - Add DELETE policies for all tables
    - Ensure proper user authorization checks
*/

-- Meetings table policies
DROP POLICY IF EXISTS "Allow authenticated to insert meetings" ON meetings;
CREATE POLICY "Allow authenticated to insert meetings"
  ON meetings FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Allow authenticated to update meetings" ON meetings;
CREATE POLICY "Allow authenticated to update meetings"
  ON meetings FOR UPDATE
  TO authenticated
  USING (auth.uid() IS NOT NULL)
  WITH CHECK (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Allow authenticated to delete meetings" ON meetings;
CREATE POLICY "Allow authenticated to delete meetings"
  ON meetings FOR DELETE
  TO authenticated
  USING (auth.uid() IS NOT NULL);

-- Participants table policies
DROP POLICY IF EXISTS "Allow authenticated to insert participants" ON participants;
CREATE POLICY "Allow authenticated to insert participants"
  ON participants FOR INSERT
  TO authenticated
  WITH CHECK (EXISTS (
    SELECT 1 FROM meetings m
    WHERE m.id = meeting_id
  ));

DROP POLICY IF EXISTS "Allow authenticated to update participants" ON participants;
CREATE POLICY "Allow authenticated to update participants"
  ON participants FOR UPDATE
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM meetings m
    WHERE m.id = meeting_id
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM meetings m
    WHERE m.id = meeting_id
  ));

DROP POLICY IF EXISTS "Allow authenticated to delete participants" ON participants;
CREATE POLICY "Allow authenticated to delete participants"
  ON participants FOR DELETE
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM meetings m
    WHERE m.id = meeting_id
  ));

-- Transcription segments table policies
DROP POLICY IF EXISTS "Allow authenticated to insert transcription segments" ON transcription_segments;
CREATE POLICY "Allow authenticated to insert transcription segments"
  ON transcription_segments FOR INSERT
  TO authenticated
  WITH CHECK (EXISTS (
    SELECT 1 FROM meetings m
    WHERE m.id = meeting_id
  ));

DROP POLICY IF EXISTS "Allow authenticated to update transcription segments" ON transcription_segments;
CREATE POLICY "Allow authenticated to update transcription segments"
  ON transcription_segments FOR UPDATE
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM meetings m
    WHERE m.id = meeting_id
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM meetings m
    WHERE m.id = meeting_id
  ));

DROP POLICY IF EXISTS "Allow authenticated to delete transcription segments" ON transcription_segments;
CREATE POLICY "Allow authenticated to delete transcription segments"
  ON transcription_segments FOR DELETE
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM meetings m
    WHERE m.id = meeting_id
  ));

-- Tags table policies
DROP POLICY IF EXISTS "Allow authenticated to insert tags" ON tags;
CREATE POLICY "Allow authenticated to insert tags"
  ON tags FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Allow authenticated to update tags" ON tags;
CREATE POLICY "Allow authenticated to update tags"
  ON tags FOR UPDATE
  TO authenticated
  USING (auth.uid() IS NOT NULL)
  WITH CHECK (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Allow authenticated to delete tags" ON tags;
CREATE POLICY "Allow authenticated to delete tags"
  ON tags FOR DELETE
  TO authenticated
  USING (auth.uid() IS NOT NULL);

-- Meeting tags table policies
DROP POLICY IF EXISTS "Allow authenticated to insert meeting tags" ON meeting_tags;
CREATE POLICY "Allow authenticated to insert meeting tags"
  ON meeting_tags FOR INSERT
  TO authenticated
  WITH CHECK (EXISTS (
    SELECT 1 FROM meetings m
    WHERE m.id = meeting_id
  ));

DROP POLICY IF EXISTS "Allow authenticated to update meeting tags" ON meeting_tags;
CREATE POLICY "Allow authenticated to update meeting tags"
  ON meeting_tags FOR UPDATE
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM meetings m
    WHERE m.id = meeting_id
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM meetings m
    WHERE m.id = meeting_id
  ));

DROP POLICY IF EXISTS "Allow authenticated to delete meeting tags" ON meeting_tags;
CREATE POLICY "Allow authenticated to delete meeting tags"
  ON meeting_tags FOR DELETE
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM meetings m
    WHERE m.id = meeting_id
  ));