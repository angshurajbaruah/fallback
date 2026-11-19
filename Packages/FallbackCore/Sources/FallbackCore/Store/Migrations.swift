import GRDB

/// Numbered schema migrations (PRD 10). Never edit a shipped migration: add a new one.
enum Migrations {
    static func register(in migrator: inout DatabaseMigrator) {
        migrator.registerMigration("v1") { db in
            try db.execute(sql: """
            CREATE TABLE families (
                id INTEGER PRIMARY KEY,
                stem TEXT NOT NULL,
                display_name TEXT NOT NULL,
                muted BOOLEAN NOT NULL DEFAULT 0,
                merged_into_id INTEGER REFERENCES families(id) ON DELETE SET NULL
            );
            CREATE TABLE files (
                id INTEGER PRIMARY KEY,
                file_identity TEXT UNIQUE,
                path TEXT,
                name TEXT NOT NULL,
                ext TEXT NOT NULL,
                stem TEXT,
                family_id INTEGER REFERENCES families(id) ON DELETE SET NULL,
                sha256 TEXT,
                size_bytes INTEGER,
                modified_at DATETIME,
                first_seen_at DATETIME NOT NULL,
                last_seen_at DATETIME NOT NULL,
                in_watched_folder BOOLEAN NOT NULL DEFAULT 0,
                where_from TEXT,
                doc_title TEXT,
                doc_author TEXT,
                doc_created_at DATETIME,
                doc_internal_id TEXT,
                text_signature BLOB,
                image_signature BLOB
            );
            CREATE INDEX files_sha256 ON files(sha256);
            CREATE INDEX files_path ON files(path);
            CREATE TABLE family_links (
                id INTEGER PRIMARY KEY,
                file_a_id INTEGER NOT NULL REFERENCES files(id) ON DELETE CASCADE,
                file_b_id INTEGER NOT NULL REFERENCES files(id) ON DELETE CASCADE,
                signal TEXT NOT NULL,
                confidence TEXT NOT NULL,
                similarity REAL,
                relation TEXT NOT NULL,
                decided_by TEXT NOT NULL
            );
            CREATE TABLE destinations (
                id INTEGER PRIMARY KEY,
                key TEXT NOT NULL UNIQUE,
                label TEXT NOT NULL,
                label_source TEXT NOT NULL,
                muted BOOLEAN NOT NULL DEFAULT 0
            );
            CREATE TABLE sends (
                id INTEGER PRIMARY KEY,
                file_id INTEGER REFERENCES files(id) ON DELETE SET NULL,
                sha256 TEXT,
                file_name_at_send TEXT NOT NULL,
                destination_id INTEGER NOT NULL REFERENCES destinations(id),
                app_bundle_id TEXT NOT NULL,
                app_name TEXT NOT NULL,
                url TEXT,
                page_title TEXT,
                confidence TEXT NOT NULL,
                detection_method TEXT NOT NULL,
                sent_at DATETIME NOT NULL,
                is_hidden BOOLEAN NOT NULL DEFAULT 0
            );
            CREATE INDEX sends_sent_at ON sends(sent_at);
            CREATE INDEX sends_destination ON sends(destination_id);
            CREATE TABLE warnings (
                id INTEGER PRIMARY KEY,
                send_id INTEGER NOT NULL REFERENCES sends(id) ON DELETE CASCADE,
                rule TEXT NOT NULL,
                shown_as_card BOOLEAN NOT NULL,
                outcome TEXT,
                created_at DATETIME NOT NULL
            );
            CREATE TABLE label_rules (id INTEGER PRIMARY KEY, key TEXT NOT NULL UNIQUE, label TEXT NOT NULL);
            CREATE TABLE watched_folders (id INTEGER PRIMARY KEY, path TEXT NOT NULL UNIQUE);
            CREATE TABLE watched_apps (id INTEGER PRIMARY KEY, bundle_id TEXT NOT NULL UNIQUE, enabled BOOLEAN NOT NULL DEFAULT 1);
            CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL);

            -- Search index (FR-10): file name, destination label, page title, app. Kept in sync by triggers.
            CREATE VIRTUAL TABLE sends_fts USING fts5(file_name, destination, page_title, app_name, tokenize = 'unicode61', prefix = '2 3');
            CREATE TRIGGER sends_ai AFTER INSERT ON sends BEGIN
                INSERT INTO sends_fts(rowid, file_name, destination, page_title, app_name)
                VALUES (new.id, new.file_name_at_send, (SELECT label FROM destinations WHERE id = new.destination_id), new.page_title, new.app_name);
            END;
            CREATE TRIGGER sends_ad AFTER DELETE ON sends BEGIN
                DELETE FROM sends_fts WHERE rowid = old.id;
            END;
            CREATE TRIGGER sends_au AFTER UPDATE ON sends BEGIN
                DELETE FROM sends_fts WHERE rowid = old.id;
                INSERT INTO sends_fts(rowid, file_name, destination, page_title, app_name)
                VALUES (new.id, new.file_name_at_send, (SELECT label FROM destinations WHERE id = new.destination_id), new.page_title, new.app_name);
            END;
            CREATE TRIGGER destinations_au AFTER UPDATE OF label ON destinations BEGIN
                DELETE FROM sends_fts WHERE rowid IN (SELECT id FROM sends WHERE destination_id = new.id);
                INSERT INTO sends_fts(rowid, file_name, destination, page_title, app_name)
                SELECT id, file_name_at_send, new.label, page_title, app_name FROM sends WHERE destination_id = new.id;
            END;
            """)
        }

        // M3: what the indexer and FamilyEngine need (PRD 8.3, 9.6).
        migrator.registerMigration("v2") { db in
            try db.execute(sql: """
            ALTER TABLE files ADD COLUMN created_at DATETIME;
            ALTER TABLE files ADD COLUMN downloaded_at DATETIME;
            ALTER TABLE files ADD COLUMN doc_modified_at DATETIME;
            ALTER TABLE files ADD COLUMN version_number INTEGER;
            ALTER TABLE files ADD COLUMN is_variant BOOLEAN NOT NULL DEFAULT 0;
            CREATE INDEX files_family ON files(family_id);
            CREATE INDEX files_identity_path ON files(path, file_identity);
            ALTER TABLE families ADD COLUMN name_source TEXT NOT NULL DEFAULT 'auto';
            ALTER TABLE families ADD COLUMN confidence TEXT;
            ALTER TABLE families ADD COLUMN signals TEXT;
            ALTER TABLE family_links ADD COLUMN reasons TEXT;
            CREATE INDEX family_links_files ON family_links(file_a_id, file_b_id);
            """)
        }

        // Versions are numbered per format; exported PDFs point at their source (PRD 8.3).
        migrator.registerMigration("v3") { db in
            try db.execute(sql: """
            ALTER TABLE families ADD COLUMN main_format TEXT;
            ALTER TABLE files ADD COLUMN export_of_id INTEGER REFERENCES files(id) ON DELETE SET NULL;
            """)
        }

        // M4: what each warning was about, and what happened next (FR-27).
        migrator.registerMigration("v4") { db in
            try db.execute(sql: """
            ALTER TABLE warnings ADD COLUMN family_id INTEGER;
            ALTER TABLE warnings ADD COLUMN file_id INTEGER;
            ALTER TABLE warnings ADD COLUMN other_file_id INTEGER;
            ALTER TABLE warnings ADD COLUMN other_send_id INTEGER;
            ALTER TABLE warnings ADD COLUMN token TEXT;
            ALTER TABLE warnings ADD COLUMN detail TEXT;
            CREATE INDEX warnings_created ON warnings(created_at);
            CREATE INDEX warnings_send ON warnings(send_id);
            """)
        }

        // FR-37: ask for a label at most once per unknown destination, ever.
        migrator.registerMigration("v5") { db in
            try db.execute(sql: "ALTER TABLE destinations ADD COLUMN label_asked BOOLEAN NOT NULL DEFAULT 0")
        }
    }
}
