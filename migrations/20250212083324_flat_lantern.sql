-- Create function to handle meeting and audio file creation in a transaction
CREATE OR REPLACE FUNCTION create_meeting_with_audio(
  meeting_title TEXT,
  meeting_date DATE,
  audio_filename TEXT
) RETURNS meetings AS $$
DECLARE
  new_meeting meetings;
BEGIN
  -- Create meeting
  INSERT INTO meetings (title, date, audio_file, status)
  VALUES (meeting_title, meeting_date, audio_filename, 'pending')
  RETURNING * INTO new_meeting;

  -- Create audio file entry
  INSERT INTO audio_files (meeting_id, filename, status)
  VALUES (new_meeting.id, audio_filename, 'pending');

  RETURN new_meeting;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;