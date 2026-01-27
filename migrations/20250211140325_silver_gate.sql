/*
  # Seed mock data for meetings

  1. Data Population
    - Add sample meetings
    - Add participants for each meeting
    - Add transcription segments
    
  2. Sample Content
    - Two different meetings with multiple participants
    - Realistic transcription segments with timestamps
*/

-- Insert mock meetings
INSERT INTO meetings (id, title, date, audio_file, status, model, language, processing_time)
VALUES
  ('d290f1ee-6c54-4b01-90e6-d701748f0851', 'Comité Stratégique Q2', '2024-03-15', 'meeting_2024_03_15.mp3', 'completed', 'whisper-diarization', 'fr', '5.2s'),
  ('d290f1ee-6c54-4b01-90e6-d701748f0852', 'Innovation & Expérience Client', '2024-03-14', 'meeting_2024_03_14.mp3', 'completed', 'whisper-diarization', 'fr', '4.8s');

-- Insert participants for first meeting
INSERT INTO participants (meeting_id, speaker_id, name, role)
VALUES
  ('d290f1ee-6c54-4b01-90e6-d701748f0851', 'SPEAKER_00', 'Marie Dubois', 'Directrice Marketing'),
  ('d290f1ee-6c54-4b01-90e6-d701748f0851', 'SPEAKER_01', 'Jean Martin', 'Directeur Financier'),
  ('d290f1ee-6c54-4b01-90e6-d701748f0851', 'SPEAKER_02', 'Sophie Bernard', 'Chef de Projet');

-- Insert participants for second meeting
INSERT INTO participants (meeting_id, speaker_id, name, role)
VALUES
  ('d290f1ee-6c54-4b01-90e6-d701748f0852', 'SPEAKER_00', 'Emma Moreau', 'UX Designer'),
  ('d290f1ee-6c54-4b01-90e6-d701748f0852', 'SPEAKER_01', 'Thomas Richard', 'Product Owner'),
  ('d290f1ee-6c54-4b01-90e6-d701748f0852', 'SPEAKER_02', 'Julie Lambert', 'Développeuse');

-- Insert transcription segments for first meeting
INSERT INTO transcription_segments (meeting_id, start_time, end_time, speaker_id, text)
VALUES
  ('d290f1ee-6c54-4b01-90e6-d701748f0851', 0.0, 5.32, 'SPEAKER_00', 'Bonjour à tous, bienvenue à ce comité stratégique du deuxième trimestre.'),
  ('d290f1ee-6c54-4b01-90e6-d701748f0851', 5.33, 12.15, 'SPEAKER_01', 'Merci Marie. Je vais commencer par présenter les résultats financiers du Q1.'),
  ('d290f1ee-6c54-4b01-90e6-d701748f0851', 12.16, 20.45, 'SPEAKER_02', 'Excellent. J''aimerais ensuite aborder les nouveaux projets marketing.'),
  ('d290f1ee-6c54-4b01-90e6-d701748f0851', 20.46, 28.30, 'SPEAKER_00', 'Parfait. Nous pourrons aussi discuter du lancement produit prévu pour septembre.');

-- Insert transcription segments for second meeting
INSERT INTO transcription_segments (meeting_id, start_time, end_time, speaker_id, text)
VALUES
  ('d290f1ee-6c54-4b01-90e6-d701748f0852', 0.0, 6.25, 'SPEAKER_00', 'Commençons notre revue des retours utilisateurs sur la nouvelle interface.'),
  ('d290f1ee-6c54-4b01-90e6-d701748f0852', 6.26, 15.40, 'SPEAKER_01', 'Les tests utilisateurs montrent une amélioration de 30% de la satisfaction client.'),
  ('d290f1ee-6c54-4b01-90e6-d701748f0852', 15.41, 22.80, 'SPEAKER_02', 'La nouvelle architecture technique permet des temps de chargement réduits de moitié.'),
  ('d290f1ee-6c54-4b01-90e6-d701748f0852', 22.81, 30.15, 'SPEAKER_00', 'Ces résultats sont très encourageants pour la suite du projet.');