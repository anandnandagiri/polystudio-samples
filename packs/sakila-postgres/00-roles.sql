-- =============================================================================
--  Roles for the Poly Studio evaluation lab (PostgreSQL / Sakila).
--
--  Runs FIRST (00- prefix) so the Sakila scripts that follow can resolve the
--  roles they reference.
--
--  Background
--  ----------
--  The upstream Sakila dump was taken with the superuser named "postgres", so
--  it contains 55 "OWNER TO postgres" statements, a "GRANT ... TO postgres",
--  and a final "REASSIGN OWNED BY postgres TO sakila".
--
--  The container's own superuser is deliberately NOT called "postgres"
--  (POSTGRES_USER=poly). That matters: if the bootstrap superuser is
--  "postgres", it owns the pg_catalog system objects, and
--  "REASSIGN OWNED BY postgres" fails with:
--
--      ERROR: cannot reassign ownership of objects owned by role postgres
--             because they are required by the database system
--
--  With "postgres" created here as an ordinary role, it owns only the Sakila
--  objects, and the reassignment succeeds.
--
--  Roles created here:
--    * postgres - ordinary role owning the Sakila objects (per the dump)
--    * sakila   - the application role the dump's cleanup script targets
--
--  Poly Studio connects as "poly" (the container superuser), so it can read
--  every object regardless of owner.
-- =============================================================================

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'postgres') THEN
        CREATE ROLE postgres LOGIN CREATEDB PASSWORD 'poly';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'sakila') THEN
        CREATE ROLE sakila LOGIN PASSWORD 'poly';
    END IF;
END
$$;

GRANT ALL PRIVILEGES ON DATABASE sakila TO sakila;
GRANT ALL PRIVILEGES ON DATABASE sakila TO postgres;
