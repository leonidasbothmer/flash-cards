import json
import random

INPUT = "data-engineering/el-extract.jsonl"

def random_line(file_path):
    with open(file_path, "rb") as f:
        f.seek(0, 2)  # go to end
        file_size = f.tell()

        while True:
            pos = random.randint(0, file_size - 1)
            f.seek(pos)

            # skip partial line
            f.readline()

            line = f.readline()
            if line:
                return line.decode("utf-8")

while True:
    try:
        line = random_line(INPUT)
        data = json.loads(line)

        print("\n--- RANDOM ENTRY ---\n")
        print(json.dumps(data, indent=2, ensure_ascii=False))

        # quick highlights
        print("\n--- SUMMARY ---")
        print("word:", data.get("word"))
        print("pos:", data.get("pos"))

        senses = data.get("senses", [])
        for i, s in enumerate(senses[:3]):
            print(f"sense {i+1}:", s.get("glosses"))

        input("\nPress ENTER for next...")
    except Exception:
        continue