# Nuvyra Food Search FTS5

Nuvyra besin veritabanı araması, kullanıcı loglarından ayrı bir SQLite dosyasında tutulur. SwiftData günlük kayıtlar için kalır; milyonlarca satırlık besin indeksi FTS5 ile aranır.

## Normalizasyon

Kullanıcı girdisi ve indekslenen alanlar aynı normalizasyondan geçirilir:

- Türkçe karakter eşleme: `ş -> s`, `ç -> c`, `ğ -> g`, `ı -> i`, `İ -> i`, `ö -> o`, `ü -> u`
- Diacritics insensitive fold
- Lowercase
- Harf/rakam dışındaki karakterleri boşluğa çevirme

Örnek:

```text
Şeftali Çilek İçli Köfte -> seftali cilek icli kofte
```

## SQL Schema

```sql
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;
PRAGMA temp_store = MEMORY;

CREATE TABLE IF NOT EXISTS food_items (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    brand TEXT,
    calories INTEGER NOT NULL,
    serving_description TEXT NOT NULL,
    name_normalized TEXT NOT NULL,
    keywords_normalized TEXT NOT NULL
);

CREATE VIRTUAL TABLE IF NOT EXISTS food_items_fts USING fts5(
    name_normalized,
    keywords_normalized,
    content = 'food_items',
    content_rowid = 'id',
    tokenize = 'unicode61 remove_diacritics 2'
);
```

## FTS Sync Triggers

```sql
CREATE TRIGGER IF NOT EXISTS food_items_ai AFTER INSERT ON food_items BEGIN
    INSERT INTO food_items_fts(rowid, name_normalized, keywords_normalized)
    VALUES (new.id, new.name_normalized, new.keywords_normalized);
END;

CREATE TRIGGER IF NOT EXISTS food_items_ad AFTER DELETE ON food_items BEGIN
    INSERT INTO food_items_fts(food_items_fts, rowid, name_normalized, keywords_normalized)
    VALUES ('delete', old.id, old.name_normalized, old.keywords_normalized);
END;

CREATE TRIGGER IF NOT EXISTS food_items_au AFTER UPDATE ON food_items BEGIN
    INSERT INTO food_items_fts(food_items_fts, rowid, name_normalized, keywords_normalized)
    VALUES ('delete', old.id, old.name_normalized, old.keywords_normalized);
    INSERT INTO food_items_fts(rowid, name_normalized, keywords_normalized)
    VALUES (new.id, new.name_normalized, new.keywords_normalized);
END;
```

## Search Query

Swift tarafında `seftali` girdisi `"seftali"*` FTS sorgusuna çevrilir.

```sql
SELECT
    food_items.id,
    food_items.name,
    food_items.brand,
    food_items.calories,
    food_items.serving_description,
    bm25(food_items_fts) AS score
FROM food_items_fts
JOIN food_items ON food_items.id = food_items_fts.rowid
WHERE food_items_fts MATCH ?
ORDER BY score
LIMIT ?;
```

Arama `SQLiteFTSFoodSearchService` içinde serial background queue üzerinde çalışır. SwiftUI yalnızca sonuç publish edildiğinde main actor'da güncellenir.
