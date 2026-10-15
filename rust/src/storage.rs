//! Local-only settings, recipes and example pack presets. No document contents or paths.
use crate::{model::*, packs::PackPreset, recipe::Recipe};
use rusqlite::{Connection, params};
use serde::{Deserialize, Serialize};
use std::path::Path;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(deny_unknown_fields)]
pub struct Settings {
    pub schema_version: u32,
    pub theme: String,
    pub history_enabled: bool,
    pub retention_days: u32,
}
impl Default for Settings {
    fn default() -> Self {
        Self {
            schema_version: 1,
            theme: "system".into(),
            history_enabled: false,
            retention_days: 30,
        }
    }
}
impl Settings {
    pub fn validate(&self) -> Result<()> {
        if self.schema_version != 1
            || !["system", "light", "dark"].contains(&self.theme.as_str())
            || !(1..=365).contains(&self.retention_days)
        {
            return Err(invalid("Unsupported settings or retention interval."));
        }
        Ok(())
    }
}
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HistoryEntry {
    pub id: i64,
    pub operation: String,
    pub format: String,
    pub bytes: u64,
    pub created_at: i64,
}
pub struct Store {
    db: Connection,
}
fn db_error(_: rusqlite::Error) -> StudioError {
    invalid("Local settings could not be read or saved. Check access and available disk space.")
}
impl Store {
    pub fn open(directory: &Path) -> Result<Self> {
        std::fs::create_dir_all(directory)?;
        let mut db = Connection::open(directory.join("studio.sqlite3")).map_err(db_error)?;
        db.busy_timeout(std::time::Duration::from_secs(3))
            .map_err(db_error)?;
        db.pragma_update(None, "trusted_schema", false)
            .map_err(db_error)?;
        db.pragma_update(None, "foreign_keys", true)
            .map_err(db_error)?;
        let version: i64 = db
            .pragma_query_value(None, "user_version", |r| r.get(0))
            .map_err(db_error)?;
        if version > 1 {
            return Err(invalid(
                "These settings were created by a newer application version.",
            ));
        }
        if version == 0 {
            let tx = db.transaction().map_err(db_error)?;
            tx.execute_batch("CREATE TABLE settings (id INTEGER PRIMARY KEY CHECK(id=1), value TEXT NOT NULL); CREATE TABLE recipes (name TEXT PRIMARY KEY, value TEXT NOT NULL); CREATE TABLE presets (name TEXT PRIMARY KEY, value TEXT NOT NULL); CREATE TABLE history (id INTEGER PRIMARY KEY, operation TEXT NOT NULL, format TEXT NOT NULL, bytes INTEGER NOT NULL, created_at INTEGER NOT NULL); PRAGMA user_version=1;").map_err(db_error)?;
            tx.execute(
                "INSERT INTO settings(id,value) VALUES(1,?1)",
                [serde_json::to_string(&Settings::default())?],
            )
            .map_err(db_error)?;
            tx.commit().map_err(db_error)?;
        }
        Ok(Self { db })
    }
    pub fn settings(&self) -> Result<Settings> {
        let value: String = self
            .db
            .query_row("SELECT value FROM settings WHERE id=1", [], |r| r.get(0))
            .map_err(db_error)?;
        let s: Settings = serde_json::from_str(&value)?;
        s.validate()?;
        Ok(s)
    }
    pub fn set_settings(&mut self, s: &Settings) -> Result<()> {
        s.validate()?;
        let tx = self.db.transaction().map_err(db_error)?;
        tx.execute(
            "UPDATE settings SET value=?1 WHERE id=1",
            [serde_json::to_string(s)?],
        )
        .map_err(db_error)?;
        if !s.history_enabled {
            tx.execute("DELETE FROM history", []).map_err(db_error)?;
        }
        tx.commit().map_err(db_error)?;
        self.expire_history()?;
        Ok(())
    }
    pub fn save_recipe(&self, r: &Recipe) -> Result<()> {
        r.validate()?;
        if r.name.len() > 128 {
            return Err(invalid("Recipe name is too long."));
        }
        self.db.execute("INSERT INTO recipes(name,value) VALUES(?1,?2) ON CONFLICT(name) DO UPDATE SET value=excluded.value",params![r.name,serde_json::to_string(r)?]).map_err(db_error)?;
        Ok(())
    }
    pub fn recipes(&self) -> Result<Vec<Recipe>> {
        let mut q = self
            .db
            .prepare("SELECT value FROM recipes ORDER BY name COLLATE NOCASE,name")
            .map_err(db_error)?;
        let values = q
            .query_map([], |r| r.get::<_, String>(0))
            .map_err(db_error)?;
        values
            .map(|v| Recipe::parse(v.map_err(db_error)?.as_bytes()))
            .collect()
    }
    pub fn delete_recipe(&self, name: &str) -> Result<()> {
        self.db
            .execute("DELETE FROM recipes WHERE name=?1", [name])
            .map_err(db_error)?;
        Ok(())
    }
    pub fn save_preset(&self, p: &PackPreset) -> Result<()> {
        p.validate()?;
        if p.name.is_empty() || p.name.len() > 128 {
            return Err(invalid("Preset needs a short name."));
        }
        self.db.execute("INSERT INTO presets(name,value) VALUES(?1,?2) ON CONFLICT(name) DO UPDATE SET value=excluded.value",params![p.name,serde_json::to_string(p)?]).map_err(db_error)?;
        Ok(())
    }
    pub fn record(&self, operation: &str, info: &OutputInfo) -> Result<()> {
        let settings = self.settings()?;
        if !settings.history_enabled {
            return Ok(());
        }
        if !["photo", "signature", "pdf", "scan", "pack", "print"].contains(&operation)
            || !["jpeg", "png", "pdf", "zip"].contains(&info.format.as_str())
            || info.bytes > i64::MAX as u64
        {
            return Err(invalid("Invalid history summary."));
        }
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map_err(|_| invalid("System clock is not valid."))?
            .as_secs() as i64;
        self.db
            .execute(
                "INSERT INTO history(operation,format,bytes,created_at) VALUES(?1,?2,?3,?4)",
                params![operation, info.format, info.bytes as i64, now],
            )
            .map_err(db_error)?;
        self.db.execute("DELETE FROM history WHERE id NOT IN (SELECT id FROM history ORDER BY id DESC LIMIT 100)",[]).map_err(db_error)?;
        self.expire_history()
    }
    fn expire_history(&self) -> Result<()> {
        let days = self.settings()?.retention_days;
        self.db
            .execute(
                "DELETE FROM history WHERE created_at < unixepoch() - ?1",
                [i64::from(days) * 86400],
            )
            .map_err(db_error)?;
        Ok(())
    }
    pub fn history(&self) -> Result<Vec<HistoryEntry>> {
        self.expire_history()?;
        let mut q=self.db.prepare("SELECT id,operation,format,bytes,created_at FROM history ORDER BY id DESC LIMIT 100").map_err(db_error)?;
        q.query_map([], |r| {
            Ok(HistoryEntry {
                id: r.get(0)?,
                operation: r.get(1)?,
                format: r.get(2)?,
                bytes: r.get::<_, i64>(3)? as u64,
                created_at: r.get(4)?,
            })
        })
        .map_err(db_error)?
        .map(|r| r.map_err(db_error))
        .collect()
    }
    pub fn clear_history(&self) -> Result<()> {
        self.db
            .execute("DELETE FROM history", [])
            .map_err(db_error)?;
        Ok(())
    }
}
