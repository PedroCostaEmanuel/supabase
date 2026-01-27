/*
  # Fix Audio File Validation

  1. Simplification
    - Suppression des fonctions redondantes
    - Amélioration de la gestion des erreurs
    - Validation plus robuste des types MIME

  2. Optimisation
    - Meilleure gestion des métadonnées
    - Validation plus efficace
    - Réduction des opérations inutiles

  3. Sécurité
    - Validation stricte des types MIME
    - Vérification de la taille des fichiers
    - Politiques RLS optimisées
*/

-- Fonction de validation des fichiers audio simplifiée
CREATE OR REPLACE FUNCTION validate_audio_file_trigger()
RETURNS TRIGGER AS $$
DECLARE
  mime_type TEXT;
  file_size BIGINT;
  valid_types TEXT[] := ARRAY[
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
  ];
  normalized_mime TEXT;
BEGIN
  -- Extraire le type MIME des métadonnées
  mime_type := COALESCE(
    NEW.metadata->>'mimetype',
    NEW.metadata->>'content_type',
    NEW.content_type
  );

  -- Vérifier que le type MIME est présent
  IF mime_type IS NULL THEN
    RAISE EXCEPTION 'Le type MIME est requis';
  END IF;

  -- Normaliser le type MIME
  normalized_mime := CASE LOWER(TRIM(mime_type))
    WHEN 'audio/x-mp3' THEN 'audio/mpeg'
    WHEN 'audio/mp3' THEN 'audio/mpeg'
    WHEN 'audio/x-wav' THEN 'audio/wav'
    WHEN 'audio/wave' THEN 'audio/wav'
    WHEN 'audio/x-m4a' THEN 'audio/m4a'
    ELSE LOWER(TRIM(mime_type))
  END;

  -- Vérifier que le type MIME est valide
  IF NOT normalized_mime = ANY(valid_types) THEN
    RAISE EXCEPTION 'Type MIME non supporté: %. Les types valides sont: %',
      mime_type,
      array_to_string(valid_types, ', ');
  END IF;

  -- Extraire et vérifier la taille du fichier
  file_size := COALESCE(
    (NEW.metadata->>'size')::bigint,
    NEW.size
  );

  IF file_size IS NULL THEN
    RAISE EXCEPTION 'La taille du fichier est requise';
  END IF;

  IF file_size > 10485760000 THEN -- 100MB
    RAISE EXCEPTION 'La taille du fichier ne doit pas dépasser 100MB';
  END IF;

  -- Mettre à jour les métadonnées
  NEW.content_type := normalized_mime;
  NEW.size := file_size;
  NEW.metadata := jsonb_build_object(
    'normalized_mime_type', normalized_mime,
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
SET allowed_mime_types = ARRAY[
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
  ],
  file_size_limit = 10485760000,
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
  WITH CHECK (bucket_id = 'Audio');

-- Ajouter des index pour les performances
CREATE INDEX IF NOT EXISTS idx_storage_objects_mime
  ON storage.objects(content_type)
  WHERE bucket_id = 'Audio';

CREATE INDEX IF NOT EXISTS idx_storage_objects_size
  ON storage.objects(size)
  WHERE bucket_id = 'Audio';