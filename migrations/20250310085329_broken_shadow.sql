/*
  # Add participant update trigger

  1. New Function
    - Creates a notify_participant_updated() function that sends a webhook when a participant is updated
    - Only triggers when name or role is modified
    - Sends meeting_id, speaker_id, speaker_name, and speaker_role to the webhook

  2. New Trigger
    - Creates participant_updated_notification trigger on the participants table
    - Triggers AFTER UPDATE
    - Only fires when name or role columns are modified
*/

-- Create the notification function
CREATE OR REPLACE FUNCTION notify_participant_updated()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  webhook_url TEXT;
  retry_count INTEGER := 0;
  max_retries INTEGER := 3;
BEGIN
  -- Récupérer dynamiquement l'URL du webhook depuis la table config
  SELECT (value->>'url') || '/api/transcript/update_speaker'
  INTO webhook_url 
  FROM shared_constants 
  WHERE key = 'BACKEND_URL';

  -- Si aucune URL n'est trouvée, lever un avertissement et ne pas exécuter la requête
  IF webhook_url IS NULL THEN
    RAISE WARNING 'No webhook URL found in config';
    RETURN NEW;
  END IF;

  -- Vérifier si les données ont changé avant d'envoyer une notification
  IF (OLD.name = NEW.name AND (OLD.role IS NOT DISTINCT FROM NEW.role)) THEN
    RETURN NEW;
  END IF;

  -- Boucle pour les tentatives de retry
  WHILE retry_count < max_retries LOOP
    BEGIN
      -- Envoi de la requête HTTP via pg_net
      PERFORM net.http_post(
        url := webhook_url,
        headers := jsonb_build_object('Content-Type', 'application/json'),
        body := jsonb_build_object(
          'meeting_id', NEW.meeting_id,
          'speaker_id', NEW.speaker_id,
          'speaker_name', NEW.name,
          'speaker_role', NEW.role,
          'old_speaker_name', OLD.name,
          'old_speaker_role', OLD.role
        )::jsonb
      );

      -- Succès : on quitte la boucle
      RETURN NEW;
    EXCEPTION
      WHEN OTHERS THEN
        -- Incrémentation du compteur de retry
        retry_count := retry_count + 1;

        -- Log l'erreur
        RAISE WARNING 'Failed % attempt for webhook: %.', retry_count, SQLERRM;

        -- Pause avant de retenter (exponential backoff)
        IF retry_count < max_retries THEN
          PERFORM pg_sleep(power(2, retry_count)::INTEGER);
        END IF;
    END;
  END LOOP;

  -- Log d'échec final sans bloquer la transaction
  RAISE WARNING 'Notification failed after % attempts', max_retries;
  RETURN NEW;
END;
$$;

-- Create the trigger
CREATE TRIGGER participant_updated_notification
  AFTER UPDATE ON participants
  FOR EACH ROW
  EXECUTE FUNCTION notify_participant_updated();

-- Add comment explaining the trigger
COMMENT ON TRIGGER participant_updated_notification ON participants IS 'Sends webhook notification when participant name or role is updated';