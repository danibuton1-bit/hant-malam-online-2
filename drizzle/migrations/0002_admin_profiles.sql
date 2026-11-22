CREATE TABLE public.admin_profiles (
  profile_id uuid PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT ALL ON public.admin_profiles TO service_role;
ALTER TABLE public.admin_profiles ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.first_profile_admin()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.admin_profiles) THEN
    INSERT INTO public.admin_profiles(profile_id) VALUES (NEW.id) ON CONFLICT DO NOTHING;
  END IF;
  RETURN NEW;
END $$;

CREATE TRIGGER profiles_first_admin AFTER INSERT ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.first_profile_admin();

INSERT INTO public.admin_profiles(profile_id)
SELECT id FROM public.profiles ORDER BY created_at LIMIT 1
ON CONFLICT DO NOTHING;

CREATE OR REPLACE FUNCTION public.is_admin(p_id uuid, p_kode text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.admin_profiles a JOIN public.profiles p ON p.id = a.profile_id
    WHERE p.id = p_id AND p.kode_id = p_kode
  )
$$;
REVOKE EXECUTE ON FUNCTION public.first_profile_admin() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.is_admin(uuid, text) TO anon, authenticated;