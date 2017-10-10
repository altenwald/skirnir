/**
 *  you need to have this as superuser:
 *  CREATE EXTENSION ltree;
 */

CREATE TABLE users (
    id serial NOT NULL PRIMARY KEY,
    username varchar(100) NOT NULL UNIQUE,
    password varchar(100) NOT NULL
);

CREATE TABLE mailboxes (
    id serial NOT NULL PRIMARY KEY,
    name varchar(128) NOT NULL,
    parent_id integer,
    full_path text NOT NULL,
    full_path_ids ltree NOT NULL,
    uid_next integer NOT NULL DEFAULT 1,
    uid_validity integer NOT NULL DEFAULT extract(epoch from now() at time zone 'utc'),
    user_id integer NOT NULL REFERENCES users(id),
    attributes varchar(50)[] NOT NULL DEFAULT '{}',

    FOREIGN KEY (parent_id) REFERENCES mailboxes(id)
);

CREATE UNIQUE INDEX ON mailboxes(user_id, full_path);

CREATE TABLE emails (
    id char(12) NOT NULL PRIMARY KEY,
    mail_from varchar(128) NOT NULL,
    subject text,
    sent_at timestamp NOT NULL DEFAULT now(),
    headers text NOT NULL,
    body text NOT NULL,
    size integer NOT NULL DEFAULT 0,
    flags varchar(50)[] NOT NULL,
    mailbox_id integer NOT NULL REFERENCES mailboxes(id) ON DELETE CASCADE,
    user_id integer NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    uid integer NOT NULL UNIQUE
);

CREATE OR REPLACE FUNCTION update_mailbox_parent_path() RETURNS TRIGGER AS $$
    DECLARE
        path ltree;
    BEGIN
        IF NEW.parent_id IS NULL THEN
            NEW.full_path_ids = NEW.id;
        ELSEIF TG_OP = 'INSERT' OR OLD.parent_id IS NULL OR OLD.parent_id != NEW.parent_id THEN
            SELECT full_path_ids || NEW.id::text FROM mailboxes WHERE id = NEW.parent_id INTO path;
            IF path IS NULL THEN
                RAISE EXCEPTION 'Invalid parent_id %', NEW.parent_id;
            END IF;
            NEW.full_path_ids = path;
        END IF;
        RETURN NEW;
    END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER parent_path_tgr
    BEFORE INSERT OR UPDATE ON mailboxes
    FOR EACH ROW EXECUTE PROCEDURE update_mailbox_parent_path();
