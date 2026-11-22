ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS map text NOT NULL DEFAULT 'rumah';
ALTER TABLE public.rooms ADD CONSTRAINT rooms_map_check CHECK (map IN ('rumah','rumahsakit','kuburan','hotel'));