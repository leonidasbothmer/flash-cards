import json

INPUT = "data-engineering/el-extract.jsonl"
OUTPUT = "data-engineering/greek_vocab_sample.json"
COMMON_WORDS = "data-engineering/1000-most-common_el.json"

ALLOWED_POS = {"noun", "verb", "adj", "adv"}
LIMIT = 1000


def load_common_english_words(path):
    """Map Greek surface form -> English gloss from ranked frequency list (best rank wins)."""
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    out = {}
    for entry in data.get("words", []):
        w = entry.get("targetWord")
        en = entry.get("englishWord")
        if w and en is not None and w not in out:
            out[w] = en
    return out


common_en = load_common_english_words(COMMON_WORDS)
vocab = []

with open(INPUT, "r", encoding="utf-8") as f:
    for line in f:
        item = json.loads(line)

        word = item.get("word")
        pos = item.get("pos")

        if not word or pos not in ALLOWED_POS:
            continue

        # skip multi-word phrases
        if " " in word or "-" in word:
            continue

        senses = item.get("senses", [])
        glosses = []

        for sense in senses:
            glosses.extend(sense.get("glosses", []))

        if not glosses:
            continue

        merged_english = glosses[:3]
        freq_en = common_en.get(word)
        if freq_en is not None:
            merged_english = [freq_en, *merged_english]

        vocab.append({
            "id": word,
            "greek": word,
            "lemma": word,
            "pos": pos,
            "english": merged_english,
            "german": "",
            "stack": 0,
            "correctStreak": 0
        })

        if len(vocab) >= LIMIT:
            break

with open(OUTPUT, "w", encoding="utf-8") as out:
    json.dump(vocab, out, ensure_ascii=False, indent=2)

print(f"Saved {len(vocab)} words to {OUTPUT}")