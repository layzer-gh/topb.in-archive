# topb.in — the gameweek archive

Every gameweek, [topb.in](https://topb.in) fits a goal model to the football
match prices and works out the expected FPL points for every player. This
repository is the record of what it said, **committed before each deadline**.

That is the whole purpose. Anyone can claim their model called a captain after
the fact. The commit timestamps here predate the deadlines they refer to, and
you do not have to take our word for any of it — GitHub keeps the dates, not us.

## What's in a file

One file per gameweek, at `archive/<season>/gw<n>.json`. Written in two phases.

**Before the deadline** — the prediction, and the prices it came from:

| field | meaning |
|---|---|
| `deadline` | the FPL deadline this is a prediction for |
| `frozenAt` | when this snapshot was taken |
| `hoursBefore` | how long before the deadline — the number that matters |
| `rev` | the engine commit that produced it |
| `odds.src` | `odds-api` for live market prices |
| `fixtures[]` | the fitted goal rates (`lam`), the Dixon-Coles correction (`rho`), and seven probabilities per match (`p`): home/draw/away, over 2.5, both teams to score, and a clean sheet for each side |
| `players[]` | expected points (`ep`), doubled for the armband (`cap`), clean-sheet and two-goal probabilities, the seven-part points breakdown (`br`), expected minutes (`xm`), and ownership at the time (`own`) |
| `pick` | the highest projected captain |
| `crowd` | the most-*owned* eligible captain — the crowd proxy available before a deadline |
| `diffs` | the differentials ranking, by player code |

**After the results settle** — added once FPL marks the gameweek checked:

| field | meaning |
|---|---|
| `fixtures[].r` | the actual score, `[home, away]` |
| `players[].act` | what the player actually returned, `[points, minutes]` |
| `actuals` | the gameweek average, the highest score, and the crowd's actual most-captained player |

Results are stored raw rather than as scores or hit-rates, so anyone can compute
their own measure of how the model did — including measures we did not think of,
and ones that are less flattering than the ones we would pick.

## Reading the honest bits

Two things are worth saying plainly.

**The match layer is the market's work, not ours.** The fixture probabilities
come from de-vigging bookmakers' prices and fitting a Dixon-Coles model to them.
If they turn out well calibrated, that is mostly a fact about the betting market.
We publish them so the fit can be checked, not as evidence of an edge.

**The player layer is ours.** Expected minutes, the share of a team's chances a
player takes, and the conversion into FPL points — that is the part worth judging
us on, and the part most likely to be wrong, especially early in a season.

## What is deliberately not here

Two things are held back, for two different reasons.

**The model's internals.** Each player row carries expected points, the
clean-sheet and two-goal probabilities, ownership, price, and what they actually
returned — but not the component-by-component breakdown of how the projection
was built, nor the expected-minutes figure behind it. Those are not needed to
check anything claimed here; across a whole season they would amount to a
specification of the player model.

**The bookmakers' prices.** The odds themselves come from a paid data provider
whose terms allow their use inside an application like topb.in, but not
redistribution as downloadable data files. So this archive publishes what the
model made of the prices — the fitted goal rates and the probabilities — rather
than the prices themselves. Those fitted numbers are the model's output, and
they are what the predictions here actually rest on.

Neither omission affects what this repository is for. The pick, the ranking, the
probabilities and the timestamps are all here, and all checkable.

## Identifiers

Players and clubs use FPL's persistent `code`, not the season-scoped `id`, so a
record stays readable in later seasons. The one exception is `fixtures[].f`, an
FPL fixture id kept only so results can be joined; it means nothing across
seasons.

## Notes

- This repo is written to automatically. Changes are not made by hand.
- A gameweek missing from the archive was one where no snapshot could be taken
  before the deadline. It is left missing rather than backfilled, because a
  prediction written after a deadline is not a prediction.
- The engine itself is not open source. This is the output, not the model.
