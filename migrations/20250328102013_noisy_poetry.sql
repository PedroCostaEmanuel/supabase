/*
  # Fix participant deletion realtime updates

  1. Changes
    - Set REPLICA IDENTITY to FULL for participants table
    - Ensures DELETE events include complete old record data
*/

-- Set REPLICA IDENTITY to FULL for participants table
ALTER TABLE participants REPLICA IDENTITY FULL;