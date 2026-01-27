-- Create function to get current date folder name
CREATE OR REPLACE FUNCTION get_current_date_folder()
RETURNS TEXT AS $$
BEGIN
  RETURN to_char(CURRENT_DATE, 'DD_MM_YYYY');
END;
$$ LANGUAGE plpgsql;

-- Update the storage path generation function to use date-based folders
CREATE OR REPLACE FUNCTION generate_storage_path(filename TEXT)
RETURNS TEXT AS $$
DECLARE
  clean_filename TEXT;
  date_folder TEXT;
BEGIN
  -- Get current date folder
  date_folder := get_current_date_folder();

  -- Clean filename: lowercase, replace special chars with underscore
  clean_filename := lower(filename);
  clean_filename := regexp_replace(clean_filename, '[^a-z0-9.-]', '_', 'g');
  clean_filename := regexp_replace(clean_filename, '\.+', '.', 'g');
  clean_filename := trim(both '.' from clean_filename);

  -- Return path with date folder
  RETURN date_folder || '/' || clean_filename;
END;
$$ LANGUAGE plpgsql;

-- Update the shared constants to remove the static storage path
UPDATE shared_constants
SET value = jsonb_set(
  value,
  '{STORAGE_PATH}',
  to_jsonb(get_current_date_folder())
)
WHERE key = 'AUDIO_CONFIG';

-- Update the webhook notification function to use the new path format
CREATE OR REPLACE FUNCTION notify_meeting_created()
RETURNS TRIGGER AS $$
DECLARE
  supabase_url TEXT := 'https://itwecqiawtsorltahlwl.supabase.co';
  storage_path TEXT;
BEGIN
  -- Generate storage path using the date-based function
  storage_path := generate_storage_path(NEW.audio_file);

  -- Send webhook notification
  PERFORM net.http_post(
    url := 'https://lumind.app.n8n.cloud/webhook-test/a881f338-6ae6-4292-9253-c51c241b356f',
    headers := jsonb_build_object(
      'Content-Type', 'application/json'
    ),
    body := jsonb_build_object(
      'meeting', jsonb_build_object(
        'id', NEW.id,
        'title', NEW.title,
        'date', NEW.date,
        'status', NEW.status,
        'created_at', NEW.created_at
      ),
      'audio_file', jsonb_build_object(
        'filename', NEW.audio_file,
        'storage_path', storage_path,
        'url', supabase_url || '/storage/v1/object/public/Audio/' || storage_path
      )
    )::jsonb
  );
  
  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Failed to send webhook notification: %', SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;