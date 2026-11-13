Answers in the shapes the Steamworks Web API documents (partner.steamgames.com/doc/webapi), used by
`node tools/ladder/test_ladder.mjs` in place of the network. They are written from the documentation, not captured
from a real App ID (there is none yet): once the game has one, replace them with real answers (`curl` the same URLs
with the publisher key) and keep the tests passing.
