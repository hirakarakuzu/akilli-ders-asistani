\encoding UTF8
-- Ders Asistani: eski ve kopya akislari siler (yalnizca bu projenin akislari).
-- Akisa bagli tum tablolari ("workflowId" sutunu olan) otomatik bulur.
BEGIN;
SET LOCAL session_replication_role = replica;  -- silme sirasinda yabanci anahtar kontrolunu gecici kapatir
DO $$
DECLARE
  t record;
  n int;
BEGIN
  CREATE TEMP TABLE hedef ON COMMIT DROP AS
    SELECT id FROM workflow_entity
    WHERE name IN (
      'AI Chat', 'Ders Notu Ozetleme', 'Otomatik Test Olusturma',
      'Performans Degerlendirme', 'Flashcard Olustur',
      '01 · AI Sohbet', '02 · Ders Notu Özeti', '03 · Test Oluşturma',
      '04 · Performans Analizi', '05 · Flashcard Üretimi', '06 · Sağlık Kontrolü'
    );
  SELECT count(*) INTO n FROM hedef;
  FOR t IN
    SELECT table_schema, table_name FROM information_schema.columns
    WHERE column_name = 'workflowId' AND table_schema = current_schema()
  LOOP
    EXECUTE format('DELETE FROM %I.%I WHERE "workflowId" IN (SELECT id FROM hedef)',
                   t.table_schema, t.table_name);
  END LOOP;
  DELETE FROM workflow_entity WHERE id IN (SELECT id FROM hedef);
  RAISE NOTICE 'Silinen akis sayisi: %', n;
END $$;
COMMIT;
