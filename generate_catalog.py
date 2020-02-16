#!/usr/bin/env python3
import frontmatter
import os
import shutil

recipe_directory = "_rezepte"
output_directories = ['owners', 'tags']

for directory in output_directories:
    shutil.rmtree(directory, ignore_errors=True, onerror=None)

with os.scandir(recipe_directory) as entries:
    for entry in entries:
        if not entry.is_file():
            continue

        recipe = frontmatter.load(entry.path)
        for tag in recipe['tags']:
            directory = f'tags/{tag}'
            file = os.path.join(directory, entry.name)
            os.makedirs(directory, exist_ok=True)
            with open(file, 'w+') as f:
                f.write(recipe.content)

        owner = recipe['owner']
        directory = f'owners/{owner}'
        file = os.path.join(directory, entry.name)
        os.makedirs(directory, exist_ok=True)
        with open(file, 'w+') as f:
            f.write(recipe.content)
