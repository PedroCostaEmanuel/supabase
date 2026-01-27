/*
  # Optimisation de la gestion des fichiers audio

  1. Configuration
    - Centralisation des constantes dans shared_constants
    - Définition des types MIME valides
    - Configuration des limites de taille

  2. Validation
    - Fonction de normalisation des types MIME
    - Validation des fichiers audio
    - Gestion des erreurs améliorée

  3. Sécurité
    - Politiques RLS optimisées
    - Accès public contrôlé
    - Protection contre les uploads non autorisés
*/

-- Mise à jour de la configuration audio
UPDATE shared_constants
SET value = jsonb_build_object(
  'MAX_FILE_SIZE', 10485760000,
  'VALID_MIME_TYPES', jsonb_build_array(
    'audio/mpeg',
    'audio/mp3',
    'audio/x-mp3',
    'audio/wav',
    'audio/x-wav',
    'audio/wave',
    'audio/m4a',
    'audio/x-m4a',
    'audio/mp4',
    'audio/aac'
  ),
  'NORMALIZED_MIME_TYPES', jsonb_build_object(
    'audio/x-mp3', 'audio/mpeg',
    'audio/mp3', 'audio/mpeg',
    'audio/x-wav', 'audio/wav',
    'audio/wave', 'audio/wav',
    'audio/x-m4a', 'audio/m4a'
  ),
  'STORAGE_PATH', 'PV'
),
updated_at = now()
WHERE key = 'AUDIO_CONFIG';

-- Fonction simplifiée de normalisation des types MIME
CREATE OR REPLACE FUNCTION normalize_mime_type(mime_type TEXT)
RETURNS TEXT AS $$
DECLARE
  normalized TEXT;
BEGIN
  -- Normaliser le type MIME
  SELECT value->>'NORMALIZED_MIME_TYPES'->mime_type
  INTO normalized
  FROM shared_constants
  WHERE key = 'AUDIO_CONFIG';

  -- Retourner le type normalisé ou l'original
  RETURN COALESCE(normalized, LOWER(mime_type));
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Fonction de validation des fichiers audio
CREATE OR REPLACE FUNCTION validate_audio_file(
  mime_type TEXT,
  file_size BIGINT
) RETURNS BOOLEAN AS $$
DECLARE
  config JSONB;
BEGIN
  -- Récupérer la configuration
  SELECT value INTO config
  FROM shared_constants
  WHERE key = 'AUDIO_CONFIG';

  -- Vérifier le type MIME et la taille
  RETURN 
    normalize_mime_type(mime_type) = ANY(
      ARRAY(SELECT jsonb_array_elements_text(config->'VALID_MIME_TYPES'))
    )
    AND file_size <= (config->>'MAX_FILE_SIZE')::bigint;
END;
$$ LANGUAGE plpgsql STABLE;

-- Trigger de validation des fichiers audio
CREATE OR REPLACE FUNCTION validate_audio_file_trigger()
RETURNS TRIGGER AS $$
DECLARE
  mime_type TEXT;
  file_size BIGINT;
BEGIN
  -- Extraire les métadonnées
  mime_type := COALESCE(
    NEW.metadata->>'mimetype',
    NEW.metadata->>'content_type',
    NEW.content_type
  );

  file_size := COALESCE(
    (NEW.metadata->>'size')::bigint,
    NEW.size
  );

  -- Vérifier que les métadonnées sont présentes
  IF mime_type IS NULL THEN
    RAISE EXCEPTION 'Le type MIME est requis';
  END IF;

  IF file_size IS NULL THEN
    RAISE EXCEPTION 'La taille du fichier est requise';
  END IF;

  -- Valider le fichier
  IF NOT validate_audio_file(mime_type, file_size) THEN
    RAISE EXCEPTION 'Fichier audio invalide: type MIME non supporté ou taille trop importante';
  END IF;

  -- Mettre à jour les métadonnées
  NEW.content_type := normalize_mime_type(mime_type);
  NEW.size := file_size;
  NEW.metadata := jsonb_build_object(
    'normalized_mime_type', NEW.content_type,
    'original_mime_type', mime_type,
    'size', file_size,
    'uploaded_at', CURRENT_TIMESTAMP
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Recréer le trigger
DROP TRIGGER IF EXISTS validate_audio_file_trigger ON storage.objects;
CREATE TRIGGER validate_audio_file_trigger
  BEFORE INSERT OR UPDATE ON storage.objects
  FOR EACH ROW
  WHEN (NEW.bucket_id = 'Audio')
  EXECUTE FUNCTION validate_audio_file_trigger();

-- Mettre à jour la configuration du bucket
UPDATE storage.buckets
SET allowed_mime_types = ARRAY(
  SELECT jsonb_array_elements_text(value->'VALID_MIME_TYPES')
  FROM shared_constants
  WHERE key = 'AUDIO_CONFIG'
),
file_size_limit = (
  SELECT (value->>'MAX_FILE_SIZE')::bigint
  FROM shared_constants
  WHERE key = 'AUDIO_CONFIG'
),
public = true
WHERE id = 'Audio';

-- Optimiser les politiques RLS
DROP POLICY IF EXISTS "Enable public access to Audio bucket" ON storage.objects;
CREATE POLICY "Enable public access to Audio bucket"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'Audio');

DROP POLICY IF EXISTS "Enable upload for authenticated users" ON storage.objects;
CREATE POLICY "Enable upload for authenticated users"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'Audio'
    AND validate_audio_file(
      COALESCE(
        metadata->>'mimetype',
        metadata->>'content_type',
        content_type
      ),
      COALESCE(
        (metadata->>'size')::bigint,
        size
      )
    )
  );

-- Ajouter des index pour les performances
CREATE INDEX IF NOT EXISTS idx_storage_objects_mime
  ON storage.objects(content_type)
  WHERE bucket_id = 'Audio';

CREATE INDEX IF NOT EXISTS idx_storage_objects_size
  ON storage.objects(size)
  WHERE bucket_id = 'Audio';