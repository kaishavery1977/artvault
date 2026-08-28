-- Enable Supabase Realtime on all tables used with .stream()
-- This allows the Flutter app to receive live updates via Postgres changes.

ALTER PUBLICATION supabase_realtime ADD TABLE public.users;
ALTER PUBLICATION supabase_realtime ADD TABLE public.paintings;
ALTER PUBLICATION supabase_realtime ADD TABLE public.documents;
ALTER PUBLICATION supabase_realtime ADD TABLE public.artists;
ALTER PUBLICATION supabase_realtime ADD TABLE public.revoked;
ALTER PUBLICATION supabase_realtime ADD TABLE public.role_audit;
ALTER PUBLICATION supabase_realtime ADD TABLE public.public_galleries;
ALTER PUBLICATION supabase_realtime ADD TABLE public.backups;

NOTIFY pgrst, 'reload schema';
