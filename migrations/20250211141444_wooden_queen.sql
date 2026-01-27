/*
  # Add test tags and assign them to meetings

  1. New Data
    - Add sample tags for meetings
    - Create associations between meetings and tags

  2. Changes
    - Insert initial set of tags
    - Link tags to existing meetings
*/

-- Insert test tags
INSERT INTO tags (name) VALUES
  ('Stratégie'),
  ('Finance'),
  ('Marketing'),
  ('Innovation'),
  ('Produit'),
  ('Client'),
  ('Tech'),
  ('RH');

-- Assign tags to first meeting (Comité Stratégique Q2)
INSERT INTO meeting_tags (meeting_id, tag_id)
SELECT 
  'd290f1ee-6c54-4b01-90e6-d701748f0851',
  id
FROM tags
WHERE name IN ('Stratégie', 'Finance', 'Marketing');

-- Assign tags to second meeting (Innovation & Expérience Client)
INSERT INTO meeting_tags (meeting_id, tag_id)
SELECT 
  'd290f1ee-6c54-4b01-90e6-d701748f0852',
  id
FROM tags
WHERE name IN ('Innovation', 'Client', 'Tech');