CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

CREATE TABLE public.account_locks (
  profile_id uuid PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  pass_hash text NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.account_locks ENABLE ROW LEVEL SECURITY;
GRANT ALL ON public.account_locks TO service_role;

CREATE OR REPLACE FUNCTION public.has_password(p_id uuid, p_kode text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM public.account_locks l JOIN public.profiles p ON p.id = l.profile_id WHERE p.id = p_id AND p.kode_id = p_kode);
$$;

CREATE OR REPLACE FUNCTION public.set_password(p_id uuid, p_kode text, p_old text, p_new text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions AS $$
DECLARE h text;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = p_id AND kode_id = p_kode) THEN RAISE EXCEPTION 'Akun tidak ditemukan'; END IF;
  SELECT pass_hash INTO h FROM public.account_locks WHERE profile_id = p_id;
  IF h IS NOT NULL AND (p_old IS NULL OR crypt(p_old, h) <> h) THEN RAISE EXCEPTION 'Password lama salah'; END IF;
  IF p_new IS NULL OR length(p_new) = 0 THEN
    DELETE FROM public.account_locks WHERE profile_id = p_id;
    RETURN;
  END IF;
  IF length(p_new) < 4 OR length(p_new) > 72 THEN RAISE EXCEPTION 'Password harus 4-72 karakter'; END IF;
  INSERT INTO public.account_locks(profile_id, pass_hash) VALUES (p_id, crypt(p_new, gen_salt('bf')))
  ON CONFLICT (profile_id) DO UPDATE SET pass_hash = EXCLUDED.pass_hash, updated_at = now();
END $$;

CREATE OR REPLACE FUNCTION public.login_secure(p_kode text, p_nama text, p_pass text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions AS $$
DECLARE r public.profiles; h text;
BEGIN
  SELECT * INTO r FROM public.profiles
  WHERE kode_id = upper(trim(p_kode))
    AND (lower(trim(nama)) = lower(trim(p_nama)) OR lower(username) = lower(trim(p_nama)))
  LIMIT 1;
  IF r.id IS NULL THEN RETURN jsonb_build_object('status', 'notfound'); END IF;
  SELECT pass_hash INTO h FROM public.account_locks WHERE profile_id = r.id;
  IF h IS NOT NULL THEN
    IF p_pass IS NULL OR p_pass = '' THEN RETURN jsonb_build_object('status', 'need_password'); END IF;
    IF crypt(p_pass, h) <> h THEN RETURN jsonb_build_object('status', 'wrong'); END IF;
  END IF;
  RETURN jsonb_build_object('status', 'ok', 'profile', to_jsonb(r));
END $$;

REVOKE EXECUTE ON FUNCTION public.login_id_card(text, text) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.has_password(uuid, text), public.set_password(uuid, text, text, text), public.login_secure(text, text, text) TO anon, authenticated;