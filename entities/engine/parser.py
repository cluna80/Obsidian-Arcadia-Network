from engine.entity import Entity

def parse_dsl(file_path):
    entity = None

    with open(file_path, "r") as f:
        lines = f.readlines()

    for line in lines:
        line = line.strip()

        if not line:
            continue

        if line.startswith("ENTITY"):
            name = line.split("ENTITY")[1].strip()
            entity = Entity(name)

        elif line.startswith("INTENT"):
            entity.intent = extract_value(line)

        elif line.startswith("BIND"):
            entity.binds.append(line.split("BIND")[1].strip())

        elif line.startswith("MODE"):
            entity.mode = line.split("MODE")[1].strip()

        elif line.startswith("WORLD"):
            entity.world = line.split("WORLD")[1].strip()

        elif line.startswith("TOKENIZED"):
            value = line.split("TOKENIZED")[1].strip()
            entity.tokenized = value.lower() == "true"

    return entity

def extract_value(line):
    return line.split('"')[1]
