"""Music study (job music-study): the comparison set of real pieces, as numbers.

The book the owner sent is a copyrighted edition and is not in the repository (docs/music_classical_refs.md has the
facts read from it). The numbers below are ESTIMATES from well-known facts about each work (its score, its form and
its usual performances), not measurements of a recording or an edition. Each row has a confidence: "high" for pieces
whose structure is very well known (Für Elise, Gymnopédie, Bach's C major prelude...), "med" for most, "low" where
the piece is rarely studied (the Alkan pieces, the Lyapunov) or the edition's choice is unclear (the polonaise).

Fields (the same names as the game's measured features, so they can be compared):
  beat_bpm      the notated beat a conductor would beat (crotchet in x/4, minim in cut time, dotted crotchet in
                compound time), at a usual performance tempo
  metre_class   duple / triple / compound / odd
  majorish      True for major, False for minor (the mode of the main section)
  harm_rhythm   chord changes per bar, typical of the main section
  chromatic     share of notes outside the key (0-1)
  phrase_square share of phrases that are 2, 4 or 8 bars long
  tune_repeat   share of the piece that brings back a stretch of tune heard before (with repeats as played)
  mel_step      share of melody intervals that are a step (1-2 semitones); mel_repeat repeated notes;
  mel_leap      share of a 4th or more
  mel_range     the melody's range in semitones
  lra           loudness range of a typical recording, in LU (piano solos ~8-14, orchestral 12-22)
  climax_pos    where the loudest point falls (0 = start, 1 = end)
  indep_lines   lines with their own rhythm (1 = a tune over chords, 2 = tune + an active bass, 3+ = counterpoint)
  develop       how much its motifs are transformed: 1 = repeated, 2 = varied / sequenced, 3 = developed
  form          a short label
  group         calm / march / storm / dance / sacred / overture / court (a piece may sit in two)
"""

# (num, short name, composer, beat_bpm, metre_class, majorish, harm_rhythm, chromatic, phrase_square, tune_repeat,
#  mel_step, mel_repeat, mel_leap, mel_range, lra, climax_pos, indep_lines, develop, form, groups, confidence)
ROWS = [
    (1, "New World Sym. I", "Dvořák", 144, "duple", False, 1.0, 0.08, 0.7, 0.35, 0.40, 0.10, 0.35, 24, 20, 0.92, 3, 3,
     "sonata (slow intro)", ("storm", "overture"), "med"),
    (2, "Etude Op.76/2", "Alkan", 60, "duple", True, 2.0, 0.10, 0.6, 0.35, 0.55, 0.10, 0.25, 24, 12, 0.7, 2, 2,
     "ternary", ("sacred",), "low"),
    (3, "Ouverture Op.39/11", "Alkan", 100, "duple", False, 1.5, 0.15, 0.7, 0.35, 0.40, 0.25, 0.30, 30, 16, 0.85, 2, 2,
     "sectional", ("storm", "march", "overture"), "low"),
    (4, "Scherzo focoso", "Alkan", 132, "compound", False, 1.0, 0.12, 0.8, 0.45, 0.55, 0.10, 0.25, 30, 14, 0.9, 2, 2,
     "scherzo-trio", ("storm", "dance"), "low"),
    (5, "Clair de Lune", "Debussy", 50, "compound", True, 1.0, 0.12, 0.5, 0.25, 0.55, 0.10, 0.15, 30, 15, 0.6, 2, 2,
     "A-B-A'", ("calm",), "high"),
    (6, "Flaxen Hair", "Debussy", 50, "triple", True, 1.5, 0.05, 0.4, 0.30, 0.40, 0.10, 0.25, 20, 10, 0.55, 1, 2,
     "A-B-A'", ("calm",), "med"),
    (7, "Gymnopédie 1", "Satie", 72, "triple", True, 1.0, 0.05, 0.8, 0.50, 0.60, 0.10, 0.15, 14, 6, 0.4, 1, 1,
     "A-A'", ("calm",), "high"),
    (8, "Hungarian Rhapsody 2", "Liszt", 80, "duple", False, 1.0, 0.12, 0.75, 0.45, 0.45, 0.20, 0.25, 40, 20, 0.95, 2, 2,
     "slow lassan, fast friska", ("dance", "storm"), "med"),
    (9, "Liebestraum 3", "Liszt", 66, "compound", True, 2.0, 0.15, 0.6, 0.35, 0.55, 0.10, 0.20, 24, 18, 0.6, 2, 2,
     "A-B-A' with cadenzas", ("calm",), "high"),
    (10, "Bénédiction de Dieu", "Liszt", 60, "duple", True, 1.5, 0.12, 0.6, 0.35, 0.60, 0.10, 0.15, 24, 18, 0.6, 2, 2,
     "A-B-A'", ("sacred", "calm"), "med"),
    (11, "Sonata in B minor", "Liszt", 132, "duple", False, 1.5, 0.25, 0.3, 0.30, 0.40, 0.15, 0.35, 50, 22, 0.75, 3, 3,
     "one-movement sonata, themes transformed", ("storm",), "med"),
    (12, "Impromptu D.899/3", "Schubert", 70, "duple", True, 1.5, 0.10, 0.85, 0.40, 0.60, 0.10, 0.15, 20, 12, 0.55, 2, 2,
     "A-B-A'", ("calm", "sacred"), "high"),
    (13, "Wanderer Fantasy", "Schubert", 120, "duple", True, 1.5, 0.15, 0.6, 0.30, 0.40, 0.25, 0.30, 36, 15, 0.8, 2, 3,
     "sonata-like, one rhythm developed", ("storm", "march"), "med"),
    (14, "Prelude Op.28/1", "Chopin", 84, "duple", True, 1.0, 0.12, 0.75, 0.15, 0.45, 0.15, 0.30, 24, 12, 0.62, 2, 2,
     "one arch", ("storm",), "high"),
    (15, "Ocean Etude", "Chopin", 80, "duple", False, 1.0, 0.15, 0.8, 0.35, 0.50, 0.15, 0.20, 30, 14, 0.85, 2, 2,
     "A-B-A'", ("storm",), "high"),
    (16, "Fantaisie-Impromptu", "Chopin", 84, "duple", False, 1.0, 0.12, 0.85, 0.45, 0.60, 0.05, 0.15, 30, 14, 0.85, 2, 2,
     "A-B-A'", ("storm", "calm"), "high"),
    (17, "Nocturne Op.9/2", "Chopin", 44, "compound", True, 2.0, 0.15, 0.85, 0.60, 0.60, 0.05, 0.20, 24, 10, 0.85, 2, 2,
     "A A B A B A coda", ("calm", "court"), "high"),
    (18, "Polonaise", "Chopin", 92, "triple", True, 2.0, 0.10, 0.8, 0.45, 0.50, 0.15, 0.25, 24, 12, 0.85, 2, 2,
     "polonaise-trio-polonaise", ("dance", "court", "march"), "low"),
    (19, "Minute Waltz", "Chopin", 210, "triple", True, 0.6, 0.10, 0.9, 0.50, 0.75, 0.05, 0.10, 24, 10, 0.8, 2, 2,
     "A-B-A", ("dance", "court"), "high"),
    (20, "Waltz Op.70/1", "Chopin", 200, "triple", True, 0.7, 0.10, 0.9, 0.50, 0.60, 0.05, 0.20, 24, 10, 0.5, 2, 2,
     "A-B-A", ("dance", "court"), "med"),
    (21, "Toreador March", "Bizet", 108, "duple", True, 1.5, 0.08, 0.9, 0.55, 0.45, 0.20, 0.30, 14, 10, 0.9, 2, 1,
     "verse and refrain", ("march",), "high"),
    (22, "Habanera", "Bizet", 72, "duple", False, 0.5, 0.25, 0.9, 0.60, 0.85, 0.05, 0.05, 14, 10, 0.8, 2, 1,
     "verse and refrain over a bass ostinato", ("dance",), "high"),
    (23, "Vissi d'arte", "Puccini", 52, "duple", False, 1.5, 0.20, 0.5, 0.25, 0.65, 0.15, 0.15, 22, 18, 0.8, 2, 2,
     "through-composed arch", ("sacred", "calm"), "med"),
    (24, "Barber of Seville Ov.", "Rossini", 120, "duple", True, 1.0, 0.10, 0.9, 0.55, 0.55, 0.15, 0.20, 20, 18, 0.95, 2, 1,
     "slow intro, sonatina, crescendos", ("overture", "court"), "high"),
    (25, "Badinerie", "Bach", 110, "duple", False, 1.5, 0.08, 0.6, 0.50, 0.40, 0.05, 0.40, 22, 5, 0.5, 2, 2,
     "binary, both halves repeated", ("court", "dance"), "high"),
    (26, "Air", "Bach", 56, "duple", True, 3.5, 0.12, 0.5, 0.50, 0.55, 0.10, 0.20, 20, 8, 0.6, 4, 2,
     "binary, both halves repeated", ("calm", "sacred", "court"), "high"),
    (27, "Prelude in C (WTC I)", "Bach", 66, "duple", True, 1.0, 0.12, 0.6, 0.05, None, None, None, None, 8, 0.7, 1, 1,
     "one figure, harmony moves every bar", ("calm", "sacred"), "high"),
    (28, "Prelude in C minor (WTC I)", "Bach", 110, "duple", False, 1.0, 0.12, 0.6, 0.05, None, None, None, None, 8, 0.8,
     2, 1, "perpetual figure, free close", ("storm",), "high"),
    (29, "Radetzky March", "J. Strauss I", 112, "duple", True, 1.0, 0.05, 0.95, 0.60, 0.45, 0.30, 0.20, 16, 10, 0.95, 2, 1,
     "march-trio-march", ("march", "court"), "high"),
    (30, "Blue Danube", "J. Strauss II", 180, "triple", True, 0.5, 0.05, 0.95, 0.50, 0.30, 0.15, 0.45, 24, 18, 0.95, 2, 1,
     "intro, five waltzes, coda", ("dance", "court"), "high"),
    (31, "Voices of Spring", "J. Strauss II", 200, "triple", True, 0.5, 0.08, 0.95, 0.55, 0.55, 0.10, 0.25, 24, 12, 0.85, 2, 1,
     "waltz chain", ("dance", "court"), "med"),
    (32, "Moonlight I", "Beethoven", 54, "duple", False, 1.0, 0.12, 0.6, 0.20, 0.40, 0.40, 0.10, 14, 8, 0.6, 2, 2,
     "free ternary over a constant figure", ("calm",), "high"),
    (33, "Moonlight III", "Beethoven", 160, "duple", False, 1.0, 0.15, 0.7, 0.40, 0.35, 0.10, 0.45, 40, 15, 0.9, 2, 3,
     "sonata", ("storm",), "high"),
    (34, "Waldstein I", "Beethoven", 160, "duple", True, 1.0, 0.15, 0.7, 0.40, 0.40, 0.25, 0.30, 36, 16, 0.85, 2, 3,
     "sonata", ("storm",), "high"),
    (35, "Pastoral I", "Beethoven", 132, "duple", True, 0.5, 0.03, 0.9, 0.60, 0.50, 0.15, 0.20, 18, 16, 0.85, 2, 3,
     "sonata, one cell repeated over long drones", ("calm",), "high"),
    (36, "Symphony 7 II", "Beethoven", 66, "duple", False, 1.0, 0.08, 0.95, 0.70, 0.30, 0.50, 0.10, 8, 22, 0.45, 3, 2,
     "ostinato variations, fugato", ("march", "sacred", "storm"), "high"),
    (37, "Für Elise", "Beethoven", 42, "compound", False, 1.0, 0.15, 0.95, 0.65, 0.60, 0.05, 0.25, 24, 10, 0.55, 2, 1,
     "rondo A-B-A-C-A", ("calm",), "high"),
    (38, "Pavane", "Ravel", 54, "duple", True, 2.0, 0.10, 0.85, 0.50, 0.60, 0.10, 0.15, 15, 12, 0.65, 2, 1,
     "rondo A-B-A-C-A", ("calm", "sacred", "court"), "high"),
    (39, "Trepak", "Tchaikovsky", 150, "duple", True, 1.0, 0.08, 0.95, 0.60, 0.50, 0.15, 0.25, 20, 14, 0.95, 2, 1,
     "A-B-A, faster coda", ("dance", "storm"), "high"),
    (40, "Sugar Plum Fairy", "Tchaikovsky", 72, "duple", False, 1.0, 0.20, 0.9, 0.50, 0.40, 0.30, 0.20, 15, 12, 0.5, 2, 1,
     "A-B-A", ("calm",), "high"),
    (41, "Waltz of the Flowers", "Tchaikovsky", 160, "triple", True, 0.5, 0.08, 0.95, 0.55, 0.45, 0.10, 0.30, 24, 18, 0.95, 2, 2,
     "intro, waltz chain, coda", ("dance", "court"), "high"),
    (42, "The Swan", "Saint-Saëns", 72, "triple", True, 1.0, 0.12, 0.6, 0.40, 0.60, 0.05, 0.20, 22, 10, 0.6, 2, 1,
     "A-B-A'", ("calm",), "high"),
    (43, "Adagio for Strings", "Barber", 50, "duple", False, 1.5, 0.08, 0.2, 0.30, 0.85, 0.05, 0.05, 24, 22, 0.75, 4, 2,
     "one arch to a single climax", ("sacred", "calm"), "high"),
    (44, "Tarantelle Op.25", "Lyapunov", 140, "compound", False, 1.0, 0.12, 0.9, 0.50, 0.45, 0.10, 0.35, 30, 14, 0.95, 2, 2,
     "A-B-A, coda", ("dance", "storm"), "low"),
    (45, "Eine kleine Nachtmusik I", "Mozart", 130, "duple", True, 1.5, 0.08, 0.85, 0.50, 0.45, 0.20, 0.30, 24, 10, 0.5, 2, 2,
     "sonata, exposition repeated", ("court",), "high"),
    (46, "Figaro Overture", "Mozart", 142, "duple", True, 1.0, 0.08, 0.85, 0.45, 0.65, 0.10, 0.15, 24, 18, 0.95, 2, 2,
     "sonata without development", ("overture", "court"), "high"),
    (47, "Rondo alla Turca", "Mozart", 128, "duple", False, 1.0, 0.10, 0.95, 0.60, 0.75, 0.05, 0.10, 24, 10, 0.95, 2, 1,
     "rondo", ("march", "court"), "high"),
    (48, "Dies Irae", "Mozart", 140, "duple", False, 3.0, 0.15, 0.7, 0.30, 0.40, 0.40, 0.20, 16, 10, 0.2, 3, 2,
     "choral blocks, a hushed answer", ("sacred", "storm"), "med"),
    (49, "Symphony 40 I", "Mozart", 110, "duple", False, 1.0, 0.15, 0.85, 0.45, 0.70, 0.30, 0.15, 20, 12, 0.7, 3, 3,
     "sonata", ("storm", "court"), "high"),
]

FIELDS = ["num", "name", "composer", "beat_bpm", "metre_class", "majorish", "harm_rhythm", "chromatic", "phrase_square",
          "tune_repeat", "mel_step", "mel_repeat", "mel_leap", "mel_range", "lra", "climax_pos", "indep_lines",
          "develop", "form", "groups", "confidence"]


def refs():
    return [dict(zip(FIELDS, r)) for r in ROWS]


# which reference groups each game job is measured against (judgement: the job's dramatic purpose)
JOB_GROUPS = {
    "calm": ("calm",), "calm+open": ("calm", "court"), "open": ("overture", "march"),
    "skirmish": ("dance", "march"), "battle": ("storm", "march"), "menu": ("overture", "sacred"),
    "win": ("march", "overture"), "defeat": ("sacred",),
}
# the classical groups the reference table assigned to each side (docs/music_classical_refs.md)
FACTION_PIECES = {
    "crown": {25, 26, 27, 28, 45, 46, 47, 48, 49, 29, 30, 31, 41, 18, 10, 23},
    "clock": {28, 15, 14, 34, 33, 3, 46},
    "brood": {36, 11, 8, 39, 44, 32, 40},
}
