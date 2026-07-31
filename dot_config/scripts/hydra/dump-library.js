#!/usr/bin/env node
/**
 * dump-library.js — read Hydra's game library and print it as JSON.
 *
 * Hydra stores its library in a LevelDB at %APPDATA%/hydralauncher/hydra-db via
 * `classic-level` with valueEncoding "json" (hydra: src/main/level/level.ts).
 * Games live in the "games" sublevel, keyed `${shop}:${objectId}`
 * (src/main/level/sublevels/keys.ts).
 *
 * LevelDB values are Snappy-compressed, so string-scraping the .ldb files does
 * not work — it has to be opened by a real LevelDB reader. Hence a Node helper
 * rather than doing this from the Playnite extension directly.
 *
 * IMPORTANT: LevelDB takes an exclusive LOCK. Hydra must be closed, or this
 * exits with a clear message rather than a stack trace.
 *
 * Output: {"games":[...]} on stdout. Errors as {"error":"..."} with exit 1, so
 * the caller can always parse the response.
 */

const path = require("path");
const os = require("os");

async function main() {
  const dbPath =
    process.argv[2] ||
    path.join(process.env.APPDATA || os.homedir(), "hydralauncher", "hydra-db");

  let ClassicLevel;
  try {
    ({ ClassicLevel } = require("classic-level"));
  } catch {
    throw new Error(
      "classic-level not installed. Run: npm install --prefix " +
        __dirname +
        " classic-level"
    );
  }

  const db = new ClassicLevel(dbPath, { valueEncoding: "json" });
  try {
    await db.open();
  } catch (err) {
    if (String(err).includes("LOCK") || String(err).includes("lock")) {
      throw new Error("Hydra is running — close it first (LevelDB is exclusive).");
    }
    throw err;
  }

  try {
    const games = db.sublevel("games", { valueEncoding: "json" });
    const out = [];
    for await (const [key, game] of games.iterator()) {
      if (!game || game.isDeleted) continue;
      out.push({
        key,
        objectId: game.objectId,
        shop: game.shop,
        title: game.title,
        executablePath: game.executablePath || null,
        iconUrl: game.customIconUrl || game.iconUrl || null,
        coverUrl: game.customCoverImageUrl || game.libraryHeroImageUrl || null,
        playTimeInMilliseconds: game.playTimeInMilliseconds || 0,
        lastTimePlayed: game.lastTimePlayed || null,
        installedSizeInBytes: game.installedSizeInBytes ?? null,
        favorite: !!game.favorite,
      });
    }
    process.stdout.write(JSON.stringify({ games: out }, null, 2));
  } finally {
    await db.close();
  }
}

main().catch((err) => {
  process.stdout.write(JSON.stringify({ error: err.message || String(err) }));
  process.exit(1);
});
