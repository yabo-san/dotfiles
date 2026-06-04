# MS Store apps (winget --source msstore)

> Store apps I actually want on a fresh machine — hand-picked, NOT a bulk dump.
> These aren't in scoop/winget-community/choco; they need the msstore source.
> `brew` falls through to msstore automatically, or install directly below.
>
>   winget install <ID> --source msstore --accept-package-agreements

## Curated list (add to this deliberately, one at a time)
| App | Store ID | Confirmed |
|-----|----------|-----------|
| Cider (Preview) | 9PL8WPH0QK9M | ✅ |
| iCloud | 9PKTQ5699M62 | ✅ |
| EarTrumpet | 9NBLGGH516XP | ✅ |
| TranslucentTB | 9PF4KZ2VN4W9 | ✅ |

> To add an app: `winget search "<name>" --source msstore`, grab its ID, add a row.
> Keep this curated — only apps you'd reinstall, not everything in the Store.
